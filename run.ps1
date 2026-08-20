# BlackWall Analytics — sobe a stack na vertical escolhida.
#
#   .\run.ps1                 # bet (padrao)
#   .\run.ps1 ecommerce       # e-commerce
#   .\run.ps1 bet -Porta 8090
#   .\run.ps1 ecommerce -Escala 3      # 3x mais clientes no dado gerado
#   .\run.ps1 -Parar
#
# Existe por um motivo so: `VERTICAL` precisa chegar igual no `dbinit` (que gera o
# dado) e no `backend` (que rotula). Passar na mao em dois lugares e a forma mais
# facil de acabar com numero de aposta escrito "GMV" na tela.
#
# Trocar de vertical NAO exige apagar volume: o marcador de carga leva a vertical
# no nome (`1.3.0-ecommerce`), entao o `dbinit` percebe a troca e regera o dado.

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('bet', 'ecommerce')]
    [string]$Vertical = 'bet',

    [int]$Porta = 8080,
    [double]$Escala = 1,
    [switch]$Parar,
    [switch]$SemBuild,
    [switch]$Logs
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

# Docker Desktop instalado por usuario nao entra no PATH da sessao.
function Resolve-Docker {
    $cmd = Get-Command docker -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidatos = @(
        "$env:LOCALAPPDATA\Programs\DockerDesktop\resources\bin\docker.exe",
        "$env:ProgramFiles\Docker\Docker\resources\bin\docker.exe"
    )
    foreach ($c in $candidatos) { if (Test-Path $c) { return $c } }
    throw "docker.exe nao encontrado. Instale o Docker Desktop ou ponha o docker no PATH."
}

$docker = Resolve-Docker

# O docker escreve o progresso do build em stderr. Com $ErrorActionPreference='Stop'
# o PowerShell 5.1 embrulha cada linha num ErrorRecord e aborta o script no meio de
# um build que estava indo bem. Dentro desta funcao o comportamento volta para
# 'Continue' e quem decide se falhou e o codigo de saida.
#
# O codigo de saida vai para $script:DockerExit e NAO pelo `return`: em PowerShell
# tudo que a funcao escreve entra no valor de retorno, e a saida do build viria
# junto com o numero.
function Invoke-Docker {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    $ErrorActionPreference = 'Continue'
    & $docker @Args
    $script:DockerExit = $LASTEXITCODE
}

if ($Parar) {
    Write-Host "Parando a stack (os dados ficam no volume)..." -ForegroundColor Cyan
    Invoke-Docker compose down
    return
}

$env:VERTICAL = $Vertical
$env:PORTA_WEB = "$Porta"
$env:SEED_ESCALA = "$Escala"

$rotulo = if ($Vertical -eq 'bet') { 'Apostas (ZephyrBet, QuasarBet, LumenBet, KestrelBet)' }
          else { 'E-commerce (Nordika, Vellora, Cintra, Kaya)' }

Write-Host ""
Write-Host "  vertical : $Vertical  ->  $rotulo" -ForegroundColor Green
Write-Host "  web      : http://127.0.0.1:$Porta"
Write-Host "  escala   : ${Escala}x"
Write-Host ""

$argumentos = @('compose', 'up', '-d')
if (-not $SemBuild) { $argumentos += '--build' }

Invoke-Docker @argumentos
if ($script:DockerExit -ne 0) {
    Write-Host ""
    Write-Host ("Falhou (exit {0}). Porta {1} ocupada? tente: .\run.ps1 {2} -Porta 8090" -f `
        $script:DockerExit, $Porta, $Vertical) -ForegroundColor Yellow
    exit $script:DockerExit
}

# O dbinit roda e sai; se a vertical mudou, ele regerou o dado antes do backend subir.
Invoke-Docker compose logs dbinit --tail 6

Write-Host ""
Write-Host "Pronto: http://127.0.0.1:$Porta" -ForegroundColor Green
Write-Host "Conferir: curl http://127.0.0.1:$Porta/api/meta" -ForegroundColor DarkGray

if ($Logs) { Invoke-Docker compose logs -f backend }
