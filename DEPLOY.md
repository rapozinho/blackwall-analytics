# Deploy — BlackWall Analytics

Guia para quem vai subir isto num servidor. Leia a seção de segurança **antes**
do primeiro `up`: hoje a aplicação não tem login.

## O que sobe

| Serviço | Imagem | Porta | Papel |
|---|---|---|---|
| `sqlserver` | `mssql/server:2022-latest` | 11433 → 1433 (localhost) | Banco de demonstração: 4 bases fictícias |
| `dbinit` | `python:3.11-slim` + ODBC | — | Cria bases + login read-only, gera e carrega os dados. Roda uma vez e sai |
| `backend` | `python:3.11-slim` + ODBC | 8000 (interna) | API FastAPI, consultas read-only ao SQL Server |
| `frontend` | `nginx:1.27-alpine` | 8080 → 80 | Arquivos estáticos + proxy `/api` para o backend |

O backend **não publica porta**: quem fala com ele é o nginx, pela rede interna
do compose. O navegador só enxerga uma origem, então CORS não entra no caminho.

`backend` depende de `dbinit` com `service_completed_successfully`: se a carga
falhar, a API não sobe — melhor do que subir e responder erro em toda consulta.

## Subir

```bash
docker compose up -d --build
```

Não precisa de `.env`: as credenciais do ambiente local têm padrão no próprio
`docker-compose.yml`, e o banco é o container `sqlserver`. Para trocar, exporte
`MSSQL_SA_PASSWORD` e `DB_PASSWORD` (ou ponha num `.env` na raiz).

Abre em `http://127.0.0.1:8080`. Por padrão o compose publica **apenas em
localhost** — para expor na rede, ponha um proxy com TLS na frente e ajuste a
linha `ports`.

Verificação rápida:

```bash
curl http://127.0.0.1:8080/api/health/db   # testa as 4 bases; ~5s por base
docker compose run --rm --entrypoint python dbinit status.py         # linhas carregadas
docker compose run --rm --entrypoint python dbinit verify_catalog.py # 292 .sql compilam?
docker compose logs -f backend
```

### Apontar para um SQL Server de verdade

O `sqlserver` e o `dbinit` existem para a demonstração. Contra um warehouse real,
remova os dois serviços do compose (e o `depends_on` do backend) e passe
`SERVER`, `DB_USER`, `DB_PASSWORD` e os quatro `DATABASE_*` por variável de
ambiente ou secret do orquestrador. O backend não muda: ele nunca soube de onde
vinha a conexão.

## Variáveis

| Variável | Padrão | Observação |
|---|---|---|
| `SERVER`, `DB_USER`, `DB_PASSWORD` | — | Use um login **somente leitura** dedicado |
| `DATABASE_ZEPHYR`, `DATABASE_QUASAR`, `DATABASE_LUMEN`, `DATABASE_KESTREL` | — | Um database por base; a lista de bases é whitelist no código |
| `ODBC_DRIVER` | `ODBC Driver 18 for SQL Server` | A imagem traz o 17 e o 18 |
| `DB_ENCRYPT` | `yes` | TLS até o banco |
| `DB_TRUST_SERVER_CERTIFICATE` | `no` | `yes` só para certificado autoassinado interno — desliga a **validação**, não a criptografia |
| `AUTH_DISABLED` | `true` | **Ver segurança abaixo** |
| `CORS_ORIGINS` | vazio | Só precisa se o frontend for servido de outra origem |
| `PORTA_WEB` | `8080` | Porta publicada no host |
| `VERTICAL` | `bet` | `bet` ou `ecommerce`. Precisa ser o **mesmo** no `backend` e no `dbinit` — o `run.ps1` garante isso |
| `PORTA_SQL` | `11433` | Porta do SQL Server no host (só localhost) |
| `MSSQL_SA_PASSWORD` | `BlackWall!Dev2026` | Só do container de demonstração |
| `MSSQL_MEMORY_LIMIT_MB` | `6144` | Teto de memória do SQL Server — ver armadilha abaixo |
| `SEED_ESCALA` | `1` | Multiplica o volume de dados gerados |

### Driver 18 e TLS

O driver 18 exige TLS por padrão. Contra um SQL Server interno com certificado
autoassinado, a conexão falha com erro de certificado — e o sintoma na tela é
"sem conexão" em todas as bases. Nesse caso: `DB_TRUST_SERVER_CERTIFICATE=yes`.
O certo mesmo é emitir um certificado válido para o servidor e manter `no`.

É o caso do container de demonstração, que usa certificado autoassinado: o compose
já sobe com `DB_ENCRYPT=yes` e `DB_TRUST_SERVER_CERTIFICATE=yes`.

## Armadilhas confirmadas na primeira subida

Três coisas quebraram de verdade ao subir a stack, todas com sintoma que aponta
para o lugar errado. Ficam registradas porque nenhuma é óbvia no erro:

**1. `msodbcsql18` não puxa `libgssapi-krb5-2`.** Com `--no-install-recommends`, a
biblioteca não entra na imagem, e o driver a carrega por `dlopen`. O erro é:

```
[unixODBC][Driver Manager]Can't open lib '/opt/microsoft/msodbcsql18/lib64/libmsodbcsql-18.6.so.2.1' : file not found
```

O arquivo citado **existe**. O que falta é uma dependência dele — `ldd` no `.so`
mostra `libgssapi_krb5.so.2 => not found`. Corrigido nos dois Dockerfiles
(`backend/` e `db/`).

**2. `BULK INSERT ... CODEPAGE` não existe no SQL Server para Linux.**

```
Keyword or statement option 'CODEPAGE' is not supported on the 'Linux' platform.
```

Sem `CODEPAGE`, os bytes do arquivo entram na coluna `VARCHAR` como estão. Por isso
`db/generate.py` grava o CSV em **CP1252** (o collation padrão do servidor) e não em
UTF-8 — em UTF-8, `'Tráfego externo'` viraria `'TrÃ¡fego externo'` e os filtros do
catálogo, que comparam com o texto acentuado, deixariam de casar silenciosamente.

**3. Memory grant maior que o limite do workload group.** O monitoring de afiliados
da LumenBet pede ~1,1 GB de grant (hash join sobre a deduplicação por username) e o
limite do grupo `default` é 25% do pool:

```
Could not get the memory grant of 1153488 KB because it exceeds the maximum
configuration limit in workload group 'default'
```

Com `MSSQL_MEMORY_LIMIT_MB=2048` a query morre. O padrão do compose subiu para
`6144`. Em máquina apertada, diminua `SEED_ESCALA` em vez de baixar a memória.

## Segurança — leia antes de expor

### Bloqueador: não há autenticação

`auth.py` é um stub. Com `AUTH_DISABLED=true`, **qualquer pessoa que alcance a
porta vê GGR, depósitos, jogadores e afiliados das quatro operações, sem login**.
Com `false`, a API responde `501` e nada funciona — o SSO nunca foi integrado.

Enquanto isso não existir, o acesso precisa ser controlado por fora:

- rede fechada (VPN ou segmento interno), **e**
- proxy reverso com autenticação na frente (Entra ID / OAuth2 Proxy / mTLS), **e**
- TLS, porque as consultas trafegam em claro entre navegador e nginx.

Fechar só a rede não basta: qualquer máquina comprometida na VPN alcança tudo.

### Consultas são visíveis entre usuários

`GET /api/jobs` lista as consultas em andamento de **todos** e `GET /api/jobs/{id}`
devolve o resultado completo — não há noção de dono. Dois analistas no mesmo
servidor veem os relatórios um do outro. Ao integrar o SSO, o job precisa guardar
o usuário e os endpoints precisam filtrar por ele.

### O que já está tratado

- **SQL parametrizado.** Nenhum `.format()` monta SQL; `sqlcat.to_parameterized()`
  troca os placeholders por marcadores posicionais antes de executar. Data vinda
  do cliente é validada como `AAAA-MM-DD` e nunca concatenada.
- **Whitelist de base e de consulta.** `_resolve()` rejeita base ou gráfico fora
  do registry; o nome do database vem do `.env`, nunca do cliente.
- **Path traversal barrado** no catálogo de SQL (`load_sql` valida que o caminho
  fica dentro de `app/sql/`).
- **Senha removida dos erros** (`db.scrub`) antes de qualquer mensagem chegar ao
  navegador ou ao log.
- **Container sem privilégio:** usuário `blackwall` (uid 10001), sistema de
  arquivos read-only, `no-new-privileges`.
- **Segredo fora da imagem:** `.dockerignore` bloqueia `.env`; as credenciais
  entram por variável de ambiente.
- **Cabeçalhos no nginx:** CSP restrita, `nosniff`, `X-Frame-Options: DENY`,
  `frame-ancestors 'none'`.

### Dependências

`react-router-dom` está fixado em **6.30.4**. As versões anteriores da linha 6
tinham advisories *high* de open redirect; subir para a linha 7 troca essas por
outras (CSRF em RSC mode) e exige migração. Restam 3 advisories *moderate* sem
correção em nenhuma versão da linha 6:

- open redirect via `<Link>`/`useNavigate` — **não explorável aqui**: todo destino
  de navegação é interno e derivado da whitelist do backend, nunca de input do
  usuário ou de query string;
- `deserializeErrors` na hidratação SSR — **não aplicável**: isto é um SPA, sem SSR.

Revisar quando a linha 7 estabilizar.

## Limitações operacionais

- **Um worker só.** O estado das consultas vive na memória do processo
  (`jobs.py`). Subir réplicas faz cada uma enxergar uma lista diferente e o
  polling do navegador cair em 404 aleatoriamente. Para escalar: trocar o
  dicionário por Redis.
- **Reiniciar o backend perde as consultas em andamento.** O TTL é de 30 min e o
  estado não é persistido.
- **Consultas longas.** Contra o warehouse original, Overview levava ~65s e
  Monitoring passava de minutos; nas bases de demonstração (~900 mil linhas) tudo
  fica em segundos. Os timeouts do nginx estão em 300s — um proxy adicional na
  frente precisa do mesmo ajuste, senão corta a conexão no meio. O fluxo de job
  (`/start` + polling) existe por causa do cenário lento, não do rápido.
- **Estado dos jobs em memória.** Reiniciar o backend perde as consultas em
  andamento; TTL de 30 min, sem persistência.
- **O banco de demonstração não é produção.** `sqlserver` sobe com senha no
  compose, sem TLS válido e com `RECOVERY SIMPLE`. É um ambiente de portfólio: um
  warehouse real entra pelas variáveis de ambiente (ver acima).

## Estado dos testes

Executado nesta máquina (Docker Desktop, WSL2, linux/amd64):

| O que | Resultado |
|---|---|
| `docker compose up -d --build` (4 serviços) | sobe; `backend` e `frontend` ficam `healthy` |
| Criação das 4 bases + login read-only + carga | 913.849 linhas em ~15 s |
| `verify_catalog.py` (compilação) | **297/297 arquivos, 0 erros** |
| `verify_catalog.py --executar` | **297/297 executam, 0 erros**; único retorno vazio é o `.sql` comentado na origem |
| `GET /api/health/db` | `ok` nas 4 bases |
| Troca de vertical (`.\run.ps1 ecommerce` e volta para `bet`) | regera o dado (~15 s) e os 297 arquivos continuam rodando nas duas; voltar para `bet` reproduz as mesmas 913.849 linhas |
| Overview (dashboard) | KPIs, série de 30 dias, 3 donuts; nota da idiossincrasia da ZephyrBet aparece |
| Retention Cohort | 18 safras, queda média M0→M1 de 32% |
| Monitoring · Big Picture (A/D) · Report Master | rodam nas 4 bases pelo fluxo de job; Report Master entrega as 5 abas |

Não testado: navegador real (só as chamadas HTTP), `AUTH_DISABLED=false` (o SSO
continua sendo stub) e qualquer cenário multi-worker.
