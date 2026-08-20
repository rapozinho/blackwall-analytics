# -*- coding: utf-8 -*-
"""Gera os fixtures da demo estatica a partir da API real.

A demo publicada no GitHub Pages nao tem backend nem banco: ela le arquivos JSON
capturados aqui. Este script sobe nada — ele consome uma API que ja esteja no ar
(a stack do `docker compose`, ou o uvicorn local) e grava um snapshot de cada
combinacao grafico x base em `frontend/public/fixtures/`.

    python tools/gen_fixtures.py --api http://127.0.0.1:8080 \
        --date-start 2026-07-01 --date-end 2026-07-31

Reports tabulares passam de 1 minuto por arquivo: eles entram pelo mesmo caminho
que o frontend usa (`/start` + polling de `/api/jobs/<id>`), nao por GET direto.
"""
import argparse
import json
import pathlib
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

RAIZ = pathlib.Path(__file__).resolve().parent.parent
DESTINO = RAIZ / "frontend" / "public" / "fixtures"

# Timeout por requisicao. O job de report responde rapido (e polling); quem
# demora e a consulta la dentro, e essa espera esta no loop de polling.
TIMEOUT = 120
# Teto de espera de um job. Monitoring na base maior fica perto de 3 min.
JOB_TIMEOUT = 900


# Janela padrao por grafico. O Retention so' faz sentido com varios meses: com
# 31 dias o grafico tem uma safra so' e a curva de decaimento nao existe.
JANELA_PADRAO = {
    "retention_cohort": {"date_start": "2025-09-01", "date_end": "2026-08-07"},
}

# Snapshots extra por grafico: a demo estatica nao roda query, entao cada
# combinacao de filtro que o visitante pode escolher precisa existir em disco.
# Chave = sufixo do arquivo; valor = params que sobrescrevem o padrao.
EXTRAS = {
    "overview": {
        "90d": {"date_start": "2026-05-10", "date_end": "2026-08-07"},
        "2026-06": {"date_start": "2026-06-01", "date_end": "2026-06-30"},
    },
    "retention_cohort": {
        "multi": {"metrics": "ggr,turnover,deposits,netcash"},
        "avg": {"variant": "avg", "metrics": "ggr,turnover"},
        "agregado": {"variant": "agregado"},
    },
}


def get(api: str, caminho: str, timeout: int = TIMEOUT):
    url = f"{api.rstrip('/')}{caminho}"
    with urllib.request.urlopen(url, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8"))


def salvar(nome: str, payload) -> int:
    destino = DESTINO / nome
    texto = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    destino.write_text(texto, encoding="utf-8")
    return len(texto.encode("utf-8"))


def qs(base: str, params: dict) -> str:
    return urllib.parse.urlencode({"base": base, **params})


def params_para(chart: dict, args) -> dict:
    """Preenche o filtro com o valor de demonstracao de cada tipo de param."""
    out = {}
    for nome, spec in chart["params"].items():
        tipo = spec["type"]
        if tipo == "date":
            # `date_start2`/`date_end2` = periodo de comparacao dos reports duais.
            if nome.endswith("2"):
                out[nome] = args.date_start2 if "start" in nome else args.date_end2
            else:
                out[nome] = args.date_start if "start" in nome else args.date_end
        elif tipo == "select":
            padrao = spec.get("default")
            out[nome] = padrao if padrao is not None else spec["options"][0]["value"]
        elif tipo == "multiselect":
            padrao = spec.get("default") or [spec["options"][0]["value"]]
            # O backend le multiselect como lista separada por virgula.
            out[nome] = ",".join(padrao)
    out.update(JANELA_PADRAO.get(chart["id"], {}))
    return out


def rodar_job(api: str, chart_id: str, base: str, params: dict):
    """Mesmo fluxo do frontend: start -> polling -> result."""
    inicio = get(api, f"/api/charts/{chart_id}/start?{qs(base, params)}")
    job_id = inicio["job_id"]
    limite = time.monotonic() + JOB_TIMEOUT
    ultimo = -1
    while time.monotonic() < limite:
        st = get(api, f"/api/jobs/{job_id}")
        if st["progress"] != ultimo:
            ultimo = st["progress"]
            print(f"      {ultimo:3d}% {st['step']}", flush=True)
        if st["status"] == "done":
            return st["result"]
        if st["status"] in ("error", "cancelled"):
            raise RuntimeError(st.get("error") or st["status"])
        time.sleep(3)
    raise TimeoutError(f"job {job_id} passou de {JOB_TIMEOUT}s")


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--api", default="http://127.0.0.1:8080")
    p.add_argument("--date-start", default="2026-07-01")
    p.add_argument("--date-end", default="2026-07-31")
    # Periodo de comparacao (Monitoring, Big Picture - Acquisition).
    p.add_argument("--date-start2", default="2026-06-01")
    p.add_argument("--date-end2", default="2026-06-30")
    p.add_argument("--only", default="", help="filtra por id de grafico (csv)")
    args = p.parse_args()

    DESTINO.mkdir(parents=True, exist_ok=True)
    filtro = {s for s in args.only.split(",") if s}

    manifesto = {
        "gerado_em": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "periodo": {"date_start": args.date_start, "date_end": args.date_end},
        "periodo_comparacao": {"date_start2": args.date_start2, "date_end2": args.date_end2},
        "entradas": {},
        "falhas": {},
    }

    print("== catalogo ==", flush=True)
    bases = get(args.api, "/api/bases")
    salvar("bases.json", bases)
    salvar("meta.json", get(args.api, "/api/meta"))

    # health/db testa as 4 bases em sequencia com 5s de timeout cada.
    try:
        saude = get(args.api, "/api/health/db", timeout=60)
        # Na demo nenhuma conexao e' aberta: o "ok" da tela e' o do dia da
        # captura, e a linha de detalhe precisa dizer isso.
        for b in saude.get("bases", []):
            b["detail"] = "snapshot da demonstração — nenhuma conexão foi aberta aqui"
        salvar("health.json", saude)
    except Exception as e:                                   # pragma: no cover
        print(f"  health/db falhou ({e}); demo usa fallback sintetico", flush=True)

    catalogo = {}
    for b in bases:
        charts = get(args.api, f"/api/charts?base={urllib.parse.quote(b['key'])}")
        salvar(f"charts__{b['key']}.json", charts)
        catalogo[b["key"]] = charts

    total_bytes = 0
    for base_key, charts in catalogo.items():
        for chart in charts:
            if filtro and chart["id"] not in filtro:
                continue
            padrao = params_para(chart, args)
            variacoes = [("", padrao)]
            for sufixo, override in EXTRAS.get(chart["id"], {}).items():
                variacoes.append((sufixo, {**padrao, **override}))

            for sufixo, params in variacoes:
                chave = f"{chart['id']}__{base_key}" + (f"__{sufixo}" if sufixo else "")
                print(f"-- {chave}  {params}", flush=True)
                t0 = time.monotonic()
                try:
                    if chart["kind"] == "tables":
                        payload = rodar_job(args.api, chart["id"], base_key, params)
                    else:
                        payload = get(args.api, f"/api/charts/{chart['id']}/data?{qs(base_key, params)}")
                except Exception as e:
                    print(f"   FALHOU: {str(e)[:200]}", flush=True)
                    manifesto["falhas"][chave] = str(e)[:300]
                    continue
                nome = f"data__{chave}.json"
                tam = salvar(nome, payload)
                total_bytes += tam
                manifesto["entradas"][chave] = {
                    "arquivo": nome, "params": params, "kind": chart["kind"],
                    "chart_id": chart["id"], "base": base_key,
                    # `padrao` marca o snapshot que a demo usa quando o visitante
                    # escolhe um filtro que nao existe em disco.
                    "padrao": sufixo == "",
                    "segundos": round(time.monotonic() - t0, 1), "bytes": tam,
                }
                print(f"   ok {tam/1024:.0f} KB em {time.monotonic()-t0:.0f}s", flush=True)

    salvar("manifest.json", manifesto)
    print(f"\n{len(manifesto['entradas'])} fixtures, {total_bytes/1024/1024:.1f} MB total")
    if manifesto["falhas"]:
        print("falhas:", ", ".join(manifesto["falhas"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
