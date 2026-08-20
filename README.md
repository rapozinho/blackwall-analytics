# BlackWall Analytics

Portal de BI para operações de apostas: uma galeria de relatórios por base, filtro
de período, e o backend consultando um data warehouse SQL Server em modo somente
leitura.

```
[bases: ZephyrBet · QuasarBet · LumenBet · KestrelBet]
        -> [galeria de gráficos da base (preview estático)]
        -> [clica gráfico -> filtro de data dinâmico]
        -> [render real: backend consulta o SQL Server (read-only) e devolve JSON]
```

Stack: **FastAPI** + **React/Vite** + **Chart.js**, sobre **SQL Server**, tudo em
**Docker**.

> **Esta é a versão de demonstração.** As quatro bases (`ZephyrBet`, `QuasarBet`,
> `LumenBet`, `KestrelBet`) são fictícias e o banco sobe junto com a aplicação,
> populado por um gerador de dados sintéticos (`db/`). Nenhuma credencial, nome de
> operação ou registro real de terceiro faz parte do repositório — o que ficou
> igual é o que interessa tecnicamente: os **292 arquivos de T-SQL** do catálogo,
> o modelo do warehouse e o caminho completo da requisição.

## Abrir no navegador

**Demo ao vivo: https://rapozinho.github.io/blackwall-analytics/** — abre direto, sem instalar nada.

O que está no ar é o frontend em **modo demonstração**: não existe backend nem
banco por trás de uma página do GitHub Pages, então a aplicação lê snapshots dos
payloads da própria API, capturados da stack real por `tools/gen_fixtures.py`. Os
números são os que o SQL Server devolveu; o que não roda ali é a consulta. Um
filtro fora dos snapshots capturados cai no período padrão e a barra do topo diz
isso na cara.

O snapshot publicado é o da vertical de **e-commerce** — as bases aparecem como
`Nordika`, `Vellora`, `Cintra` e `Kaya`, e as métricas são GMV, take rate, receita
por cliente. O mesmo código serve a vertical de apostas com `VERTICAL=bet`
(seção [Duas verticais no mesmo código](#duas-verticais-no-mesmo-código)); trocar
a publicação é regerar os fixtures com a stack na outra vertical.

As três bandeiras no canto direito do topo trocam o idioma da aplicação inteira —
**português, espanhol e inglês** — incluindo o que é gerado no backend: rótulo de
métrica, aba de report, frase de insight e mensagem de erro. Ver
[Três idiomas](#três-idiomas).

Para ver a coisa consultando o banco de verdade — as 292 queries T-SQL, o job com
progresso, o cancelamento derrubando a query no servidor — é `docker compose up`
na sua máquina (seção seguinte).

| | Demo do Pages | Stack local |
|---|---|---|
| Backend / banco | não sobe | FastAPI + SQL Server 2022 |
| Origem do dado | JSON capturado (`frontend/public/fixtures/`) | consulta ao warehouse |
| Filtro | os snapshots capturados | qualquer período |
| Custo para abrir | um clique | Docker + ~6 GB de RAM |

## Subir

Só precisa de Docker. Escolha a vertical na hora de subir:

```powershell
.\run.ps1              # apostas (padrão)
.\run.ps1 ecommerce    # e-commerce
```

Equivalente, sem o script:

```bash
docker compose up -d --build                    # apostas
VERTICAL=ecommerce docker compose up -d --build  # e-commerce
# -> http://127.0.0.1:8080
```

Sem `.env`, sem credencial, sem rede externa. A ordem é `sqlserver` → `dbinit`
(cria as 4 bases, gera e carrega os dados, então sai) → `backend` → `frontend`.
O backend só inicia depois que o `dbinit` termina com sucesso.

```bash
docker compose logs -f dbinit                 # o que foi criado e carregado
curl http://127.0.0.1:8080/api/health/db      # as 4 bases devem responder "ok"
docker compose down                           # para tudo (mantém os dados)
docker compose down -v                        # apaga também as bases
```

Porta 8080 ocupada? `.\run.ps1 -Porta 8090` (ou `PORTA_WEB=8090 docker compose up -d`).

## Duas verticais no mesmo código

O portal roda em **apostas** ou em **e-commerce**, e a escolha é uma variável:
`VERTICAL=bet` (padrão) ou `VERTICAL=ecommerce`.

Não são duas aplicações, nem dois catálogos de SQL: os 292 `.sql` continuam
intocados. A modelagem do warehouse é a mesma — cliente, transação, receita — e o
que troca é o vocabulário, a ordem de grandeza dos números e o nome das bases.

| | `bet` | `ecommerce` |
|---|---|---|
| Bases | ZephyrBet · QuasarBet · LumenBet · KestrelBet | Nordika · Vellora · Cintra · Kaya |
| `Turnover` | Turnover (volume apostado) | **GMV** |
| `GGR` | GGR (ganho da casa) | **Receita** (comissão 3P + margem 1P) |
| `NGR` | NGR (GGR − bônus) | **Margem de contribuição** (receita − cupons) |
| `Margin` | Margem (GGR/Turnover) | **Take rate** |
| `Hold` | Hold (NGR/GGR) | **Margem líquida** |
| `Bet_Count` | Apostas | **Itens** |
| `casino_agg_hourly` | Casino | **Marketplace (3P)** |
| `sports_agg_hourly` | Sportsbook | **Loja própria (1P)** |
| `Provider_Name` | Provedor de jogo | **Seller** |
| `ftd_agg` | FTD (1º depósito) | **1ª compra** |
| `Deposits`/`Withdrawals` | Depósitos / Saques | **Pagamentos aprovados / Reembolsos** |
| `UAP` · `ARPU` | Jogadores ativos · ARPU | **Clientes ativos · Receita por cliente** |

Onde isso vive:

| Arquivo | Papel |
|---|---|
| `backend/app/vertical.py` | Rótulo das bases, termo de cada métrica e `traduz()` — a tradução do texto que vem **de dentro do SQL** (nome de coluna, valor de célula) |
| `db/verticals.py` | Perfil econômico do dado gerado: ticket, take rate, frequência de compra |
| `GET /api/meta` | Vertical ativa e o vocabulário dela, para o frontend rotular a série e o split das duas operações |

Três detalhes que essa abordagem exige:

- **A chave interna da base não muda** (`Zephyr`, `Quasar`, `Lumen`, `Kestrel`):
  ela nomeia a pasta do catálogo e o database. Trocar exigiria editar SQL. O que o
  usuário vê é o rótulo — então no modo e-commerce o `/api/health/db` continua
  mostrando `dw_zephyr`, que é nome de infraestrutura, não de marca.
- **Os valores de texto que o catálogo filtra são os mesmos nas duas verticais**
  (`affiliate_manager IN ('GoogleAds', …)`, `channel_type = 'Afiliados'`,
  `acquisition_channel = 'Others'`). Mudar o dado quebraria o filtro; quem troca é
  a exibição. É por isso que `traduz()` também roda sobre o **valor** das células,
  não só sobre o cabeçalho.
- **Trocar de vertical regera o dado.** O marcador de carga leva a vertical no
  nome (`1.6.0-ecommerce`), então o `dbinit` percebe a troca e recarrega — ~15 s,
  sem precisar de `docker compose down -v`.

### Volume por vertical

A diferença de tamanho não é arbitrária: apostador ativo joga várias horas no
mesmo dia (várias linhas por dia), cliente de varejo faz um pedido e volta semanas
depois.

| | `bet` | `ecommerce` |
|---|---:|---:|
| Linhas totais | 913.849 | 128.301 |
| `casino_agg_hourly` (Zephyr/Nordika) | 197.637 | 14.376 |
| Pedidos por cliente ativo no mês | — | ~3 |
| AOV / ticket médio do pedido | — | ~R$ 380 |
| Take rate | — | ~20,7% |
| Devolução sobre pagamentos | — | 3,5%–7,8% |
| Conversão cadastro → 1ª compra | 43% | 43% |

## Segurança (resumo do desenho)
- Usuário SQL **somente leitura** dedicado (`blackwall_ro`, só em `db_datareader`);
  ideal expor apenas views/procs.
- SQL **sempre parametrizado**; `base`/`metric`/`chart` via **whitelist** (nunca SQL do cliente).
- Autenticação de aplicação além da VPN (SSO Microsoft Entra — stub em `app/auth.py`).
- Só endpoints GET read-only; rate-limit/cache a adicionar antes de produção.

## Rodar sem Docker (dev)

Requisitos: **Python 3.11**, Node 18+, ODBC Driver 18 for SQL Server — e o banco
de pé (`docker compose up -d sqlserver dbinit`, que publica o SQL Server em
`127.0.0.1:11433`).

### Atalho: sobe tudo de uma vez

```powershell
.\dev.cmd            # ou:  .\dev.ps1
```

Faz o bootstrap que falta (venv 3.11, `pip install`, `npm install`, `.env`), sobe
backend + frontend no mesmo console e abre o browser. `Ctrl+C` encerra os dois.

Flags: `-NoBrowser`, `-KillStale` (mata processo velho preso na porta),
`-BackendPort`, `-FrontendPort`.
Se uma porta estiver ocupada o script **aborta** em vez de deixar o Vite cair para
5174 — fallback silencioso quebra o proxy `/api` de forma difícil de debugar.

Passo a passo manual (equivalente):

> Use 3.11, não 3.12+. Em Python 3.14 o `pydantic-core` pinado (via `pydantic==2.9.2`)
> não tem wheel; o pip cai no build via Rust/maturin e falha
> (`the configured Python interpreter version (3.14) is newer than PyO3's maximum supported version (3.13)`).

Backend:
```bash
cd backend
py -3.11 -m venv .venv && .venv\Scripts\activate    # Windows
pip install -r requirements.txt
copy .env.example .env      # ja aponta para o SQL Server do compose (:11433)
uvicorn app.main:app --reload --port 8000
```

Frontend:
```bash
cd frontend
npm install
npm run dev                 # Vite em :5173, proxy /api -> :8000
```

## Diagnosticar a conexão com o banco

```
GET /api/health/db
```

Testa cada base da whitelist: config do `.env` → login → tabelas exigidas pelos
gráficos habilitados. Login timeout curto (5s), read-only, e a senha nunca aparece
na resposta.

Status por base: `ok` · `not_configured` (falta valor no `.env`) ·
`missing_tables` (conectou, mas falta tabela ou `GRANT SELECT`) · `error`
(com `sqlstate` + `hint` do que olhar).

## Bases de demonstração (`db/`)

O banco não é um mock na camada da aplicação: é **SQL Server de verdade**, com o
mesmo schema que o catálogo espera. Foi assim de propósito — trocar o banco por
stub em Python faria os 292 arquivos de T-SQL, que são a parte densa do projeto,
deixarem de rodar.

| Arquivo | Papel |
|---|---|
| `db/schema.sql` | DDL das 6 tabelas de agregado por base + índices |
| `db/schema_manager.sql` | `affiliate_manager_lumen` — existe só na base LumenBet |
| `db/bases.py` | Configuração das 4 bases: volume, domínios de texto, idiossincrasias |
| `db/generate.py` | Gerador dos dados sintéticos (CSV) |
| `db/init.py` | Cria bases e login read-only, aplica schema, carrega por `BULK INSERT` |
| `db/verify_catalog.py` | Compila/executa **todo** o catálogo contra as bases |
| `db/status.py` | Linhas por tabela e versão do seed carregada |

### O que é gerado

18 meses (`2025-03-01` … `2026-08-07`), ~6k jogadores na maior base. Não é ruído
aleatório: cadastro cresce ao longo do período e pesa em fim de semana, conversão
em FTD depende do canal, retenção decai por safra (o Retention Cohort precisa de
curva), GGR sai de turnover × margem da casa — com jogador que ganha no mês, que é
o que alimenta o segmento *Negative* do Report Master.

| Tabela | ZephyrBet | QuasarBet | LumenBet | KestrelBet |
|---|---:|---:|---:|---:|
| `casino_agg_hourly` | 197.637 | 142.536 | 168.918 | 98.035 |
| `sports_agg_hourly` | 58.275 | 40.500 | 50.700 | 29.497 |
| `payments_agg_hourly` | 32.489 | 23.591 | 28.074 | 16.381 |
| `acquisitions_agg` | 6.000 | 4.400 | 5.200 | 3.000 |
| `ftd_agg` | 2.785 | 1.988 | 2.373 | 1.390 |
| `affiliates_agg` | 14 | 16 | 16 | 16 |
| `affiliate_manager_lumen` | — | — | 18 | — |

Total **913.849** linhas; geração + carga em **~15 s**. Conferir a qualquer
momento:

```bash
docker compose run --rm --entrypoint python dbinit status.py
```

`SEED_ESCALA=4 docker compose up` multiplica o número de jogadores por 4 sem mexer
em código. A semente do RNG é fixa por base: subir duas vezes dá exatamente o mesmo
dado, então print de tela e número de relatório continuam batendo.

### As idiossincrasias das bases foram reproduzidas

O backend tem código que existe só por causa de peculiaridade de base. Se o dado
fictício fosse homogêneo, esse código ficaria morto e o portal mentiria sobre o
que sabe fazer:

- **ZephyrBet** grava `NGR = 0` no sportsbook — o Overview compara os dois
  verticais e avisa na tela (`charts/overview.py::_notas`); e 55% das linhas de
  `payments` vêm com `Status` nulo, que é o motivo do filtro `Status = 'Completed'`
  no catálogo inteiro.
- **QuasarBet** carrega o id dentro do texto do gerente (`'GoogleAds (444)'`).
- **LumenBet** não tem a coluna `turnover_bonus` — o `.sql` de bônus dela está
  inteiro comentado no catálogo, e a célula de Generosity sai vazia no Report
  Master. A coluna é removida na carga (`init.py`), não só deixada nula.
- **KestrelBet** usa `'Organic'` onde a LumenBet usa `'Others'`, e lê a tabela de
  gerentes da outra base por nome de 3 partes
  (`dw_lumen.dbo.affiliate_manager_lumen`) — é a única leitura cross-database do
  projeto, e o motivo pelo qual o login read-only precisa de usuário nas 4 bases.

Os valores de texto (`affiliate_manager`, `channel_type`, `acquisition_channel`)
não são decorativos: o catálogo filtra por eles. `db/bases.py` documenta, em cada
domínio, qual `.sql` o exige — mudar um nome lá sem mudar no SQL faz o report
voltar vazio.

### Verificar que o catálogo inteiro roda

```bash
# compila os 292 .sql (SET NOEXEC ON: resolve tabela, coluna e tipo) — ~2 s
docker compose run --rm --entrypoint python dbinit verify_catalog.py

# executa de verdade e aponta quem devolveu 0 linhas — ~15 s
docker compose run --rm --entrypoint python dbinit verify_catalog.py --executar
```

O schema foi derivado dos `.sql`, não o contrário; este script é o que garante que
não ficou coluna faltando. Saída esperada: `297 arquivos … 0 com erro`. O único
retorno vazio esperado é `lumen_rmc_bonus.sql`, que está comentado na origem.

Mudou o schema ou o gerador? Suba `SEED_VERSION` em `db/bases.py`: o `init.py`
recria as tabelas daquela base e recarrega, sem precisar de `docker compose down -v`.

## Reports disponíveis

| Report | `kind` | Bases | Períodos | Arquivos SQL |
|---|---|---|---|---|
| Overview operacional | `dashboard` | todas | 1 (compara com a janela anterior) | 4 |
| Retention Cohort | `chart` | Zephyr, Quasar, Lumen | 1 | 1 |
| Report Master | `tables` | Zephyr, Quasar, Lumen | 1 | 77 |
| Monitoring | `tables` | todas | 2 (comparação) | 2 |
| Big Picture - Acquisition | `tables` | todas | 2 (comparação) | 6 (7 na Lumen/Kestrel) |
| Big Picture - Distribution | `tables` | todas | 1 | 3 |

Monitoring e Big Picture usam **o mesmo SQL do `kpi-bot`**, copiado para
`backend/app/sql/`. Cada `bpa_query_N` devolve uma linha (um canal de aquisição)
com o mesmo schema, então elas são unidas numa tabela só — no bot são abas
separadas. Se algum schema divergir, o merge não acontece e as tabelas aparecem
separadas.

### Report Master

Réplica da planilha do bot: **5 abas** (Operational Overview, Casino, Sports, CRM
e Acquisition - All), cada uma com os cabeçalhos na ordem da referência e uma
linha larga de métricas. São 77 consultas por execução — **~45 s na Lumen,
minutos na Zephyr**.

Diferenças em relação ao xlsx do bot, todas em `reports/report_master.py`:

- As fórmulas do Excel (`=F2+G2`, `=Y2/I2`, …) são calculadas em Python. O CSV
  leva número, não fórmula.
- Percentual sai como número de 0 a 100; o SQL devolve fração e a conversão
  acontece no backend, porque o frontend só acrescenta o `%`.
- CRM e Acquisition têm linhas extras (segmentos Negative/Core/VIP; top 5 btags e
  canais de marketing), como na planilha.
- Coluna sem query fica vazia — inclusive **Bônus/Generosity na Lumen**, onde
  o `.sql` do bot está inteiro comentado porque a base não tem `turnover_bonus`.

Kestrel não entra: o bot não tem Report Master para ela.

### Consultas longas rodam como job

Uma query de Monitoring leva ~90s e o Big Picture - Acquisition passa de 5 min.
GET síncrono não sobrevive a isso, então:

```
GET /api/charts/<id>/start?base=…&<params>   -> { "job_id": "..." }
GET /api/jobs/<job_id>                        -> { status, progress, step, result|error }
```

`status`: `queued` · `running` · `done` · `error`. O frontend faz polling a cada
2s e mostra a barra de progresso com o arquivo atual.

`GET /api/charts/<id>/data` (síncrono) continua existindo para query rápida.

Detalhes que importam antes de produção:
- Estado dos jobs é **memória do processo**, com TTL de 30 min. Com mais de um
  worker uvicorn cada um teria seu próprio dicionário — trocar por Redis antes de
  escalar horizontalmente.
- Pool de 2 workers de propósito: o SQL Server é compartilhado com os bots.
- `start` é GET porque o projeto é read-only/GET-only (CORS só libera GET) e job
  aqui é cache de resultado, não recurso de negócio.

## Catálogo de SQL (`backend/app/sql/`)

O SQL vive em arquivo, não embutido no Python. Organizado por base:

```
backend/app/sql/
  graphics/retention_cohort.sql        # base-agnóstico (serve as 4 bases)
  Zephyr/bpa/zephyr_bpa_query_1..6.sql
  Zephyr/bpd/zephyr_bpd_query_1..3.sql
  Zephyr/monitoring/zephyr_monitoring_query.sql
  Zephyr/monitoring/zephyr_monitoring_affiliates_query.sql
  Quasar/…  Lumen/…  Kestrel/…     # mesma estrutura
```

O nome do arquivo repete a base (`Zephyr/bpa/zephyr_bpa_...`) de propósito: mantém o
nome idêntico ao do `kpi-bot`, o que facilita diff quando o SQL mudar lá.

Os `.sql` usam a convenção de placeholders do `kpi-bot` (`{start1}`,
`{end1}`, `{start2}`, `{end2}`) para que o mesmo arquivo sirva aos dois projetos.

O bot injeta com `.format()`. **Aqui nunca interpolamos**:
`sqlcat.to_parameterized()` troca cada placeholder por marcador posicional e
devolve os valores na ordem, para o pyodbc.

```python
sql, params = to_parameterized(load_sql("graphics/retention_cohort.sql"),
                               {"start1": start, "end1": end})
rows = run_query(base_key, sql, params)
```

Comentários (`--`, `/* */`) e literais de string passam intactos — placeholder
citado em comentário não é substituído. Não escreva marcador posicional literal
dentro de um `.sql`: ele contaria como parâmetro extra.

`{affiliate_ids}` ainda não é suportado — no catálogo do bot ele aparece como
`IN ({affiliate_ids})` e como `= {affiliate_ids}`, e a conversão correta depende
de qual. `to_parameterized()` levanta `ValueError` em vez de adivinhar.

### Percentuais: número no SQL, `%` na exibição

**Regra do catálogo: coluna de percentual devolve número, nunca texto.** Não
escreva `CAST(... AS VARCHAR) + '%'` — o `%` é formatação do frontend.

No bot isso era inconsistente (`bpa_query_1` numérico, `2..6` texto; monitoring
da Quasar texto e das outras bases numérico). Como no site as queries de BPA são
unidas numa tabela só, a mesma coluna vinha com dois tipos. Normalizado: 52
`CAST(... AS VARCHAR) + '%'` viraram `CAST(... AS DECIMAL(n,2))`.

`tabular._percent_columns()` marca a coluna como percentual quando o **nome**
casa com `percent|%` **e** todos os valores são numéricos — se algum vier como
texto a coluna não entra, para não gerar `12,34%%`. O frontend usa essa lista
(`percent_columns`) para exibir `-10,83%`; o CSV exporta o número puro.

## Demo estática (o que o GitHub Pages serve)

A publicação é um build do frontend com `VITE_DEMO=1`. Nesse modo, `lib/demo.ts`
entra no lugar do `fetch("/api/...")` de `lib/api.ts` e responde a partir de
`frontend/public/fixtures/`:

```
tools/gen_fixtures.py  --api http://127.0.0.1:8080   # captura contra a stack real
  -> frontend/public/fixtures/<pt|es|en>/manifest.json   # params de cada arquivo
  -> frontend/public/fixtures/<pt|es|en>/data__<grafico>__<base>[__<variacao>].json
```

O snapshot cobre os 6 relatórios nas 4 bases, mais variações de período no
Overview e as três visões do Retention Cohort: 39 payloads por idioma, 141
arquivos no total, ~1,3 MB.

**Uma pasta por idioma** porque o texto vem do backend: o mesmo número sai como
"Receita", "Ingresos" ou "Revenue" conforme o `lang=` da requisição. Trocar a
bandeira troca a pasta que a demo lê.

A vertical vai gravada em `manifest.json` (`"vertical": "ecommerce"`), porque ela
muda as duas coisas: o rótulo de cada métrica e a ordem de grandeza do dado
gerado. Para publicar a outra, suba a stack com `VERTICAL=bet` e regere — a barra
do topo passa a dizer "vertical de apostas" sozinha.

Detalhes que a demo mantém de propósito, porque são parte do desenho:

- **O fluxo de job.** A interface inicia a consulta, recebe um id e faz polling
  até terminar; o botão de encerrar continua ali. Na demo o "trabalho" é ler um
  JSON, mas a tela é a mesma.
- **A duração real.** Ao concluir, o tempo mostrado é o que a consulta levou no
  servidor quando o snapshot foi capturado — não o tempo de baixar o arquivo.
- **Rotas no hash.** O Pages não tem rewrite de SPA, então o build de demo usa
  `HashRouter`. Servido pelo nginx do compose, o caminho normal continua.

Regerar depois de mexer em gráfico ou report: suba a stack, rode o script e
comite os fixtures. O deploy é o workflow `.github/workflows/pages.yml`, em todo
push na `main`.

## Três idiomas

Português, espanhol e inglês, trocados pelas bandeiras no topo. O que muda não é
só a casca: **o texto gerado no backend também sai traduzido** — nome de KPI,
descrição de relatório, aba de planilha, frase de insight, abreviação de mês,
mensagem de erro de validação e até o separador decimal.

O idioma é uma dimensão *ortogonal* à vertical de negócio. A vertical decide qual
é o conceito (a mesma coluna do warehouse é "GGR" numa operação de apostas e
"Receita" num e-commerce); o idioma decide em que língua esse conceito aparece:

```
                       pt              es                en
bet        .GGR        GGR             GGR               GGR
ecommerce  .GGR        Receita         Ingresos          Revenue
ecommerce  .turnover   GMV             GMV               GMV
ecommerce  .uap        Clientes ativos Clientes activos  Active customers
```

Três catálogos, separados por origem do texto:

| Arquivo | O que guarda |
|---|---|
| `backend/app/vocab/terms.py` | vocabulário de negócio: `[vertical][idioma][chave]` |
| `backend/app/vocab/glossary.py` | substituições no texto que vem **de dentro do SQL** |
| `backend/app/vocab/messages.py` | texto de produto: filtro, progresso, erro, insight |
| `frontend/src/lib/i18n.tsx` | a casca: menu, botão, aviso, rótulo de coluna da tela |

O idioma da requisição vive num `ContextVar` (`backend/app/i18n.py`) fixado por
uma dependência do router a partir de `?lang=`, e não num parâmetro carregado de
função em função: quem consome idioma é a *saída*, e ela está espalhada por todo
o caminho da consulta. Quem sai da thread da requisição leva o contexto por
cópia — `charts/overview.py` e `reports/report_master.py` já faziam isso pelo id
do job, e `jobs.py` passou a fazer pelo mesmo motivo.

Duas conferências rodam no import, porque erro de tradução não pode aparecer só
quando alguém abre aquela tela naquela língua:

- as 6 combinações de `terms.py` (2 verticais × 3 idiomas) têm as mesmas chaves;
- cada mensagem tem os **mesmos placeholders** nos três idiomas (um `{m}` perdido
  na tradução seria `KeyError` no meio de uma consulta de 3 minutos).

O que **não** é traduzido, de propósito: o nome das bases (`Nordika` é nome de
operação, não palavra), os 292 arquivos de T-SQL (o glossário age na saída), e os
termos de mercado que não se traduzem — GGR, NGR, GMV, take rate, netcash, seller.

## Adicionar um gráfico novo
1. Cria o SQL em `backend/app/sql/<grupo>/<id>.sql`.
2. Cria `backend/app/charts/<id>.py` com `PARAMS`, `REQUIRED_TABLES` e
   `load(base, params, on_progress=None) -> dict`, lendo o SQL via
   `load_sql`/`to_parameterized`.
3. Registra em `backend/app/registry.py` (`CHARTS`) com `kind: "chart"` e
   `required_tables` — é isso que o `/api/health/db` usa para checar grants.
4. Front descobre sozinho via `/api/charts`. Para `kind: "chart"` novo é preciso
   uma view dedicada; `kind: "tables"` já renderiza sozinho.

## Adicionar um report tabular novo
1. Copia os `.sql` para `backend/app/sql/<Base>/<grupo>/`, um por base, mantendo
   o prefixo do nome (`zephyr_`, `quasar_`, `lumen_`, `kestrel_`).
2. Adiciona uma entrada em `SPECS` (`backend/app/reports/tabular.py`): pasta,
   `files` (lista fixa) ou `prefix` (varre a pasta), `dual_period` e, se as
   queries compartilham schema, `merge`.
3. Pronto — o registry gera a entrada e a UI renderiza sem código novo.
