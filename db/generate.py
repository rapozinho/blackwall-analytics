# -*- coding: utf-8 -*-
"""Gera os dados ficticios das 4 bases, em CSV, para carga por BULK INSERT.

Serve as duas verticais (`VERTICAL=bet|ecommerce`): a forma do dado e a mesma e o
que troca sao os parametros economicos e a frequencia de atividade, em
`verticals.py::PERFIL`. Aposta = varias linhas por dia por jogador; e-commerce =
um pedido e semanas de intervalo.

Nao e dado aleatorio uniforme: o objetivo e que os graficos do portal contem uma
historia coerente, porque e isso que o portal foi feito para mostrar.

  - Cadastro cresce ao longo dos 18 meses, com pico de fim de semana.
  - Conversao (1o deposito / 1a compra) depende do canal: midia paga converte
    mais que organico.
  - Retencao decai por cohort (o Retention Cohort precisa de curva, nao de ruido).
  - GGR (receita) = turnover (GMV) x margem, com cauda: parte fica negativa no
    mes, que e o que alimenta o segmento "Negative" do Report Master.
  - Pagamento e reembolso andam junto da atividade, nao soltos.

RNG com semente fixa por base (`bases.py::rng_seed`): dois `docker compose up`
geram exatamente o mesmo dado, entao print de tela e numero de relatorio batem.

Sem dependencia externa (nem faker, nem numpy): o container de seed sobe so com
pyodbc.
"""
import csv
import math
import random
from datetime import date, datetime, timedelta
from pathlib import Path

from bases import (BASES, DATA_FIM, ESCALA, LUMEN_MANAGER_TABLE,
                   LUMEN_PARTNER_CHANNELS, MESES, PROVIDERS)
from verticals import PERFIL, VERTICAL

# --- janela de datas -------------------------------------------------------- #
def _primeiro_dia(d: date, meses_atras: int) -> date:
    ano, mes = d.year, d.month - meses_atras
    while mes <= 0:
        mes += 12
        ano -= 1
    return date(ano, mes, 1)


def _fim_do_mes(d: date) -> date:
    return (date(d.year + 1, 1, 1) if d.month == 12
            else date(d.year, d.month + 1, 1)) - timedelta(days=1)


DATA_INI = _primeiro_dia(DATA_FIM, MESES - 1)
DIAS_TOTAL = (DATA_FIM - DATA_INI).days + 1

# Quanto o primeiro mes do cliente pesa em relacao aos seguintes. Ver
# `GeradorBase._dias_ativos`. Vem do perfil da vertical: aposta tem lua de mel
# mais forte que varejo.
_HONEYMOON = PERFIL["honeymoon"]


# --- utilidades de distribuicao --------------------------------------------- #
def _lognormal(rng: random.Random, mediana: float, sigma: float) -> float:
    """Valor monetario: cauda longa a direita, sem negativo."""
    return mediana * math.exp(rng.gauss(0, sigma))


def _bonus_e_ngr(rng: random.Random, ggr: float) -> tuple[float, float]:
    """Custo de bonus e NGR a partir do GGR.

    O bonus e proporcional ao GGR, nao ao turnover: e o que mantem
    Hold (NGR/GGR) entre 70% e 95% e Generosity (bonus/GGR) na casa de 5%-30%,
    que e a faixa que a operacao le como normal. Proporcional ao turnover, o
    bonus fica maior que o proprio GGR e o NGR sai negativo.

    GGR negativo (o jogador ganhou no periodo) nao gera bonus: NGR acompanha o
    GGR. Esses casos alimentam o segmento "Negative" do Report Master.
    """
    if ggr <= 0:
        return 0.0, ggr
    bonus = round(ggr * rng.uniform(0.05, 0.30), 2)
    return bonus, round(ggr - bonus, 2)


def _peso_dia(d: date) -> float:
    """Sazonalidade: sabado/domingo pesam mais; sexta um pouco."""
    return {0: 0.92, 1: 0.90, 2: 0.95, 3: 1.00, 4: 1.12, 5: 1.30, 6: 1.22}[d.weekday()]


def _peso_mes(d: date) -> float:
    """Crescimento suave da operacao ao longo da janela (+ ~90% no fim)."""
    prog = (d - DATA_INI).days / max(DIAS_TOTAL - 1, 1)
    return 0.65 + 1.15 * prog


# --- geracao por base ------------------------------------------------------- #
class GeradorBase:
    def __init__(self, base_key: str, cfg: dict, destino: Path):
        self.base = base_key
        self.cfg = cfg
        self.destino = destino
        self.rng = random.Random(cfg["rng_seed"])
        self.contagens: dict[str, int] = {}

    # -- afiliados ---------------------------------------------------------- #
    def afiliados(self) -> list[dict]:
        """Um afiliado por manager do dominio da base (o id casa com o nome
        quando a base usa o sufixo '(444)').

        `update_time` nao e enfeite: o monitoring de afiliados deduplica por ela
        (`ROW_NUMBER() ... ORDER BY update_time DESC`).
        """
        rng = self.rng
        atualizado = datetime(DATA_FIM.year, DATA_FIM.month, DATA_FIM.day)
        out = []
        for nome, aff_id in self.cfg["managers"]:
            out.append({"Affiliate_Id": aff_id,
                        "Affiliate_Name": nome.split(" (")[0],
                        "Affiliate_Manager": nome,
                        "update_time": atualizado - timedelta(days=rng.randint(1, 400))})
        # Lumen/Kestrel: os parceiros da tabela de gerentes tambem sao afiliados,
        # com id proprio — e por eles que `acquisitions_agg.affiliate_name` casa.
        if self.cfg["canais"] is None:
            proximo = 600
            for username, manager, _ct in LUMEN_MANAGER_TABLE:
                if any(a["Affiliate_Name"] == username for a in out):
                    continue
                out.append({"Affiliate_Id": proximo, "Affiliate_Name": username,
                            "Affiliate_Manager": manager,
                            "update_time": atualizado - timedelta(days=rng.randint(1, 400))})
                proximo += 1
        return out

    # -- jogadores ---------------------------------------------------------- #
    def jogadores(self, afiliados: list[dict]) -> list[dict]:
        rng = self.rng
        organico = self.cfg["canal_organico"]
        # Sorteio de dia de cadastro proporcional ao peso (mes x dia da semana).
        dias = [DATA_INI + timedelta(days=i) for i in range(DIAS_TOTAL)]
        pesos = [_peso_dia(d) * _peso_mes(d) for d in dias]

        canais = self.cfg["canais"]
        pool_afiliado = [a for a in afiliados]

        jog = []
        for i in range(int(self.cfg["jogadores"] * ESCALA)):
            reg = rng.choices(dias, weights=pesos, k=1)[0]
            # 26% chegam sem afiliado (organico).
            if rng.random() < 0.26:
                aff = None
            else:
                aff = rng.choice(pool_afiliado)

            if canais is None:
                # Lumen/Kestrel: o canal e o proprio parceiro (e o mesmo texto
                # que `affiliate_name`, que casa com `username` na tabela de
                # gerentes); organico tem rotulo proprio — 'Others' na Lumen,
                # 'Organic' na Kestrel.
                canal = organico if aff is None else aff["Affiliate_Name"]
            else:
                canal = organico if aff is None else rng.choice(canais)

            # Midia paga converte melhor que organico.
            p_conv = 0.34 if aff is None else 0.50
            converte = rng.random() < p_conv

            jog.append({
                "User_Id": 10_000 + i,
                "Registration_Date": reg,
                "Acquisition_Channel": canal,
                "Affiliate_Id": None if aff is None else aff["Affiliate_Id"],
                "Affiliate_Name": None if aff is None else aff["Affiliate_Name"],
                "Affiliate_Manager": None if aff is None else aff["Affiliate_Manager"],
                "btag": None if aff is None else f"BT{aff['Affiliate_Id']}-{rng.randint(100, 999)}",
                "converte": converte,
            })
        return jog

    # -- atividade ---------------------------------------------------------- #
    def _dias_ativos(self, inicio: date) -> list[date]:
        """Dias com aposta, mes a mes, a partir do FTD.

        Duas coisas dao forma a curva do Retention Cohort:

        1. `p_ativo` cai a cada mes — o jogador para de voltar (vida media ~3
           meses).
        2. O primeiro mes tem mais dias jogados que os seguintes (`_HONEYMOON`).
           Sem isso o mes 0 sai menor que o mes 1 — ele comeca no dia do FTD, nao
           no dia 1 — e a curva de retencao aparece *subindo* do M0 para o M1, que
           e o oposto do que a safra faz.

        Os dias vem de `rng.sample`, sem repeticao: sorteio com reposicao perdia
        dia repetido no `set()` e afinava o mes sem querer.
        """
        rng = self.rng
        dias: list[date] = []
        mes_ref = date(inicio.year, inicio.month, 1)
        p_ativo = PERFIL["p_ativo"]
        primeiro = True

        while mes_ref <= DATA_FIM:
            if rng.random() > p_ativo:
                break
            ini_mes = max(mes_ref, inicio)
            fim_mes = min(_fim_do_mes(mes_ref), DATA_FIM)
            if ini_mes > fim_mes:
                break
            janela = (fim_mes - ini_mes).days + 1

            # Quantos dias jogou no mes (casual x recorrente).
            n = rng.choices(PERFIL["dias_mes"][0], weights=PERFIL["dias_mes"][1], k=1)[0]
            if primeiro:
                n = max(1, round(n * _HONEYMOON))
            n = min(n, janela)
            dias.extend(ini_mes + timedelta(days=o) for o in rng.sample(range(janela), n))

            p_ativo *= PERFIL["decay"]
            primeiro = False
            mes_ref = (date(mes_ref.year + 1, 1, 1) if mes_ref.month == 12
                       else date(mes_ref.year, mes_ref.month + 1, 1))
        return sorted(set(dias))

    def gerar(self) -> dict[str, int]:
        rng = self.rng
        cfg = self.cfg
        afiliados = self.afiliados()
        jogadores = self.jogadores(afiliados)

        self._escrever("affiliates_agg",
                       ["Affiliate_Id", "Affiliate_Name", "Affiliate_Manager", "update_time"],
                       afiliados)

        self._escrever("acquisitions_agg",
                       ["User_Id", "Registration_Date", "Acquisition_Channel",
                        "Affiliate_Id", "Affiliate_Name", "btag"],
                       ({k: j[k] for k in ("User_Id", "Registration_Date",
                                           "Acquisition_Channel", "Affiliate_Id",
                                           "Affiliate_Name", "btag")} for j in jogadores))

        # FTD + atividade: uma passada, escrevendo em quatro arquivos.
        with self._writer("ftd_agg", ["User_Id", "FTD_Date", "FTD_Amount", "FTD_QTD",
                                      "Affiliate_Id", "Affiliate_Name", "Affiliate_Manager"]) as w_ftd, \
             self._writer("casino_agg_hourly", ["User_Id", "Date_Time", "Date_Agg", "Provider_Name",
                                                "Bet_Count", "Turnover", "GGR", "NGR"]
                          + (["turnover_bonus"] if cfg["tem_turnover_bonus"] else [])) as w_cas, \
             self._writer("sports_agg_hourly", ["User_Id", "Date_Time", "Date_Agg",
                                                "Bet_Count", "Turnover", "GGR", "NGR"]
                          + (["turnover_bonus"] if cfg["tem_turnover_bonus"] else [])) as w_spo, \
             self._writer("payments_agg_hourly", ["User_Id", "Date_Time", "Date_Agg", "Status",
                                                  "Deposits_Amount", "Deposits_Count",
                                                  "Withdrawals_Amount", "Withdrawals_Count",
                                                  "Netcash"]) as w_pay:

            for j in jogadores:
                if not j["converte"]:
                    continue
                uid = j["User_Id"]
                ftd_date = j["Registration_Date"] + timedelta(days=rng.choices(
                    [0, 1, 2, 5, 12, 30], weights=[45, 18, 12, 12, 8, 5], k=1)[0])
                if ftd_date > DATA_FIM:
                    continue
                ftd_valor = round(_lognormal(rng, PERFIL["valor_ftd"], 0.85), 2)
                w_ftd.writerow([uid, ftd_date, ftd_valor, 1, j["Affiliate_Id"],
                                j["Affiliate_Name"], j["Affiliate_Manager"]])

                # Perfil do jogador: quanto aposta e onde.
                escala = _lognormal(rng, 1.0, PERFIL["escala_sigma"])
                joga_casino = rng.random() < PERFIL["p_participa_a"]
                joga_sports = rng.random() < PERFIL["p_participa_b"]
                if not (joga_casino or joga_sports):
                    joga_casino = True
                # Margem da casa do jogador: a media fica ~4%, mas ha quem ganhe.
                margem_base = rng.gauss(*PERFIL["margem_a"])
                provedores_pref = rng.sample(PROVIDERS, k=rng.randint(1, 4))

                for dia in self._dias_ativos(ftd_date):
                    peso = _peso_dia(dia) * _peso_mes(dia)
                    if joga_casino:
                        # Uma linha por hora jogada x provedor: e o grao real da
                        # tabela `*_agg_hourly`, e o que faz o volume do DW.
                        for _ in range(rng.choices(PERFIL["linhas_dia_a"][0],
                                                   weights=PERFIL["linhas_dia_a"][1], k=1)[0]):
                            hora = rng.choices(range(24), weights=self._perfil_hora(), k=1)[0]
                            dt = datetime(dia.year, dia.month, dia.day, hora,
                                          rng.choice((0, 15, 30, 45)))
                            turnover = round(_lognormal(
                                rng, PERFIL["valor_a"] * escala * peso, PERFIL["valor_sigma_a"]), 2)
                            apostas = max(1, int(turnover / max(_lognormal(
                                rng, PERFIL["unitario_a"], PERFIL["unitario_sigma_a"]), 0.4)))
                            ggr = round(turnover * rng.gauss(
                                margem_base, PERFIL["margem_a_ruido"]), 2)
                            bonus, ngr = _bonus_e_ngr(rng, ggr)
                            linha = [uid, dt, dia, rng.choice(provedores_pref),
                                     apostas, turnover, ggr, ngr]
                            if cfg["tem_turnover_bonus"]:
                                linha.append(bonus)
                            w_cas.writerow(linha)
                    if joga_sports:
                        for _ in range(rng.choices(PERFIL["linhas_dia_b"][0],
                                                   weights=PERFIL["linhas_dia_b"][1], k=1)[0]):
                            hora = rng.choices(range(24), weights=self._perfil_hora(), k=1)[0]
                            dt = datetime(dia.year, dia.month, dia.day, hora,
                                          rng.choice((0, 15, 30, 45)))
                            turnover = round(_lognormal(
                                rng, PERFIL["valor_b"] * escala * peso, PERFIL["valor_sigma_b"]), 2)
                            apostas = max(1, int(turnover / max(_lognormal(
                                rng, PERFIL["unitario_b"], PERFIL["unitario_sigma_b"]), 1.0)))
                            ggr = round(turnover * rng.gauss(*PERFIL["margem_b"]), 2)
                            bonus, ngr = _bonus_e_ngr(rng, ggr)
                            # Idiossincrasia da Zephyr: sportsbook grava NGR = 0.
                            if cfg["sports_ngr_zero"]:
                                ngr = 0.0
                            linha = [uid, dt, dia, apostas, turnover, ggr, ngr]
                            if cfg["tem_turnover_bonus"]:
                                linha.append(bonus)
                            w_spo.writerow(linha)

                    # Pagamentos: no bet, deposita em ~55% dos dias ativos e saca as
                    # vezes; no e-commerce, quase todo pedido gera pagamento e uma
                    # fatia pequena vira reembolso/devolucao.
                    if rng.random() < PERFIL["p_pagamento"]:
                        hora = rng.choices(range(24), weights=self._perfil_hora(), k=1)[0]
                        dt = datetime(dia.year, dia.month, dia.day, hora, rng.choice((5, 20, 35, 50)))
                        qtd = rng.choices([1, 2, 3], weights=[70, 22, 8], k=1)[0]
                        dep = round(_lognormal(
                            rng, PERFIL["valor_pagamento"] * escala, 0.80) * qtd, 2)
                        saque, qtd_saque = 0.0, 0
                        if rng.random() < PERFIL["p_reembolso"]:
                            saque = round(_lognormal(
                                rng, PERFIL["valor_reembolso"] * escala, 0.9), 2)
                            qtd_saque = 1
                        w_pay.writerow([uid, dt, dia, self._status(rng), dep, qtd,
                                        saque, qtd_saque, round(dep - saque, 2)])

        # Tabela de gerentes (so a Lumen tem).
        if cfg["manager_table"]:
            self._escrever("affiliate_manager_lumen",
                           ["id", "username", "affiliate_manager", "channel_type"],
                           self._linhas_manager(cfg["manager_table"]))

        return self.contagens

    def _linhas_manager(self, tabela: list[tuple]) -> list[dict]:
        """Uma linha por parceiro + algumas duplicadas de username, porque o
        catalogo deduplica por `ROW_NUMBER() ... ORDER BY id DESC` e a duplicata
        e o caso que aquele CTE existe para tratar."""
        linhas = []
        for i, (username, manager, canal) in enumerate(tabela, start=1):
            linhas.append({"id": i, "username": username,
                           "affiliate_manager": manager, "channel_type": canal})
        # Versao antiga (id menor) de dois parceiros: apontava para outro gerente.
        linhas.append({"id": 900, "username": tabela[5][0],
                       "affiliate_manager": "AfiliadosAtivosCpa", "channel_type": "Afiliados"})
        linhas.append({"id": 901, "username": tabela[11][0],
                       "affiliate_manager": "TráfegoExterno", "channel_type": "Tráfego externo"})
        # Linha sem username: o catalogo filtra `WHERE username IS NOT NULL`.
        linhas.append({"id": 902, "username": None,
                       "affiliate_manager": "Desativado", "channel_type": None})
        return linhas

    @staticmethod
    def _perfil_hora() -> list[float]:
        """Curva de uso do dia: vale de madrugada, pico entre 19h e 23h."""
        return [3, 2, 1.5, 1, 1, 1, 1.5, 2.5, 3.5, 4, 4.5, 5,
                5.5, 5.5, 5.5, 6, 6.5, 7.5, 9, 10.5, 11, 10, 7.5, 5]

    def _status(self, rng: random.Random) -> str | None:
        if rng.random() < self.cfg["pct_status_nulo"]:
            return None
        return rng.choices(["Completed", "Pending", "Failed"],
                           weights=[88, 7, 5], k=1)[0]

    # -- escrita ------------------------------------------------------------ #
    def _caminho(self, tabela: str) -> Path:
        return self.destino / f"{self.base}.{tabela}.csv"

    def _writer(self, tabela: str, colunas: list[str]):
        return _CsvWriter(self, tabela, colunas)

    def _escrever(self, tabela: str, colunas: list[str], linhas) -> None:
        with self._writer(tabela, colunas) as w:
            for linha in linhas:
                w.writerow([linha[c] for c in colunas])


# Codificacao do arquivo de carga. Nao e UTF-8 de proposito: o BULK INSERT do
# SQL Server para Linux nao aceita a opcao CODEPAGE, entao os bytes do arquivo
# entram na coluna VARCHAR como estao — e a coluna usa o collation padrao do
# servidor (CP1252). Gravar UTF-8 aqui transformaria 'Tráfego externo' em
# 'TrÃ¡fego externo' e os filtros do catalogo, que comparam com o texto acentuado,
# deixariam de casar.
ENCODING_CARGA = "cp1252"


class _CsvWriter:
    """CSV com '|' como separador e campo vazio = NULL (BULK INSERT KEEPNULLS).

    Delimitador '|' e nao ',' porque nome de parceiro tem espaco e virgula e o
    BULK INSERT nao interpreta aspas por padrao. Sem cabecalho: a carga mapeia
    por posicao.
    """

    def __init__(self, gerador: GeradorBase, tabela: str, colunas: list[str]):
        self.gerador = gerador
        self.tabela = tabela
        self.colunas = colunas
        self.n = 0

    def __enter__(self):
        self._fh = self.gerador._caminho(self.tabela).open(
            "w", encoding=ENCODING_CARGA, errors="strict", newline="\n")
        self._w = csv.writer(self._fh, delimiter="|", lineterminator="\n",
                             quoting=csv.QUOTE_NONE, escapechar="\\")
        return self

    def writerow(self, valores: list) -> None:
        self._w.writerow(["" if v is None else _fmt(v) for v in valores])
        self.n += 1

    def __exit__(self, *exc):
        self._fh.close()
        self.gerador.contagens[self.tabela] = self.n


def _fmt(v) -> str:
    if isinstance(v, datetime):
        return v.strftime("%Y-%m-%d %H:%M:%S")
    if isinstance(v, date):
        return v.isoformat()
    return str(v)


def gerar_tudo(destino: Path, bases: list[str]) -> dict[str, dict[str, int]]:
    destino.mkdir(parents=True, exist_ok=True)
    resumo = {}
    for base_key in bases:
        gerador = GeradorBase(base_key, BASES[base_key], destino)
        resumo[base_key] = gerador.gerar()
    return resumo


if __name__ == "__main__":   # geracao local, sem banco: `python generate.py /tmp/out`
    import sys
    alvo = Path(sys.argv[1] if len(sys.argv) > 1 else "./out")
    inicio = datetime.now()
    res = gerar_tudo(alvo, list(BASES))
    print(f"janela: {DATA_INI} .. {DATA_FIM}  ({DIAS_TOTAL} dias)")
    total = 0
    for base, tabelas in res.items():
        soma = sum(tabelas.values())
        total += soma
        print(f"\n{base}: {soma:,} linhas")
        for t, n in tabelas.items():
            print(f"   {t:24} {n:>10,}")
    print(f"\nTOTAL: {total:,} linhas em {(datetime.now() - inicio).total_seconds():.1f}s")
