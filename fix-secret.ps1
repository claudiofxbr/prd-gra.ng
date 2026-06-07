#!/usr/bin/env pwsh
# fix-secret.ps1 — Recadastra DATABASE_URL no GitHub Secrets de forma segura
# Uso: .\fix-secret.ps1
# O valor e lido de forma interativa e gravado em arquivo temporario para
# evitar que '#' em senhas seja truncado pelo shell ou pelo pipe do PowerShell.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GH_REPO = "claudiofxbr/prd-gra.ng"

Write-Host ""
Write-Host "  Recadastro seguro de DATABASE_URL"
Write-Host "  Repositorio: $GH_REPO"
Write-Host ""
Write-Host "  Cole a URL completa do Neon PostgreSQL."
Write-Host "  Formato: postgresql://usuario:senha@ep-xxx.neon.tech/banco?sslmode=verify-full"
Write-Host ""
Write-Host "  DATABASE_URL: " -NoNewline

# Leitura como SecureString para nao exibir na tela
$ss  = Read-Host -AsSecureString
$url = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
           [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ss))

if (-not $url) {
    Write-Host "  [ERRO] URL nao pode estar vazia."
    exit 1
}

# Verificar formato basico
if (-not ($url -match "^postgresql://")) {
    Write-Host "  [AVISO] URL nao comeca com 'postgresql://' — verifique o valor."
}

# Gravar em arquivo temporario (evita que o shell interprete caracteres especiais no pipe)
$tmp = [System.IO.Path]::GetTempFileName()
try {
    # Gravar sem BOM, sem nova linha extra
    [System.IO.File]::WriteAllText($tmp, $url, [System.Text.Encoding]::UTF8)

    Write-Host ""
    Write-Host "  Cadastrando DATABASE_URL no GitHub Secrets..." -NoNewline

    # Usar --body-file para garantir que o valor e lido byte a byte sem interpretacao de shell
    $result = gh secret set DATABASE_URL --repo $GH_REPO --body-file $tmp 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host " OK"
        Write-Host ""
        Write-Host "  [OK] DATABASE_URL atualizado com sucesso."
    } else {
        Write-Host " FALHOU"
        Write-Host "  [ERRO] $result"
        exit 1
    }
} finally {
    Remove-Item $tmp -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "  Proximos passos:"
Write-Host "  1. Disparar novo deploy:"
Write-Host "     git commit --allow-empty -m 'chore: retry deploy apos corrigir DATABASE_URL'"
Write-Host "     git push origin main"
Write-Host ""
Write-Host "  2. Acompanhar CI:"
Write-Host "     gh run watch --repo $GH_REPO"
Write-Host ""
