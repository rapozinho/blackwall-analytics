# Sobe backend (FastAPI :8000) e frontend (Vite :5173) juntos.
# Uso:  .\dev.ps1  [-NoBrowser] [-KillStale] [-Lan] [-BackendPort 8000] [-FrontendPort 5173]
# Ctrl+C encerra os dois.

[CmdletBinding()]
param(
    [int]$BackendPort = 8000,
    [int]$FrontendPort = 5173,
    [switch]$NoBrowser,
    # Mata quem estiver ocupando as portas antes de subir (util quando sobra
    # um uvicorn/vite orfao de uma execucao anterior).
    [switch]$KillStale,
    # Publica o frontend na rede local (colega no mesmo escritorio abre pelo seu
    # IP). O backend continua so em localhost: quem vem de fora entra pelo proxy
    # do Vite, entao basta uma porta aberta.
    #
    # ATENCAO: o site nao tem login (AUTH_DISABLED). Qualquer um que alcance a
    # porta ve os dados das quatro bases. Use para mostrar algo pontual, nao
    # como acesso permanente.
    [switch]$Lan
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$backend = Join-Path $root 'backend'
$frontend = Join-Path $root 'frontend'
$venvPy = Join-Path $backend '.venv\Scripts\python.exe'
$procs = @()

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host "!!  $msg" -ForegroundColor Yellow }

function Get-PortOwners([int]$port) {
    $conns = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if (-not $conns) { return @() }
    return @($conns | Select-Object -ExpandProperty OwningProcess -Unique)
}

function Stop-All {
    foreach ($p in $procs) {
        if ($null -ne $p -and -not $p.HasExited) {
            # taskkill /T para matar a arvore (uvicorn --reload e npm criam filhos)
            & taskkill /PID $p.Id /T /F 2>$null | Out-Null
        }
    }
}

try {
    # ---------- bootstrap backend ----------
    if (-not (Test-Path $venvPy)) {
        Write-Step 'venv do backend nao existe. Criando com Python 3.11...'
        $py311 = (& py -3.11 -c "import sys; print(sys.executable)" 2>$null)
        if (-not $py311) {
            throw "Python 3.11 nao encontrado. Instale o 3.11 (o pydantic pinado nao tem wheel para 3.12+/3.14)."
        }
        & py -3.11 -m venv (Join-Path $backend '.venv')
        if (-not $?) { throw 'Falha ao criar o venv.' }
        Write-Step 'Instalando requirements.txt...'
        & $venvPy -m pip install -r (Join-Path $backend 'requirements.txt')
        if ($LASTEXITCODE -ne 0) { throw 'pip install falhou.' }
    }

    $envFile = Join-Path $backend '.env'
    if (-not (Test-Path $envFile)) {
        Write-Step 'Criando backend/.env a partir do .env.example...'
        Copy-Item (Join-Path $backend '.env.example') $envFile
        Write-Warn 'backend/.env aponta para o SQL Server do compose (127.0.0.1:11433). Suba o banco com: docker compose up -d sqlserver dbinit'
    }

    # ---------- bootstrap frontend ----------
    if (-not (Test-Path (Join-Path $frontend 'node_modules'))) {
        Write-Step 'Instalando deps do frontend (npm install)...'
        Push-Location $frontend
        try { & npm install; if ($LASTEXITCODE -ne 0) { throw 'npm install falhou.' } }
        finally { Pop-Location }
    }

    # ---------- portas ----------
    # Porta ocupada e erro, nao aviso: o Vite cairia para 5174 e o proxy /api
    # continuaria batendo em outra instancia, o que confunde muito na hora de debugar.
    foreach ($p in @($BackendPort, $FrontendPort)) {
        $owners = Get-PortOwners $p
        if ($owners.Count -eq 0) { continue }

        $desc = ($owners | ForEach-Object {
            $proc = Get-Process -Id $_ -ErrorAction SilentlyContinue
            "PID $_ ($($proc.ProcessName))"
        }) -join ', '

        if ($KillStale) {
            Write-Warn "Porta $p ocupada por $desc. Encerrando (-KillStale)..."
            foreach ($owner in $owners) { & taskkill /PID $owner /T /F 2>$null | Out-Null }
            Start-Sleep -Milliseconds 800
            if ((Get-PortOwners $p).Count -gt 0) { throw "Porta $p continua ocupada depois do kill." }
        }
        else {
            throw "Porta $p ja esta em uso por $desc. Encerre o processo ou rode: .\dev.ps1 -KillStale"
        }
    }

    # ---------- sobe os dois ----------
    # -NoNewWindow: log dos dois no mesmo console e Ctrl+C propaga para os filhos.
    Write-Step "Backend  -> http://localhost:$BackendPort  (docs em /docs)"
    $procs += Start-Process -FilePath $venvPy `
        -ArgumentList @('-m', 'uvicorn', 'app.main:app', '--reload', '--port', "$BackendPort") `
        -WorkingDirectory $backend -NoNewWindow -PassThru

    Write-Step "Frontend -> http://localhost:$FrontendPort"
    # --strictPort: falha em vez de cair para 5174 sem avisar.
    $viteArgs = @('run', 'dev', '--', '--port', "$FrontendPort", '--strictPort')
    if ($Lan) { $viteArgs += @('--host', '0.0.0.0') }
    $procs += Start-Process -FilePath 'npm.cmd' `
        -ArgumentList $viteArgs `
        -WorkingDirectory $frontend -NoNewWindow -PassThru

    if ($Lan) {
        # IPv4 das placas fisicas. Adaptador virtual (WSL/Hyper-V/VPN) tem IP que
        # so existe dentro desta maquina — mostrar so confundiria na hora de
        # passar o endereco.
        $ips = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object {
                $_.IPAddress -ne '127.0.0.1' -and
                $_.InterfaceAlias -notmatch 'vEthernet|WSL|Loopback|VirtualBox|VMware'
            } |
            Select-Object InterfaceAlias, IPAddress)

        $regra = Get-NetFirewallRule -DisplayName "BlackWall dev $FrontendPort" -ErrorAction SilentlyContinue

        Write-Host ''
        Write-Warn "Modo LAN: o site NAO tem login. Quem alcancar a porta ve os dados das 4 bases."
        Write-Host '    Passe o endereco da rede em que o colega esta:'
        foreach ($ip in $ips) {
            Write-Host ("    http://{0}:{1}   ({2})" -f $ip.IPAddress, $FrontendPort, $ip.InterfaceAlias) -ForegroundColor Green
        }
        if (-not $regra) {
            Write-Warn "O firewall do Windows ainda bloqueia a porta $FrontendPort. Num PowerShell ADMIN:"
            Write-Host "    New-NetFirewallRule -DisplayName 'BlackWall dev $FrontendPort' -Direction Inbound -Protocol TCP -LocalPort $FrontendPort -Action Allow -Profile Private" -ForegroundColor Yellow
            Write-Warn "Para fechar depois: Remove-NetFirewallRule -DisplayName 'BlackWall dev $FrontendPort'"
        }
    }

    # ---------- espera o front responder e abre o browser ----------
    if (-not $NoBrowser) {
        $url = "http://localhost:$FrontendPort/"
        for ($i = 0; $i -lt 40; $i++) {
            Start-Sleep -Milliseconds 500
            try {
                Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 2 | Out-Null
                Start-Process $url
                break
            } catch { }
        }
    }

    Write-Host ''
    Write-Host 'Rodando. Ctrl+C encerra backend + frontend.' -ForegroundColor Green
    Write-Host ''

    # Fica vivo enquanto os dois processos viverem; se um morrer, derruba o outro.
    while ($true) {
        Start-Sleep -Seconds 1
        foreach ($p in $procs) {
            if ($p.HasExited) {
                Write-Warn "Processo PID $($p.Id) saiu (exit $($p.ExitCode)). Encerrando o restante."
                return
            }
        }
    }
}
finally {
    Stop-All
}
