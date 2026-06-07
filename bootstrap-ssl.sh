#!/usr/bin/env bash
# ==============================================================================
# PRD-GRA.NG - Script de Bootstrap SSL para VPS Hostinger
# ==============================================================================
# Este script resolve o problema do "ovo e da galinha" (Nginx dependendo de
# certificados SSL que ainda nao existem). Ele levanta um container temporario
# standalone do Certbot para obter o primeiro certificado SSL antes de iniciar a stack.
# ==============================================================================

set -euo pipefail

# Cores para output
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}==> PRD-GRA.NG SSL Bootstrapper ${NC}"

# Carregar variaveis do .env de forma segura — sem export $(xargs) que quebra
# com valores contendo espacos, aspas ou caracteres especiais.
if [ -f .env ]; then
    echo -e "  [...] Carregando variaveis do arquivo .env..."
    while IFS='=' read -r key value; do
        # Ignorar comentarios, linhas vazias e keys invalidas
        [[ -z "$key" || "$key" =~ ^# || ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] && continue
        # Remover aspas externas do valor se existirem
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"
        export "$key=$value"
    done < .env
else
    echo -e "${RED}  [ERR] Arquivo .env nao encontrado.${NC}"
    echo -e "${YELLOW}  [!] Crie o .env com DOMAIN e EMAIL antes de executar.${NC}"
    exit 1
fi

if [ -z "${DOMAIN:-}" ]; then
    echo -e "${RED}  [ERR] Variavel DOMAIN nao definida no .env.${NC}"
    exit 1
fi

EMAIL_CERTBOT="${EMAIL:-admin@$DOMAIN}"

# Verificar se a porta 80 esta em uso — usa ss (disponivel em Ubuntu moderno) com fallback para netstat
port80_in_use() {
    if command -v ss &>/dev/null; then
        ss -tlnp | grep -q ':80 '
    elif command -v netstat &>/dev/null; then
        netstat -tlnp 2>/dev/null | grep -q ':80 '
    else
        # Fallback: tentar conectar na porta
        timeout 1 bash -c 'echo > /dev/tcp/127.0.0.1/80' 2>/dev/null
    fi
}

if port80_in_use; then
    echo -e "${YELLOW}  [!] Porta 80 em uso. Parando containers...${NC}"
    docker compose down || true
    sleep 2
fi

echo -e "  [...] Solicitando certificado SSL para: ${GREEN}$DOMAIN${NC} (Email: $EMAIL_CERTBOT)"

# Criar os volumes do Docker se não existirem
docker volume create prd-gra_certbot-certs || true
docker volume create prd-gra_certbot-www || true

# Rodar certbot standalone temporário para obter o certificado
docker run --rm \
  -p 80:80 \
  -v prd-gra_certbot-certs:/etc/letsencrypt \
  -v prd-gra_certbot-www:/var/www/certbot \
  certbot/certbot certonly \
  --standalone \
  -d "$DOMAIN" \
  -m "$EMAIL_CERTBOT" \
  --agree-tos \
  --no-eff-email \
  --non-interactive

# Verificar se o certificado foi gerado
CERT_PATH="/var/lib/docker/volumes/prd-gra_certbot-certs/_data/live/$DOMAIN/fullchain.pem"
if docker run --rm -v prd-gra_certbot-certs:/certs alpine test -f "/certs/live/$DOMAIN/fullchain.pem"; then
    echo -e "${GREEN}  [OK] Certificado SSL obtido com sucesso!${NC}"
    echo -e "  [...] Reiniciando a stack definitiva com docker-compose..."
    docker compose up -d
else
    echo -e "${RED}  [ERR] Falha ao verificar a existência do certificado SSL gerado.${NC}"
    exit 1
fi
