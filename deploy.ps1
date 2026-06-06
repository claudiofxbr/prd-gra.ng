#!/usr/bin/env pwsh
# deploy.ps1 - Deploy interativo do PRD-GRA.NG para VPS Hostinger
#
# Uso:
#   .\deploy.ps1               deploy completo com coleta interativa
#   .\deploy.ps1 -SkipPush     pula git push, so monitora CI/CD e valida VPS
#   .\deploy.ps1 -VpsOnly      so valida a VPS (sem push nem CI/CD)
#   .\deploy.ps1 -Bootstrap    configura a VPS do zero (1a vez, como root)

param(
    [switch]$SkipPush,
    [switch]$VpsOnly,
    [switch]$Bootstrap,
    [string]$ConfigFile = ".deploy-config.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# =============================================================================
# CORES
# =============================================================================
$C_RED    = "`e[31m"
$C_GREEN  = "`e[32m"
$C_YELLOW = "`e[33m"
$C_CYAN   = "`e[36m"
$C_WHITE  = "`e[37m"
$C_BOLD   = "`e[1m"
$C_DIM    = "`e[2m"
$C_RESET  = "`e[0m"

function Write-Step  { param([int]$N, [int]$T, [string]$Msg)
    Write-Host "`n${C_BOLD}${C_CYAN}[$N/$T] $Msg${C_RESET}"
    Write-Host "  ${C_DIM}$('-' * 55)${C_RESET}"
}
function Write-Ok    { param([string]$Msg) Write-Host "  ${C_GREEN}[OK] $Msg${C_RESET}" }
function Write-Fail  { param([string]$Msg) Write-Host "  ${C_RED}[ERRO] $Msg${C_RESET}" }
function Write-Info  { param([string]$Msg) Write-Host "  ${C_YELLOW}[->] $Msg${C_RESET}" }
function Write-Title { param([string]$Msg) Write-Host "`n  ${C_BOLD}${C_WHITE}$Msg${C_RESET}" }

function Assert-Tool {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Write-Fail "'$Name' nao encontrado no PATH. Instale e tente novamente."
        exit 1
    }
}

# =============================================================================
# LEITURA INTERATIVA
# =============================================================================

function Read-Input {
    param([string]$Label, [string]$Default = "", [switch]$Secret)

    if ($Default) {
        Write-Host "  ${C_CYAN}$Label${C_RESET} ${C_DIM}[Enter = $Default]${C_RESET}: " -NoNewline
    } else {
        Write-Host "  ${C_CYAN}$Label${C_RESET}: " -NoNewline
    }

    while ($true) {
        if ($Secret) {
            $ss  = Read-Host -AsSecureString
            $val = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                       [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ss))
        } else {
            $val = Read-Host
        }

        if (-not $val -and $Default) { return $Default }
        if ($val)                    { return $val }

        Write-Host "  ${C_RED}Campo obrigatorio. Tente novamente.${C_RESET}"
        Write-Host "  ${C_CYAN}$Label${C_RESET}: " -NoNewline
    }
}

function Read-YesNo {
    param([string]$Label, [string]$Default = "s")
    $hint = if ($Default -eq "s") { "S/n" } else { "s/N" }
    Write-Host "  ${C_CYAN}$Label${C_RESET} ${C_DIM}[$hint]${C_RESET}: " -NoNewline
    $val = Read-Host
    if (-not $val) { return ($Default -eq "s") }
    return ($val -match "^[sS]$")
}

# =============================================================================
# PERSISTENCIA DE CONFIGURACAO (sem segredos)
# =============================================================================

function Save-Config {
    param([hashtable]$Cfg)
    @{
        VpsHost      = $Cfg.VpsHost
        VpsUser      = $Cfg.VpsUser
        SshKeyPath   = $Cfg.SshKeyPath
        GhRepo       = $Cfg.GhRepo
        GhBranch     = $Cfg.GhBranch
        Domain       = $Cfg.Domain
        AppDir       = $Cfg.AppDir
        CiTimeoutMin = $Cfg.CiTimeoutMin
        SmokeRetries = $Cfg.SmokeRetries
    } | ConvertTo-Json | Set-Content $ConfigFile -Encoding UTF8
    Write-Info "Configuracao salva em $ConfigFile (segredos nao sao persistidos)"
}

function Get-SavedConfig {
    if (-not (Test-Path $ConfigFile)) { return $null }
    try {
        $j = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        return @{
            VpsHost      = $j.VpsHost
            VpsUser      = $j.VpsUser
            SshKeyPath   = $j.SshKeyPath
            GhRepo       = $j.GhRepo
            GhBranch     = $j.GhBranch
            Domain       = $j.Domain
            AppDir       = $j.AppDir
            CiTimeoutMin = [int]$j.CiTimeoutMin
            SmokeRetries = [int]$j.SmokeRetries
        }
    } catch { return $null }
}

# =============================================================================
# COLETA DE SEGREDOS
# =============================================================================

function Request-Secrets {
    param([hashtable]$Cfg)

    Write-Host ""
    Write-Title "--- SEGREDOS DA APLICACAO ---"
    Write-Host "    ${C_DIM}Estes valores NAO sao salvos em disco.${C_RESET}"
    Write-Host ""

    $hasGh = $null -ne (Get-Command gh -ErrorAction SilentlyContinue)
    if ($hasGh) {
        Write-Ok "gh CLI detectado - secrets serao configurados automaticamente."
    } else {
        Write-Info "gh CLI nao encontrado - copie os valores manualmente no GitHub."
        Write-Info "Instale com: winget install GitHub.cli"
    }

    Write-Host ""
    Write-Host "    ${C_DIM}DATABASE_URL: string de conexao do Neon PostgreSQL${C_RESET}"
    Write-Host "    ${C_DIM}Formato: postgresql://user:senha@ep-xxx.neon.tech/db?sslmode=verify-full${C_RESET}"
    $dbUrl = Read-Input "DATABASE_URL"

    Write-Host ""
    Write-Host "    ${C_DIM}JWT_SECRET: chave para assinar tokens JWT${C_RESET}"
    Write-Host "    ${C_DIM}Deixe em branco para GERAR automaticamente (recomendado)${C_RESET}"
    Write-Host "  ${C_CYAN}JWT_SECRET${C_RESET} ${C_DIM}[Enter = gerar automaticamente]${C_RESET}: " -NoNewline
    $jwtInput = Read-Host
    if (-not $jwtInput) {
        $bytes = New-Object byte[] 48
        $rng   = [Security.Cryptography.RandomNumberGenerator]::Create()
        $rng.GetBytes($bytes)
        $rng.Dispose()
        $jwtSecret = [Convert]::ToBase64String($bytes)
        Write-Ok "JWT_SECRET gerado automaticamente."
    } else {
        $jwtSecret = $jwtInput
    }

    # API URL: caminho relativo /api funciona quando nginx serve tudo no mesmo dominio
    $apiDefault  = "/api"
    $corsDefault = "https://" + $Cfg.Domain
    $apiUrl      = Read-Input "NEXT_PUBLIC_API_URL"  $apiDefault
    $corsUrl     = Read-Input "CORS_ALLOWED_ORIGINS" $corsDefault

    Write-Host ""
    Write-Host "    ${C_DIM}TRUSTED_PROXY_IP: IP interno do container nginx no Docker${C_RESET}"
    Write-Host "    ${C_DIM}Na 1a instalacao use 172.18.0.2 (ajuste apos o 1o deploy)${C_RESET}"
    $proxyIp = Read-Input "TRUSTED_PROXY_IP" "172.18.0.2"

    $Cfg.DatabaseUrl        = $dbUrl
    $Cfg.JwtSecret          = $jwtSecret
    $Cfg.NextPublicApiUrl   = $apiUrl
    $Cfg.CorsAllowedOrigins = $corsUrl
    $Cfg.TrustedProxyIp     = $proxyIp

    if ($hasGh) {
        Write-Host ""
        if (Read-YesNo "Configurar os Secrets no GitHub agora via gh CLI?") {
            Push-GithubSecrets $Cfg
        }
    } else {
        Show-SecretsManual $Cfg
    }

    return $Cfg
}

# =============================================================================
# GITHUB SECRETS VIA gh CLI
# =============================================================================

function Push-GithubSecrets {
    param([hashtable]$Cfg)

    Write-Host ""
    Write-Info "Configurando secrets em $($Cfg.GhRepo)..."

    gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Info "Autenticando no GitHub via browser..."
        gh auth login --web
    }

    $sshKeyContent = Get-Content $Cfg.SshKeyPath -Raw

    $pairs = @(
        @{ Key = "VPS_HOST";             Val = $Cfg.VpsHost }
        @{ Key = "VPS_USER";             Val = $Cfg.VpsUser }
        @{ Key = "VPS_SSH_KEY";          Val = $sshKeyContent }
        @{ Key = "DATABASE_URL";         Val = $Cfg.DatabaseUrl }
        @{ Key = "JWT_SECRET";           Val = $Cfg.JwtSecret }
        @{ Key = "NEXT_PUBLIC_API_URL";  Val = $Cfg.NextPublicApiUrl }
        @{ Key = "CORS_ALLOWED_ORIGINS"; Val = $Cfg.CorsAllowedOrigins }
        @{ Key = "DOMAIN";               Val = $Cfg.Domain }
        @{ Key = "TRUSTED_PROXY_IP";     Val = $Cfg.TrustedProxyIp }
    )

    $ok = 0
    foreach ($p in $pairs) {
        $p.Val | gh secret set $p.Key --repo $Cfg.GhRepo 2>$null
        if ($LASTEXITCODE -eq 0) { Write-Ok "Secret: $($p.Key)"; $ok++ }
        else                     { Write-Fail "Falha: $($p.Key)" }
    }
    Write-Host ""
    Write-Ok "$ok/$($pairs.Count) secrets configurados."
}

function Show-SecretsManual {
    param([hashtable]$Cfg)
    Write-Host ""
    Write-Host "  ${C_BOLD}${C_YELLOW}Configure manualmente em:${C_RESET}"
    Write-Host "  ${C_CYAN}https://github.com/$($Cfg.GhRepo)/settings/secrets/actions${C_RESET}"
    Write-Host ""
    Write-Host "  Secret                    Valor"
    Write-Host "  $('-'*60)"
    Write-Host "  VPS_HOST                  $($Cfg.VpsHost)"
    Write-Host "  VPS_USER                  $($Cfg.VpsUser)"
    Write-Host "  VPS_SSH_KEY               (conteudo de $($Cfg.SshKeyPath))"
    Write-Host "  DATABASE_URL              (valor que voce informou)"
    Write-Host "  JWT_SECRET                (valor gerado/informado)"
    Write-Host "  NEXT_PUBLIC_API_URL       $($Cfg.NextPublicApiUrl)"
    Write-Host "  CORS_ALLOWED_ORIGINS      $($Cfg.CorsAllowedOrigins)"
    Write-Host "  DOMAIN                    $($Cfg.Domain)"
    Write-Host "  TRUSTED_PROXY_IP          $($Cfg.TrustedProxyIp)"
    Write-Host ""
    Write-Info "Apos configurar os secrets, pressione Enter para continuar."
    $null = Read-Host
}

# =============================================================================
# WIZARD DE CONFIGURACAO
# =============================================================================

function Invoke-Setup {
    Write-Host ""
    Write-Host "  ${C_BOLD}${C_YELLOW}+--------------------------------------------------+${C_RESET}"
    Write-Host "  ${C_BOLD}${C_YELLOW}|       CONFIGURACAO INTERATIVA DO DEPLOY          |${C_RESET}"
    Write-Host "  ${C_BOLD}${C_YELLOW}+--------------------------------------------------+${C_RESET}"

    $saved = Get-SavedConfig
    if ($saved) {
        Write-Host ""
        $label = "Configuracao anterior encontrada em " + $ConfigFile
        Write-Info $label
        Write-Host "    VPS:     $($saved.VpsHost)  /  usuario: $($saved.VpsUser)"
        Write-Host "    Repo:    $($saved.GhRepo) [$($saved.GhBranch)]"
        Write-Host "    Dominio: $($saved.Domain)"
        Write-Host ""
        if (Read-YesNo "Usar esta configuracao salva?") {
            Write-Ok "Configuracao carregada."
            $saved = Request-Secrets $saved
            return $saved
        }
    }

    # --- VPS ---
    Write-Host ""
    Write-Title "--- VPS ---"
    Write-Host "    ${C_DIM}Encontre o IP no painel Hostinger -> VPS -> detalhes${C_RESET}"

    $vpsHost = ""
    while ($true) {
        $vpsHost = Read-Input "IP publico da VPS"
        if ($vpsHost -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$") { break }
        Write-Fail "Formato invalido. Use um IPv4 como 185.123.45.67"
    }

    $vpsUser = Read-Input "Usuario SSH da VPS" "deploy"

    Write-Host ""
    Write-Host "    ${C_DIM}Chave SSH: caminho para o arquivo de chave PRIVADA no seu PC${C_RESET}"

    $defaultKey = ""
    if     (Test-Path "$HOME\.ssh\id_ed25519") { $defaultKey = "$HOME\.ssh\id_ed25519" }
    elseif (Test-Path "$HOME\.ssh\id_rsa")     { $defaultKey = "$HOME\.ssh\id_rsa"     }
    else                                       { $defaultKey = "$HOME\.ssh\id_rsa"     }

    while ($true) {
        $sshKey = Read-Input "Caminho da chave SSH privada" $defaultKey
        if (Test-Path $sshKey) { Write-Ok "Chave encontrada: $sshKey"; break }
        Write-Fail "Arquivo nao encontrado: $sshKey"
    }

    # --- GitHub ---
    Write-Host ""
    Write-Title "--- GITHUB ---"
    Write-Host "    ${C_DIM}Formato: usuario/repositorio  (ex: claudiofxbr/prd-gra.ng)${C_RESET}"
    $ghRepo   = Read-Input "Repositorio GitHub" "claudiofxbr/prd-gra.ng"
    $ghBranch = Read-Input "Branch de deploy"   "main"

    # --- Dominio ---
    Write-Host ""
    Write-Title "--- DOMINIO ---"
    Write-Host "    ${C_DIM}O DNS deve ter registro A apontando para o IP da VPS${C_RESET}"
    $domain = Read-Input "Dominio da aplicacao" "xavierbr-vps.tech"
    $appDir = Read-Input "Diretorio na VPS"     "/opt/prd-gra"

    $cfg = @{
        VpsHost      = $vpsHost
        VpsUser      = $vpsUser
        SshKeyPath   = $sshKey
        GhRepo       = $ghRepo
        GhBranch     = $ghBranch
        Domain       = $domain
        AppDir       = $appDir
        CiTimeoutMin = 15
        SmokeRetries = 20
    }

    $cfg = Request-Secrets $cfg

    Write-Host ""
    if (Read-YesNo "Salvar configuracao para proximos deploys?") {
        Save-Config $cfg
    }

    return $cfg
}

# =============================================================================
# SSH HELPER
# =============================================================================

function Invoke-Ssh {
    param([string]$Cmd, [switch]$PassThru)
    $sshArgs = @(
        "-i",  $script:Config.SshKeyPath,
        "-o",  "StrictHostKeyChecking=no",
        "-o",  "ConnectTimeout=10",
        "$($script:Config.VpsUser)@$($script:Config.VpsHost)",
        $Cmd
    )
    if ($PassThru) { return (ssh @sshArgs 2>&1) }
    ssh @sshArgs
    return $LASTEXITCODE
}

function Test-VpsReachable {
    $r = ssh `
        -i $script:Config.SshKeyPath `
        -o StrictHostKeyChecking=no `
        -o ConnectTimeout=10 `
        -o BatchMode=yes `
        "$($script:Config.VpsUser)@$($script:Config.VpsHost)" `
        "echo PONG" 2>&1
    return ($r -match "PONG")
}

# =============================================================================
# ETAPA 0 - Pre-verificacoes
# =============================================================================

function Step-PreChecks {
    Write-Step 0 6 "Pre-verificacoes"

    foreach ($tool in @("git", "ssh")) {
        Assert-Tool $tool
        Write-Ok "$tool disponivel"
    }

    if (Get-Command gh -ErrorAction SilentlyContinue) {
        Write-Ok "gh CLI disponivel - monitoramento de Actions habilitado"
    } else {
        Write-Info "gh CLI nao encontrado - aguardara tempo fixo pelo CI/CD"
    }

    $gitRoot = git rev-parse --show-toplevel 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Diretorio atual nao e um repositorio git."
        exit 1
    }
    Write-Ok "Repositorio git: $gitRoot"

    $branch = git branch --show-current
    if ($branch -ne $script:Config.GhBranch) {
        Write-Info "Branch atual: $branch  (configurado: $($script:Config.GhBranch))"
        if (-not (Read-YesNo "Continuar mesmo assim?")) { exit 0 }
    } else {
        Write-Ok "Branch: $branch"
    }

    $mergeFile = Join-Path $gitRoot ".git/MERGE_HEAD"
    if (Test-Path $mergeFile) {
        Write-Fail "Merge em andamento. Resolva antes do deploy."
        exit 1
    }

    Write-Ok "Pre-verificacoes OK"
}

# =============================================================================
# ETAPA 1 - Git push
# =============================================================================

function Step-GitPush {
    Write-Step 1 6 "Enviar codigo para o GitHub"

    $status = git status --porcelain
    if ($status) {
        Write-Info "Arquivos nao commitados:"
        git status --short
        Write-Host ""
        if (Read-YesNo "Commitar tudo agora?") {
            Write-Host "  ${C_CYAN}Mensagem do commit${C_RESET} ${C_DIM}[Enter = mensagem automatica]${C_RESET}: " -NoNewline
            $msg = Read-Host
            if (-not $msg) {
                $ts  = Get-Date -Format "yyyy-MM-dd HH:mm"
                $msg = "chore: deploy $ts"
            }
            git add -A
            git commit -m $msg
            Write-Ok "Commit: $msg"
        } else {
            Write-Info "Faca o commit manualmente e reexecute o script."
            exit 0
        }
    } else {
        Write-Ok "Working tree limpo"
    }

    $branch = $script:Config.GhBranch
    $ahead  = git rev-list "origin/${branch}..HEAD" --count 2>$null
    if ([int]$ahead -gt 0) {
        Write-Info "Enviando $ahead commit(s) para origin/$branch..."
        git push origin $branch
        if ($LASTEXITCODE -ne 0) { Write-Fail "git push falhou."; exit 1 }
        Write-Ok "Push concluido"
    } else {
        Write-Info "Nenhum commit novo - branch em sync com origin"
    }

    $script:CommitSha = git rev-parse HEAD
    Write-Ok "SHA: $($script:CommitSha.Substring(0, 12))"
}

# =============================================================================
# ETAPA 2 - Aguardar CI/CD
# =============================================================================

function Step-WaitCi {
    Write-Step 2 6 "Aguardar pipeline GitHub Actions"

    $hasGh    = $null -ne (Get-Command gh -ErrorAction SilentlyContinue)
    $deadline = (Get-Date).AddMinutes($script:Config.CiTimeoutMin)

    if (-not $hasGh) {
        $mins = $script:Config.CiTimeoutMin
        Write-Info "Aguardando $mins minutos (sem gh CLI)..."
        $end = (Get-Date).AddMinutes($mins)
        while ((Get-Date) -lt $end) {
            $s = [int]($end - (Get-Date)).TotalSeconds
            Write-Host "  Aguardando CI/CD... ${s}s restantes   `r" -NoNewline
            Start-Sleep 15
        }
        Write-Host ""
        Write-Ok "Tempo de espera concluido"
        return
    }

    Write-Info "Aguardando workflow iniciar no GitHub..."
    $run = $null
    for ($i = 0; $i -lt 12; $i++) {
        Start-Sleep 6
        $json = gh run list `
            --repo   $script:Config.GhRepo `
            --branch $script:Config.GhBranch `
            --limit  1 `
            --json   "databaseId,status,conclusion,headSha" 2>$null
        $run = $json | ConvertFrom-Json | Select-Object -First 1
        $prefix = $script:CommitSha.Substring(0, 8)
        if ($run -and $run.headSha -like "${prefix}*") { break }
        $s = [int]($deadline - (Get-Date)).TotalSeconds
        Write-Host "  Esperando workflow... ${s}s   `r" -NoNewline
    }
    Write-Host ""

    if (-not $run) {
        $url = "https://github.com/$($script:Config.GhRepo)/actions"
        Write-Info "Workflow nao localizado - verifique: $url"
        return
    }

    $runId = $run.databaseId
    Write-Info "Run #$runId encontrado"

    while ((Get-Date) -lt $deadline) {
        $view = gh run view $runId `
            --repo $script:Config.GhRepo `
            --json "status,conclusion" | ConvertFrom-Json
        if ($view.status -eq "completed") {
            if ($view.conclusion -eq "success") {
                Write-Ok "Pipeline concluido com sucesso"
                return
            } else {
                Write-Fail "Pipeline falhou (conclusion=$($view.conclusion))"
                Write-Info "Logs: gh run view $runId --repo $($script:Config.GhRepo) --log"
                exit 1
            }
        }
        $s = [int]($deadline - (Get-Date)).TotalSeconds
        Write-Host "  Status: $($view.status) - ${s}s restantes...   `r" -NoNewline
        Start-Sleep 20
    }
    Write-Host ""
    $mins = $script:Config.CiTimeoutMin
    Write-Fail "Timeout ($mins min) - verifique manualmente."
    exit 1
}

# =============================================================================
# ETAPA 3 - Conectar VPS
# =============================================================================

function Step-VpsConnect {
    Write-Step 3 6 "Verificar conectividade com a VPS"

    $target = "$($script:Config.VpsUser)@$($script:Config.VpsHost)"
    Write-Info "Testando SSH: $target ..."

    if (-not (Test-VpsReachable)) {
        Write-Fail "Nao foi possivel conectar via SSH."
        Write-Info "Verifique: IP da VPS, usuario, chave SSH e firewall (porta 22)."
        if (Read-YesNo "Tentar novamente?") {
            if (-not (Test-VpsReachable)) {
                Write-Fail "Segunda tentativa falhou. Abortando."
                exit 1
            }
        } else { exit 1 }
    }
    Write-Ok "SSH conectado: $target"

    $dockerVer = Invoke-Ssh "docker --version 2>&1" -PassThru
    if ($dockerVer -match "Docker version") {
        Write-Ok "Docker: $dockerVer"
    } else {
        Write-Fail "Docker nao encontrado na VPS."
        Write-Info "Execute primeiro: .\deploy.ps1 -Bootstrap"
        exit 1
    }

    $appDir  = $script:Config.AppDir
    $dirTest = Invoke-Ssh "test -d $appDir && echo OK || echo MISSING" -PassThru
    if ($dirTest -match "OK") {
        Write-Ok "Diretorio: $appDir"
    } else {
        Write-Fail "Diretorio $appDir nao existe."
        Write-Info "Execute primeiro: .\deploy.ps1 -Bootstrap"
        exit 1
    }
}

# =============================================================================
# ETAPA 4 - Smoke test
# =============================================================================

function Step-SmokeTest {
    Write-Step 4 6 "Smoke test - saude da aplicacao"

    Write-Info "Aguardando containers estabilizarem (10s)..."
    Start-Sleep 10

    $domain  = $script:Config.Domain
    $retries = $script:Config.SmokeRetries
    $appDir  = $script:Config.AppDir

    # Backend health
    Write-Info "Testando backend..."
    $ok = $false
    for ($i = 1; $i -le $retries; $i++) {
        try {
            $r    = Invoke-WebRequest -Uri "https://$domain/api/actuator/health" `
                        -TimeoutSec 10 -SkipCertificateCheck -ErrorAction Stop
            $body = $r.Content | ConvertFrom-Json
            if ($body.status -eq "UP") {
                Write-Ok "Backend: UP (tentativa $i)"
                $ok = $true
                break
            }
        } catch { }
        Write-Host "  Tentativa $i/${retries} - aguardando 3s...   `r" -NoNewline
        Start-Sleep 3
    }
    Write-Host ""
    if (-not $ok) {
        Write-Fail "Backend nao respondeu."
        Write-Info "Logs do backend:"
        Invoke-Ssh "docker compose -f $appDir/docker-compose.yml logs --tail=30 backend"
        exit 1
    }

    # Frontend — acessivel sob o sub-path /prd-gra.ng/
    Write-Info "Testando frontend em https://$domain/prd-gra.ng/ ..."
    try {
        $r = Invoke-WebRequest -Uri "https://$domain/prd-gra.ng/" `
                 -TimeoutSec 15 -SkipCertificateCheck -ErrorAction Stop
        if ($r.Content -match "<html") {
            Write-Ok "Frontend: OK (HTTP $($r.StatusCode)) em /prd-gra.ng/"
        } else {
            Write-Fail "Frontend retornou resposta inesperada."
        }
    } catch {
        Write-Fail "Frontend inacessivel em /prd-gra.ng/: $_"
        exit 1
    }

    # Redirect HTTP -> HTTPS
    Write-Info "Testando redirect HTTP -> HTTPS..."
    try {
        Invoke-WebRequest -Uri "http://$domain" `
            -TimeoutSec 10 -MaximumRedirection 0 `
            -SkipCertificateCheck -ErrorAction Stop | Out-Null
    } catch {
        $code = $_.Exception.Response.StatusCode.value__
        if ($code -eq 301) { Write-Ok "Redirect HTTP->HTTPS: 301 OK" }
        else               { Write-Info "Redirect retornou HTTP $code (esperado 301)" }
    }

    # TLS
    Write-Info "Verificando certificado TLS..."
    $tlsCmd = "echo Q | openssl s_client -servername $domain -connect ${domain}:443 2>&1 | grep 'Verify return'"
    $tls    = Invoke-Ssh $tlsCmd -PassThru
    if ($tls -match "Verify return code: 0") { Write-Ok "Certificado TLS valido" }
    else                                     { Write-Info "TLS: $tls" }

    # Fix #4/#11: validar headers de seguranca do frontend
    # X-Frame-Options deve ser DENY (consistente com frame-ancestors 'none' no CSP).
    # CSP nao deve conter 'unsafe-inline' em script-src em producao.
    Write-Info "Verificando headers de seguranca do frontend..."
    try {
        $hr = Invoke-WebRequest -Uri "https://$domain" `
                  -TimeoutSec 15 -SkipCertificateCheck -ErrorAction Stop -Method HEAD
        $xfo = $hr.Headers["X-Frame-Options"]
        $csp = $hr.Headers["Content-Security-Policy"]

        if ($xfo -eq "DENY") {
            Write-Ok "X-Frame-Options: DENY [OK]"
        } else {
            Write-Fail "X-Frame-Options: '$xfo' (esperado DENY)"
        }

        # Cast para string: PowerShell 7 pode retornar array de headers
        $cspStr = if ($csp -is [array]) { $csp -join ' ' } else { [string]$csp }
        if ($cspStr -and $cspStr -notmatch "script-src[^;]*'unsafe-inline'") {
            Write-Ok "CSP script-src sem 'unsafe-inline' em producao [OK]"
        } elseif (-not $cspStr) {
            Write-Info "CSP: header nao retornado (verifique next.config.mjs)"
        } else {
            Write-Fail "CSP contem 'unsafe-inline' em script-src - remova para producao"
        }
    } catch {
        Write-Info "Nao foi possivel verificar headers de seguranca: $_"
    }
}

# =============================================================================
# ETAPA 5 - Validacoes na VPS
# =============================================================================

function Step-VpsValidation {
    Write-Step 5 6 "Validacao de saude na VPS"

    $appDir = $script:Config.AppDir
    $dc     = "docker compose -f $appDir/docker-compose.yml"

    Write-Info "Status dos containers:"
    Invoke-Ssh "$dc ps"

    # Verificar containers nao-running usando formato tabular (compativel com todas as versoes do Compose V2)
    # Filtra por status diferente de "running" usando awk - sem dependencia de Python inline
    $check = Invoke-Ssh "$dc ps --format 'table {{.Name}}\t{{.State}}' 2>/dev/null | awk 'NR>1 && \$2 != \"running\" {print \$1}'" -PassThru
    $badContainers = ($check | Where-Object { $_.Trim() -ne "" }) -join ", "

    if (-not $badContainers) {
        Write-Ok "Todos os containers estao running"
    } else {
        Write-Fail "Containers com problema: $badContainers"
        Write-Info "Logs:"
        Invoke-Ssh "$dc logs --tail=50"
        exit 1
    }

    Write-Info "Uso de recursos:"
    Invoke-Ssh "docker stats --no-stream"

    $disk = Invoke-Ssh "df -h / | tail -1 | awk '{print \$5}'" -PassThru
    $pct  = [int]($disk -replace '[^0-9]', '')
    if ($pct -gt 85) { Write-Info "Disco com ${disk} usado - monitore o espaco" }
    else             { Write-Ok   "Disco: ${disk} usado" }

    # Obter imagem ativa do backend via docker compose ps (sem template Go - evita escaping complexo)
    $img = Invoke-Ssh "$dc ps --format 'table {{.Image}}' backend 2>/dev/null | tail -1" -PassThru
    if ($img -and $img.Trim() -ne "IMAGE") { Write-Ok "Imagem ativa: $($img.Trim())" }
}

# =============================================================================
# ETAPA 6 - Relatorio
# =============================================================================

function Step-Report {
    Write-Step 6 6 "Relatorio do deploy"

    $ts     = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $domain = $script:Config.Domain
    $vps    = "$($script:Config.VpsUser)@$($script:Config.VpsHost)"
    $appDir = $script:Config.AppDir
    $repo   = $script:Config.GhRepo

    Write-Host ""
    Write-Host "  ${C_BOLD}${C_GREEN}+--------------------------------------------------+${C_RESET}"
    Write-Host "  ${C_BOLD}${C_GREEN}|         DEPLOY CONCLUIDO COM SUCESSO             |${C_RESET}"
    Write-Host "  ${C_BOLD}${C_GREEN}+--------------------------------------------------+${C_RESET}"
    Write-Host ""
    Write-Host "  Aplicacao  : PRD-GRA.NG"
    Write-Host "  Dominio    : ${C_CYAN}https://$domain/prd-gra.ng/${C_RESET}"
    Write-Host "  Timestamp  : $ts"
    if ($script:CommitSha) {
        $sha = $script:CommitSha.Substring(0, 12)
        Write-Host "  Commit     : $sha"
        Write-Host "  GitHub     : ${C_DIM}https://github.com/$repo/commit/$($script:CommitSha)${C_RESET}"
    }
    Write-Host ""
    Write-Host "  ${C_BOLD}Endpoints:${C_RESET}"
    Write-Host "    Frontend -> https://$domain/prd-gra.ng/"
    Write-Host "    API      -> https://$domain/api"
    Write-Host "    Health   -> https://$domain/api/actuator/health"
    Write-Host ""
    Write-Host "  ${C_BOLD}Comandos uteis na VPS:${C_RESET}"
    Write-Host ""
    Write-Host "    # Logs em tempo real"
    Write-Host "    ssh $vps `"docker compose -f $appDir/docker-compose.yml logs -f --tail=50`""
    Write-Host ""
    Write-Host "    # Descobrir IP do nginx na frontend-net (para TRUSTED_PROXY_IP)"
    Write-Host "    # Fix #12: nginx esta apenas na frontend-net (removido da backend-net)"
    Write-Host "    ssh $vps `"docker inspect `$(docker compose -f $appDir/docker-compose.yml ps -q nginx) --format '{{json .NetworkSettings.Networks}}' | python3 -m json.tool`""
    Write-Host ""
    Write-Host "    # Reiniciar servicos"
    Write-Host "    ssh $vps `"docker compose -f $appDir/docker-compose.yml restart`""
    Write-Host ""

    if ($script:Config.TrustedProxyIp -eq "172.18.0.2") {
        Write-Host "  ${C_BOLD}${C_YELLOW}PROXIMO PASSO - Corrigir TRUSTED_PROXY_IP:${C_RESET}"
        Write-Host "  Execute o comando de 'Descobrir IP do nginx' acima, copie o IP"
        Write-Host "  e reexecute: .\deploy.ps1  (informe o novo IP quando perguntado)"
        Write-Host ""
    }
}

# =============================================================================
# BOOTSTRAP
# =============================================================================

function Step-Bootstrap {
    Write-Host ""
    Write-Host "  ${C_BOLD}${C_CYAN}+--------------------------------------------------+${C_RESET}"
    Write-Host "  ${C_BOLD}${C_CYAN}|              BOOTSTRAP DA VPS                    |${C_RESET}"
    Write-Host "  ${C_BOLD}${C_CYAN}+--------------------------------------------------+${C_RESET}"
    Write-Host ""
    Write-Info "Configura a VPS do zero: Docker, firewall, usuario deploy, SSL."
    Write-Info "Deve ser executado com VpsUser = 'root'."
    Write-Host ""

    $bsPath = Join-Path $PSScriptRoot "vps-bootstrap.sh"
    if (-not (Test-Path $bsPath)) {
        Write-Fail "vps-bootstrap.sh nao encontrado em: $PSScriptRoot"
        exit 1
    }

    Write-Info "Enviando e executando vps-bootstrap.sh na VPS..."
    $tmp     = "/tmp/bootstrap-$([System.IO.Path]::GetRandomFileName().Replace('.',''))"
    $sshBase = @(
        "-i", $script:Config.SshKeyPath,
        "-o", "StrictHostKeyChecking=no",
        "$($script:Config.VpsUser)@$($script:Config.VpsHost)"
    )

    # 1. Copiar o script via scp (sem ocupar stdin)
    $scpArgs = @(
        "-i", $script:Config.SshKeyPath,
        "-o", "StrictHostKeyChecking=no",
        $bsPath,
        "$($script:Config.VpsUser)@$($script:Config.VpsHost):$tmp"
    )
    scp @scpArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "scp falhou ao copiar vps-bootstrap.sh"
        exit 1
    }

    # 2. Executar com -t (pseudo-TTY) para que o bash remoto leia prompts do terminal do usuario
    $sshCmd = 'chmod +x TMP_PATH && bash TMP_PATH; rc=$?; rm -f TMP_PATH; exit $rc' -replace 'TMP_PATH', $tmp
    ssh -t @sshBase $sshCmd
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Bootstrap falhou (exit $LASTEXITCODE)"
        exit 1
    }
    Write-Ok "Bootstrap concluido com sucesso."
}

# =============================================================================
# PONTO DE ENTRADA
# =============================================================================

$script:CommitSha = ""

Write-Host ""
Write-Host "  ${C_BOLD}${C_CYAN}+---------------------------------------------------+${C_RESET}"
Write-Host "  ${C_BOLD}${C_CYAN}|      PRD-GRA.NG - Deploy para Hostinger VPS       |${C_RESET}"
Write-Host "  ${C_BOLD}${C_CYAN}+---------------------------------------------------+${C_RESET}"
Write-Host ""
Write-Host "  ${C_DIM}Modos disponiveis:${C_RESET}"
Write-Host "    ${C_CYAN}.\deploy.ps1${C_RESET}             Deploy completo"
Write-Host "    ${C_CYAN}.\deploy.ps1 -Bootstrap${C_RESET}  Configura a VPS do zero (1a vez)"
Write-Host "    ${C_CYAN}.\deploy.ps1 -VpsOnly${C_RESET}    So valida a VPS"
Write-Host "    ${C_CYAN}.\deploy.ps1 -SkipPush${C_RESET}   Pula git push"
Write-Host ""

# Wizard interativo
$script:Config = Invoke-Setup

# Confirmacao antes de executar
Write-Host ""
Write-Host "  ${C_BOLD}Configuracao confirmada:${C_RESET}"
Write-Host "  $('-'*45)"
Write-Host "  VPS       : $($script:Config.VpsUser)@$($script:Config.VpsHost)"
Write-Host "  Chave SSH : $($script:Config.SshKeyPath)"
Write-Host "  Repo      : $($script:Config.GhRepo) [$($script:Config.GhBranch)]"
Write-Host "  Dominio   : https://$($script:Config.Domain)"
Write-Host "  App Dir   : $($script:Config.AppDir)"
Write-Host ""

if (-not (Read-YesNo "Confirmar e iniciar deploy?")) {
    Write-Info "Deploy cancelado pelo usuario."
    exit 0
}

# Execucao
if ($Bootstrap) {
    Step-Bootstrap
    exit 0
}

if ($VpsOnly) {
    Step-VpsConnect
    Step-SmokeTest
    Step-VpsValidation
    Step-Report
    exit 0
}

if (-not $SkipPush) {
    Step-PreChecks
    Step-GitPush
    Step-WaitCi
}

Step-VpsConnect
Step-SmokeTest
Step-VpsValidation
Step-Report
