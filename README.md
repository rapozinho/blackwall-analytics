# BlackWall Analytics

Portal interno de consulta de dados (rede/VPN da empresa). Fluxo:

```
[bases: F12 · LuvaBet · BrasilBet · GaleraBet]
        -> [galeria de gráficos da base (preview estático)]
        -> [clica gráfico -> filtro de data dinâmico]
        -> [render real: backend consulta o SQL Server (read-only) e devolve JSON]
```

Stack: **FastAPI** (backend) + **React/Vite** (frontend) + **Chart.js**.

## Segurança (resumo do desenho)
- Usuário SQL **somente leitura** dedicado; ideal expor apenas views/procs.
- SQL **sempre parametrizado**; `base`/`metric`/`chart` via **whitelist** (nunca SQL do cliente).
- Autenticação de aplicação além da VPN (SSO Microsoft Entra — stub em `app/auth.py`).
- Só endpoints GET read-only; rate-limit/cache a adicionar antes de produção.

## Rodar (dev)

Backend:
```bash
cd backend
python -m venv .venv && .venv\Scripts\activate    # Windows
pip install -r requirements.txt
copy .env.example .env      # preencher credenciais read-only
uvicorn app.main:app --reload --port 8000
```

Frontend:
```bash
cd frontend
npm install
npm run dev                 # Vite em :5173, proxy /api -> :8000
```

## Adicionar um gráfico novo
1. Cria `backend/app/charts/<id>.py` com `PARAMS` + `load(base, params) -> dict`.
2. Registra em `backend/app/registry.py` (`CHARTS`).
3. Front descobre sozinho via `/api/charts` — sem mudar UI.
