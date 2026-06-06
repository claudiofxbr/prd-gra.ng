<#
.SYNOPSIS
    PRD-GRA.NG - Script de Ativacao Completo
.DESCRIPTION
    Ativa o aplicativo PRD-GRA.NG em modo Docker ou local.
    Uso:
        .\start-prdgra.ps1               # modo automatico
        .\start-prdgra.ps1 -Modo docker  # forcar Docker
        .\start-prdgra.ps1 -Modo local   # forcar local (sem Docker)
        .\start-prdgra.ps1 -Modo parar   # parar todos os servicos
        .\start-prdgra.ps1 -Modo status  # ver status dos servicos
#>
param(
    [ValidateSet("docker","local","parar","status","auto")]
    [string]$Modo = "auto"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# =========================================================
# Funcoes de output
# =========================================================
function Write-Ok    { param($m) Write-Host "  [OK]   $m" -ForegroundColor Green  }
function Write-Info  { param($m) Write-Host "  [...] $m"  -ForegroundColor Cyan   }
function Write-Warn  { param($m) Write-Host "  [!]   $m"  -ForegroundColor Yellow }
function Write-Fail  { param($m) Write-Host "  [ERR] $m"  -ForegroundColor Red    }
function Write-Title { param($m) Write-Host "" ; Write-Host "==> $m" -ForegroundColor Magenta }

$ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path

# =========================================================
# Banner
# =========================================================
Clear-Host
Write-Host ""
Write-Host "  +==========================================+" -ForegroundColor Blue
Write-Host "  |        PRD-GRA.NG  Launcher             |" -ForegroundColor Blue
Write-Host "  |   Gerador de Documentos de Requisitos   |" -ForegroundColor Blue
Write-Host "  +==========================================+" -ForegroundColor Blue
Write-Host ""

# =========================================================
# Test-HttpPort: retorna true se URL responde com 2xx/3xx/4xx
# =========================================================
function Test-HttpPort {
    param([string]$Url, [int]$TimeoutSec = 5)
    try {
        $r = Invoke-WebRequest $Url -TimeoutSec $TimeoutSec -UseBasicParsing -ErrorAction Stop
        return ($r.StatusCode -lt 500)
    } catch {
        $code = $null
        try { $code = $_.Exception.Response.StatusCode.value__ -as [int] } catch {}
        return ($null -ne $code -and $code -gt 0 -and $code -lt 500)
    }
}

# =========================================================
# Wait-ForService: aguarda ate o servico responder
# =========================================================
function Wait-ForService {
    param([string]$Name, [string]$Url, [int]$MaxWaitSec = 120)
    Write-Info "Aguardando $Name ficar disponivel (max ${MaxWaitSec}s)..."
    $elapsed = 0
    while ($elapsed -lt $MaxWaitSec) {
        if (Test-HttpPort -Url $Url) {
            Write-Ok "$Name respondendo em $Url"
            return $true
        }
        Start-Sleep -Seconds 3
        $elapsed += 3
        Write-Host "    ... ${elapsed}s" -ForegroundColor DarkGray
    }
    Write-Fail "$Name nao respondeu em ${MaxWaitSec}s"
    return $false
}

# =========================================================
# Import-DotEnv: carrega variaveis do arquivo .env
# =========================================================
function Import-DotEnv {
    $envFile = Join-Path $ROOT ".env"
    if (-not (Test-Path $envFile)) {
        Write-Fail "Arquivo .env nao encontrado em: $envFile"
        Write-Warn "Copie .env.example para .env e preencha as variaveis."
        exit 1
    }
    Write-Info "Carregando variaveis do .env..."
    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#")) {
            $idx = $line.IndexOf("=")
            if ($idx -gt 0) {
                $key   = $line.Substring(0, $idx).Trim()
                $value = $line.Substring($idx + 1).Trim()
                [System.Environment]::SetEnvironmentVariable($key, $value, "Process")
            }
        }
    }
    Write-Ok ".env carregado com sucesso"
}

# =========================================================
# Assert-EnvVars: verifica variaveis obrigatorias
# =========================================================
function Assert-EnvVars {
    Write-Title "Verificando variaveis de ambiente"
    # DOMAIN adicionado - necessario para nginx em producao e .env.example
    $required = @("DATABASE_URL","JWT_SECRET","NEXT_PUBLIC_API_URL","CORS_ALLOWED_ORIGINS","DOMAIN")
    $allOk = $true
    foreach ($v in $required) {
        $val = [System.Environment]::GetEnvironmentVariable($v, "Process")
        if ([string]::IsNullOrWhiteSpace($val)) {
            Write-Fail "Variavel obrigatoria ausente: $v"
            $allOk = $false
        } else {
            $display = if ($v -eq "JWT_SECRET") { "****" } else { $val }
            Write-Ok "${v} = $display"
        }
    }
    if (-not $allOk) { exit 1 }
}

# =========================================================
# Show-Status: mostra o estado atual dos servicos
# =========================================================
function Show-Status {
    Write-Title "Status dos Servicos"

    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    $dockerRunning = $false
    docker info 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $dockerRunning = $true
        Write-Ok "Docker Desktop: RODANDO"
    } else {
        Write-Warn "Docker Desktop: PARADO"
    }

    if ($dockerRunning) {
        $containers = docker ps --format "{{.Names}}|{{.Status}}|{{.Ports}}" 2>&1
        if ($containers) {
            Write-Info "Containers ativos:"
            $containers | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        } else {
            Write-Warn "Nenhum container em execucao"
        }
    }

    $ErrorActionPreference = $prevEAP

    Write-Info "Verificando portas..."
    $backendOk  = Test-HttpPort "http://localhost:8080/api/actuator/health"
    $frontendOk = Test-HttpPort "http://localhost:3000"

    if ($backendOk)  { Write-Ok  "Backend  -> http://localhost:8080/api  [ONLINE]"  }
    else             { Write-Warn "Backend  -> http://localhost:8080/api  [OFFLINE]" }

    if ($frontendOk) { Write-Ok  "Frontend -> http://localhost:3000       [ONLINE]"  }
    else             { Write-Warn "Frontend -> http://localhost:3000       [OFFLINE]" }

    if ($backendOk) {
        try {
            $body = '{"email":"smoke@test.com","password":"wrongpass"}'
            Invoke-WebRequest "http://localhost:8080/api/auth/login" `
                -Method POST -Body $body -ContentType "application/json" `
                -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop | Out-Null
        } catch {
            $code = $null
            try { $code = $_.Exception.Response.StatusCode.value__ -as [int] } catch {}
            if ($code -eq 401) { Write-Ok "Auth API: respondendo corretamente (401)" }
            else               { Write-Warn "Auth API: resposta inesperada ($code)"   }
        }
    }

    Write-Host ""
    if ($backendOk -and $frontendOk) {
        Write-Host "  Acesse o aplicativo em: " -NoNewline
        Write-Host "http://localhost:3000" -ForegroundColor Green
    }
}

# =========================================================
# Stop-AllServices: para todos os servicos
# =========================================================
function Stop-AllServices {
    Write-Title "Parando servicos PRD-GRA.NG"
    Set-Location $ROOT

    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    docker info 2>&1 | Out-Null
    $dockerRunning = ($LASTEXITCODE -eq 0)

    if ($dockerRunning) {
        Write-Info "Parando containers Docker..."
        docker compose -f docker-compose.dev.yml down --remove-orphans 2>&1 | ForEach-Object {
            if ($_ -notmatch "^$") { Write-Host "    $_" -ForegroundColor DarkGray }
        }
        Write-Ok "Containers parados"
    } else {
        Write-Warn "Docker nao esta rodando"
    }

    $ErrorActionPreference = $prevEAP

    # Parar processos locais por PIDs salvos
    $pidsFile = Join-Path $ROOT "logs\.pids.json"
    if (Test-Path $pidsFile) {
        $pids = Get-Content $pidsFile | ConvertFrom-Json
        foreach ($prop in $pids.PSObject.Properties) {
            $procId = $prop.Value -as [int]
            $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
            if ($proc) {
                Write-Info "Encerrando $($prop.Name) (PID ${procId})..."
                Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
                Write-Ok "$($prop.Name) encerrado"
            }
        }
        Remove-Item $pidsFile -Force -ErrorAction SilentlyContinue
    }

    # Limpar portas residuais
    foreach ($port in @(3000, 8080)) {
        $conns = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
        foreach ($conn in $conns) {
            $proc = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
            if ($proc -and $proc.ProcessName -notin @("wslrelay","com.docker.backend","docker","System")) {
                Write-Info "Encerrando $($proc.ProcessName) (PID $($proc.Id)) na porta ${port}..."
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            }
        }
    }
    Write-Ok "Servicos parados com sucesso"
}

# =========================================================
# Start-WithDocker: sobe via docker compose
# =========================================================
function Start-WithDocker {
    Write-Title "Iniciando com Docker Compose"
    Set-Location $ROOT

    Write-Info "Verificando Docker Desktop..."
    $dockerOk = $false
    $attempt  = 0

    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    while (-not $dockerOk -and $attempt -lt 3) {
        docker info 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $dockerOk = $true
        } else {
            $attempt++
            if ($attempt -eq 1) {
                Write-Warn "Docker Desktop nao esta rodando. Tentando iniciar..."
                $dockerExe = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
                if (Test-Path $dockerExe) {
                    Start-Process $dockerExe -WindowStyle Hidden
                } else {
                    Write-Warn "Executavel do Docker Desktop nao encontrado em: $dockerExe"
                    Write-Warn "Abra o Docker Desktop manualmente e tente novamente."
                }
            }
            Write-Info "Aguardando Docker inicializar... (tentativa ${attempt}/3)"
            Start-Sleep -Seconds 20
        }
    }

    if (-not $dockerOk) {
        Write-Fail "Docker Desktop nao disponivel."
        Write-Warn "Use: .\start-prdgra.ps1 -Modo local"
        exit 1
    }
    Write-Ok "Docker Desktop ativo"

    # ErrorActionPreference ja esta em "Continue" desde o bloco do while acima.
    # Verificar containers ja rodando
    $running = docker ps --filter "name=prd" --format "{{.Names}}" 2>&1
    if ($running) {
        Write-Warn "Containers ja em execucao: $($running -join ', ')"
        Write-Info "Parando containers existentes..."
        docker compose -f docker-compose.dev.yml down --remove-orphans 2>&1 | ForEach-Object {
            if ($_ -notmatch "^$") { Write-Host "    $_" -ForegroundColor DarkGray }
        }
        if ($LASTEXITCODE -ne 0) {
            $ErrorActionPreference = $prevEAP
            Write-Fail "Falha ao parar containers (codigo: $LASTEXITCODE)"
            exit 1
        }
        Write-Ok "Containers anteriores parados"
    }

    Write-Info "Construindo imagens e iniciando servicos..."
    Write-Host "  (Primeira execucao pode levar 3-5 minutos)" -ForegroundColor DarkGray

    docker compose -f docker-compose.dev.yml up --build -d 2>&1 | ForEach-Object {
        if ($_ -notmatch "^$") { Write-Host "    $_" -ForegroundColor DarkGray }
    }
    $buildExit = $LASTEXITCODE

    $ErrorActionPreference = $prevEAP   # restaurar apos todos os comandos docker

    if ($buildExit -ne 0) {
        Write-Fail "docker compose up falhou (codigo: $buildExit)"
        Write-Info "Verifique os logs: docker compose -f docker-compose.dev.yml logs"
        exit 1
    }

    $backendOk  = Wait-ForService "Backend"  "http://localhost:8080/api/actuator/health" 120
    $frontendOk = Wait-ForService "Frontend" "http://localhost:3000" 180

    if (-not $backendOk -or -not $frontendOk) {
        $ErrorActionPreference = "Continue"
        Write-Warn "Algum servico nao iniciou. Verificando logs..."
        docker compose -f docker-compose.dev.yml logs --tail=30
        $ErrorActionPreference = $prevEAP
        exit 1
    }
}

# =========================================================
# Start-WithLocal: sobe sem Docker (Java + Node direto)
# =========================================================
function Start-WithLocal {
    Write-Title "Iniciando em modo local (sem Docker)"

    # Verificar Java 17+
    Write-Info "Verificando Java..."
    $javaOk      = $false
    $javaExeFull = "java"   # caminho absoluto resolvido abaixo

    try {
        $verStr = java -version 2>&1 | Out-String
        if ($verStr -match '"(\d+)') {
            $major = [int]$Matches[1]
            if ($major -ge 17) {
                $javaOk = $true
                $javaCmd = Get-Command java -ErrorAction SilentlyContinue
                if ($javaCmd) { $javaExeFull = $javaCmd.Source }
            }
        }
    } catch {}

    if (-not $javaOk) {
        $candidates = @(
            "C:\Program Files\Amazon Corretto\jdk17*\bin\java.exe",
            "C:\Program Files\Amazon Corretto\jdk21*\bin\java.exe",
            "C:\Program Files\Java\jdk-21*\bin\java.exe",
            "C:\Program Files\Eclipse Adoptium\jdk-21*\bin\java.exe",
            "C:\Program Files\Eclipse Adoptium\jdk-17*\bin\java.exe",
            "C:\Program Files\Microsoft\jdk-21*\bin\java.exe",
            "C:\Program Files\Microsoft\jdk-17*\bin\java.exe"
        )
        foreach ($pattern in $candidates) {
            $found = Get-Item $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) {
                $javaExeFull = $found.FullName
                $javaOk      = $true
                break
            }
        }
    }

    if (-not $javaOk) {
        Write-Fail "Java 17+ nao encontrado."
        Write-Warn "Instale: https://adoptium.net  ou use: .\start-prdgra.ps1 -Modo docker"
        exit 1
    }
    Write-Ok "Java encontrado: $javaExeFull"

    # Verificar Node.js 18+
    Write-Info "Verificando Node.js..."
    try {
        $nodeVerStr = node --version
        $nodeMajor  = [int](($nodeVerStr -replace "v","").Split(".")[0])
        if ($nodeMajor -lt 18) {
            Write-Fail "Node.js $nodeVerStr encontrado, requer 18+. Instale: https://nodejs.org"
            exit 1
        }
        Write-Ok "Node.js $nodeVerStr"
    } catch {
        Write-Fail "Node.js nao encontrado. Instale: https://nodejs.org"
        exit 1
    }

    # Verificar/compilar Backend
    Write-Title "Compilando Backend (Spring Boot)"
    $backendDir = Join-Path $ROOT "backend"
    Set-Location $backendDir

    $jar = Get-ChildItem "$backendDir\target\*.jar" -ErrorAction SilentlyContinue |
           Where-Object { $_.Name -notlike "*sources*" } |
           Select-Object -First 1

    $needsBuild = $true
    if ($jar) {
        $latestSrc = Get-ChildItem "$backendDir\src" -Recurse -File |
                     Sort-Object LastWriteTime -Descending |
                     Select-Object -First 1
        if ($null -ne $latestSrc -and $latestSrc.LastWriteTime -le $jar.LastWriteTime) {
            $needsBuild = $false
        }
    }

    if ($needsBuild) {
        # --- Resolver JAVA_HOME antes do build ---
        # $javaExeFull ja foi resolvido para caminho absoluto na secao de verificacao de Java
        if ($javaExeFull -ne "java" -and (Test-Path $javaExeFull)) {
            $javaHome = Split-Path -Parent (Split-Path -Parent $javaExeFull)
            $env:JAVA_HOME = $javaHome
        }

        # --- Funcao interna: invoca Maven via wrapper JAR ou executavel ---
        function Invoke-Maven {
            param([string[]]$MvnArgs)

            $wrapperJar = Join-Path $backendDir ".mvn\wrapper\maven-wrapper.jar"

            # Prioridade 1: Maven Wrapper JAR (nao tem problema de espacos/aspas)
            if (Test-Path $wrapperJar) {
                Write-Ok "Usando Maven Wrapper (mvnw)"
                & $javaExeFull `
                    -classpath $wrapperJar `
                    "-Dmaven.multiModuleProjectDirectory=$backendDir" `
                    org.apache.maven.wrapper.MavenWrapperMain `
                    @MvnArgs
                return $LASTEXITCODE
            }

            # Prioridade 2: mvn no PATH
            $mvnInPath = Get-Command mvn -ErrorAction SilentlyContinue
            if ($mvnInPath) {
                Write-Ok "Usando Maven do PATH: $($mvnInPath.Source)"
                & mvn @MvnArgs
                return $LASTEXITCODE
            }

            # Prioridade 3: instalacoes conhecidas do Windows
            $candidates = @(
                "$env:ProgramFiles\apache-maven-*\bin\mvn.cmd",
                "$env:ProgramFiles\Apache\maven\bin\mvn.cmd",
                "$env:ProgramFiles\Maven\bin\mvn.cmd",
                "$env:LOCALAPPDATA\Programs\Maven\bin\mvn.cmd",
                "C:\tools\maven\bin\mvn.cmd",
                "C:\maven\bin\mvn.cmd"
            )
            foreach ($pattern in $candidates) {
                $found = Get-Item $pattern -ErrorAction SilentlyContinue |
                         Sort-Object Name -Descending | Select-Object -First 1
                if ($found) {
                    Write-Ok "Maven encontrado em: $($found.FullName)"
                    & $found.FullName @MvnArgs
                    return $LASTEXITCODE
                }
            }

            return -1  # nao encontrado
        }

        # Verificar se Maven esta disponivel antes de tentar compilar
        $wrapperJar = Join-Path $backendDir ".mvn\wrapper\maven-wrapper.jar"
        $hasMaven = (Test-Path $wrapperJar) -or
                    (Get-Command mvn -ErrorAction SilentlyContinue) -or
                    (Get-Item "$env:ProgramFiles\apache-maven-*\bin\mvn.cmd" -ErrorAction SilentlyContinue)

        if (-not $hasMaven) {
            Write-Fail "Maven nao encontrado no sistema."
            Write-Host ""
            Write-Host "  Opcoes para resolver:" -ForegroundColor Yellow
            Write-Host "  1. (Recomendado) Use Docker:"    -ForegroundColor Yellow
            Write-Host "       .\start-prdgra.ps1 -Modo docker"  -ForegroundColor Cyan
            Write-Host "  2. Instale Maven via winget:"    -ForegroundColor Yellow
            Write-Host "       winget install Apache.Maven"      -ForegroundColor Cyan
            Write-Host "  3. Baixe em: https://maven.apache.org/download.cgi" -ForegroundColor Cyan
            Write-Host ""
            exit 1
        }

        Write-Info "Compilando backend... (aguarde ~60s na primeira vez)"

        $buildExit = Invoke-Maven @("clean", "package", "-DskipTests", "-q")
        if ($buildExit -ne 0) {
            Write-Fail "Compilacao Maven falhou (codigo: $buildExit)."
            Write-Info "Para ver detalhes execute:"
            Write-Host "    cd backend" -ForegroundColor Cyan
            Write-Host "    .\mvnw.cmd clean package -DskipTests" -ForegroundColor Cyan
            exit 1
        }
        $jar = Get-ChildItem "$backendDir\target\*.jar" |
               Where-Object { $_.Name -notlike "*sources*" } |
               Select-Object -First 1
        Write-Ok "Backend compilado: $($jar.Name)"
    } else {
        Write-Ok "JAR atualizado: $($jar.Name) (pulando compilacao)"
    }

    # Preparar Frontend
    Write-Title "Preparando Frontend (Next.js)"
    $frontendDir = Join-Path $ROOT "frontend"
    Set-Location $frontendDir

    if (-not (Test-Path "node_modules")) {
        Write-Info "Instalando dependencias npm..."
        npm ci --silent
        if ($LASTEXITCODE -ne 0) { Write-Fail "npm ci falhou"; exit 1 }
        Write-Ok "Dependencias instaladas"
    } else {
        Write-Ok "node_modules encontrado (pulando npm install)"
    }

    # Liberar portas
    Write-Title "Liberando portas"
    foreach ($port in @(8080, 3000)) {
        $conns = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
        foreach ($conn in $conns) {
            $proc = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
            if ($proc -and $proc.ProcessName -notin @("wslrelay","com.docker.backend","docker","System","svchost")) {
                Write-Warn "Porta ${port} em uso por $($proc.ProcessName) (PID $($proc.Id)). Encerrando..."
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
            }
        }
    }
    Write-Ok "Portas verificadas"

    # Criar pasta de logs
    $logsDir = Join-Path $ROOT "logs"
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null

    # Iniciar Backend
    Write-Title "Iniciando Backend"
    Set-Location $backendDir
    $backendLog = Join-Path $logsDir "backend.log"

    # Perfil dev: desabilita rate limit para nao bloquear uso local e smoke tests (application-dev.yml)
    $backendProc = Start-Process $javaExeFull `
        -ArgumentList "-jar", "`"$($jar.FullName)`"", "-Dspring.profiles.active=dev" `
        -WorkingDirectory $backendDir `
        -WindowStyle Hidden `
        -RedirectStandardOutput $backendLog `
        -RedirectStandardError  "$backendLog.err" `
        -PassThru

    Write-Ok "Backend iniciado (PID $($backendProc.Id)) [perfil: dev]"
    Write-Info "Log: $backendLog"

    # Iniciar Frontend
    Write-Title "Iniciando Frontend"
    Set-Location $frontendDir
    $frontendLog = Join-Path $logsDir "frontend.log"

    # Localizar o binario JS real do Next.js (NAO o .cmd/.sh que sao wrappers shell/batch)
    # node "next.cmd" falha com SyntaxError pois .cmd e batch, nao JavaScript
    $nextJsBin = Join-Path $frontendDir "node_modules\next\dist\bin\next"
    if (-not (Test-Path $nextJsBin)) {
        Write-Fail "Binario do Next.js nao encontrado em: $nextJsBin"
        Write-Info "Reinstale as dependencias: cd frontend && npm ci"
        exit 1
    }

    $frontendProc = Start-Process "node" `
        -ArgumentList "`"$nextJsBin`"", "dev" `
        -WorkingDirectory $frontendDir `
        -WindowStyle Hidden `
        -RedirectStandardOutput $frontendLog `
        -RedirectStandardError  "$frontendLog.err" `
        -PassThru

    Write-Ok "Frontend iniciado (PID $($frontendProc.Id))"
    Write-Info "Log: $frontendLog"

    # Salvar PIDs
    @{
        Backend  = $backendProc.Id
        Frontend = $frontendProc.Id
    } | ConvertTo-Json | Set-Content (Join-Path $logsDir ".pids.json")

    # Aguardar servicos
    # Next.js 14 com typedRoutes experimental pode levar 2-3min no cold start
    $backendOk  = Wait-ForService "Backend"  "http://localhost:8080/api/actuator/health" 120
    $frontendOk = Wait-ForService "Frontend" "http://localhost:3000" 180

    if (-not $backendOk) {
        Write-Fail "Backend nao iniciou. Ultimas linhas do log:"
        Get-Content $backendLog -Tail 20 -ErrorAction SilentlyContinue
        exit 1
    }
    if (-not $frontendOk) {
        Write-Fail "Frontend nao iniciou. Ultimas linhas do log:"
        Get-Content $frontendLog -Tail 20 -ErrorAction SilentlyContinue
        exit 1
    }

    Set-Location $ROOT
}

# =========================================================
# Invoke-SmokeTests: testes rapidos de sanidade
# =========================================================
function Invoke-SmokeTests {
    param([switch]$RateLimitAtivo)
    Write-Title "Smoke Tests"

    $script:passed = 0
    $script:failed = 0

    function Test-Endpoint {
        param($Label, $Url, $Method="GET", $Body=$null, [int]$ExpectedCode)
        $code = 0
        try {
            $params = @{
                Uri             = $Url
                Method          = $Method
                TimeoutSec      = 10
                UseBasicParsing = $true
                ErrorAction     = "Stop"
            }
            if ($Body) {
                $params.Body        = $Body
                $params.ContentType = "application/json"
            }
            $r    = Invoke-WebRequest @params
            $code = $r.StatusCode
        } catch {
            try { $code = $_.Exception.Response.StatusCode.value__ -as [int] } catch {}
        }
        if ($code -eq $ExpectedCode) {
            Write-Ok "${Label} -> HTTP ${code} [PASS]"
            $script:passed++
        } else {
            Write-Fail "${Label} -> esperado ${ExpectedCode}, obtido ${code} [FAIL]"
            $script:failed++
        }
    }

    Test-Endpoint "Health check backend"       "http://localhost:8080/api/actuator/health"          -ExpectedCode 200
    Test-Endpoint "Frontend raiz"              "http://localhost:3000"                               -ExpectedCode 200
    Test-Endpoint "API protegida sem token"    "http://localhost:8080/api/prds"                      -ExpectedCode 401
    Test-Endpoint "Login credencial invalida"  "http://localhost:8080/api/auth/login" -Method POST `
                  -Body '{"email":"x@x.com","password":"wrongpass123"}' `
                  -ExpectedCode 401
    Test-Endpoint "Registro sem body"          "http://localhost:8080/api/auth/register" -Method POST `
                  -Body '{}' `
                  -ExpectedCode 400

    # Teste de rate limit: executado apenas em modo Docker (perfil prod, rate limit ativo).
    # Em modo local o backend sobe com perfil dev (app.rate-limit.enabled=false),
    # portanto o teste seria sempre FAIL e ainda bloquearia o IP para uso humano.
    if ($RateLimitAtivo) {
        Write-Info "Verificando ordem dos filtros (rate limit antes do JWT)..."
        $rlBody  = '{"email":"ratelimit@test.com","password":"wrongpass"}'
        $rlCode  = 0
        $prevEAP = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        for ($i = 1; $i -le 11; $i++) {
            try {
                $r = Invoke-WebRequest "http://localhost:8080/api/auth/login" `
                         -Method POST -Body $rlBody -ContentType "application/json" `
                         -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
                $rlCode = $r.StatusCode
            } catch {
                try { $rlCode = $_.Exception.Response.StatusCode.value__ -as [int] } catch { $rlCode = 0 }
            }
        }
        $ErrorActionPreference = $prevEAP
        if ($rlCode -eq 429) {
            Write-Ok "Rate limit: 429 na 11a tentativa [PASS] - filtro executando na ordem correta"
            $script:passed++
        } else {
            Write-Fail "Rate limit: esperado 429 na 11a tentativa, obtido $rlCode [FAIL]"
            $script:failed++
        }
        # Aguardar a janela de 60s expirar para nao bloquear login do usuario apos os testes
        Write-Info "Aguardando janela de rate limit expirar (65s) para liberar o login..."
        Start-Sleep -Seconds 65
        Write-Ok "Janela de rate limit expirada - login disponivel"
    } else {
        Write-Info "Rate limit desabilitado (perfil dev) - teste de rate limit ignorado"
    }

    # Teste de conflito de e-mail (409) - alinhado com GlobalExceptionHandler atualizado
    # Usa dominio example.com (RFC 2606 - reservado para testes, aceito pelo @Email do Hibernate Validator)
    # Dominio .local e rejeitado pelo validador Bean Validation antes de chegar ao AuthService
    $smokeEmail = "smoketest_$(Get-Date -Format 'HHmmss')@example.com"
    $smokeBody  = "{`"name`":`"Smoke`",`"email`":`"$smokeEmail`",`"password`":`"Smoke@1234`"}"
    # Primeira chamada: deve retornar 200 (registro bem-sucedido)
    Test-Endpoint "Registro novo usuario"      "http://localhost:8080/api/auth/register" -Method POST `
                  -Body $smokeBody `
                  -ExpectedCode 200
    # Segunda chamada com mesmo e-mail: GlobalExceptionHandler deve retornar 409 Conflict
    Test-Endpoint "Registro email duplicado"   "http://localhost:8080/api/auth/register" -Method POST `
                  -Body $smokeBody `
                  -ExpectedCode 409

    Test-Endpoint "Frontend /login"            "http://localhost:3000/login"                         -ExpectedCode 200
    Test-Endpoint "Frontend /register"         "http://localhost:3000/register"                      -ExpectedCode 200
    Test-Endpoint "Frontend /dashboard"        "http://localhost:3000/dashboard"                     -ExpectedCode 200

    Write-Host ""
    Write-Host "  Resultado: " -NoNewline
    Write-Host "$($script:passed) aprovados" -ForegroundColor Green -NoNewline
    Write-Host " | " -NoNewline
    $failColor = if ($script:failed -gt 0) { "Red" } else { "Green" }
    Write-Host "$($script:failed) reprovados" -ForegroundColor $failColor
}

# =========================================================
# Show-Summary: resumo final com URLs
# =========================================================
function Show-Summary {
    Write-Host ""
    Write-Host "  +--------------------------------------------+" -ForegroundColor Blue
    Write-Host "  |        PRD-GRA.NG  ATIVO E PRONTO         |" -ForegroundColor Blue
    Write-Host "  +--------------------------------------------+" -ForegroundColor Blue
    Write-Host "  |  Aplicativo  :  http://localhost:3000      |" -ForegroundColor Cyan
    Write-Host "  |  API         :  http://localhost:8080/api  |" -ForegroundColor Cyan
    Write-Host "  |  Health      :  /api/actuator/health       |" -ForegroundColor Cyan
    Write-Host "  +--------------------------------------------+" -ForegroundColor Blue
    Write-Host "  |  Rotas:                                    |" -ForegroundColor DarkGray
    Write-Host "  |    /           -> Landing page             |" -ForegroundColor DarkGray
    Write-Host "  |    /login      -> Entrar                   |" -ForegroundColor DarkGray
    Write-Host "  |    /register   -> Criar conta              |" -ForegroundColor DarkGray
    Write-Host "  |    /dashboard  -> Painel principal         |" -ForegroundColor DarkGray
    Write-Host "  |    /prd        -> Seus PRDs (requer login) |" -ForegroundColor DarkGray
    Write-Host "  |    /prd/new    -> Criar novo PRD           |" -ForegroundColor DarkGray
    Write-Host "  +--------------------------------------------+" -ForegroundColor Blue
    Write-Host "  |  Comandos uteis:                           |" -ForegroundColor Yellow
    Write-Host "  |    .\start-prdgra.ps1 -Modo status         |" -ForegroundColor Yellow
    Write-Host "  |    .\start-prdgra.ps1 -Modo parar          |" -ForegroundColor Yellow
    Write-Host "  +--------------------------------------------+" -ForegroundColor Blue
    Write-Host ""
}

# =========================================================
# Open-Browser: abre o app no navegador padrao
# =========================================================
function Open-Browser {
    Write-Info "Abrindo aplicativo no navegador..."
    Start-Sleep -Seconds 2
    try {
        Start-Process "http://localhost:3000"
    } catch {
        Write-Warn "Nao foi possivel abrir o browser automaticamente."
        Write-Warn "Acesse manualmente: http://localhost:3000"
    }
}

# =========================================================
# PONTO DE ENTRADA
# =========================================================
Set-Location $ROOT

switch ($Modo) {

    "status" {
        Show-Status
    }

    "parar" {
        Stop-AllServices
    }

    "docker" {
        Import-DotEnv
        Assert-EnvVars
        Start-WithDocker
        # Docker usa perfil prod: rate limit ativo, teste de rate limit habilitado
        Invoke-SmokeTests -RateLimitAtivo
        Show-Summary
        Open-Browser
    }

    "local" {
        Import-DotEnv
        Assert-EnvVars
        Start-WithLocal
        # Local usa perfil dev: rate limit desabilitado, teste de rate limit ignorado
        Invoke-SmokeTests
        Show-Summary
        Open-Browser
    }

    "auto" {
        Import-DotEnv
        Assert-EnvVars

        # Se ja esta rodando, apenas mostrar status
        $backendOk  = Test-HttpPort "http://localhost:8080/api/actuator/health"
        $frontendOk = Test-HttpPort "http://localhost:3000"

        if ($backendOk -and $frontendOk) {
            Write-Ok "PRD-GRA.NG ja esta rodando!"
            # Modo auto ja rodando: nao sabemos o perfil, omite teste de rate limit por seguranca
            Invoke-SmokeTests
            Show-Summary
            Open-Browser
            exit 0
        }

        # Detectar modo automaticamente
        $prevEAP2 = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        docker info 2>&1 | Out-Null
        $dockerAvailable = ($LASTEXITCODE -eq 0)
        $ErrorActionPreference = $prevEAP2

        if ($dockerAvailable) {
            Write-Ok "Docker detectado - usando modo Docker"
            Start-WithDocker
            # Docker: perfil prod com rate limit ativo
            Invoke-SmokeTests -RateLimitAtivo
        } else {
            Write-Warn "Docker nao disponivel - usando modo local"
            Start-WithLocal
            # Local: perfil dev com rate limit desabilitado
            Invoke-SmokeTests
        }

        Show-Summary
        Open-Browser
    }
}
