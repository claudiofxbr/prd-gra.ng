#!/bin/bash
# ==============================================================================
# PRD-GRA.NG - Script de Bootstrap SSL para VPS Hostinger
# ==============================================================================
# Este script resolve o problema do "ovo e da galinha" (Nginx dependendo de 
# certificados SSL que ainda não existem). Ele levanta um container temporário
# standalone do Certbot para obter o primeiro certificado SSL antes de iniciar a stack.
# ==============================================================================

set -e

# Cores para output
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # Sem cor

echo -e "${CYAN}==> PRD-GRA.NG SSL Bootstrapper ${NC}"

# Carregar variáveis do .env se existir
if [ -f .env ]; then
    echo -e "  [...] Carregando variáveis do arquivo .env..."
    export $(grep -v '^#' .env | xargs)
else
    echo -e "${RED}  [ERR] Arquivo .env não encontrado.${NC}"
    echo -e "${YELLOW}  [!] Por favor, crie o arquivo .env e preencha as variáveis DOMAIN e EMAIL antes de rodar o bootstrap.${NC}"
    exit 1
fi

if [ -z "$DOMAIN" ]; then
    echo -e "${RED}  [ERR] Variável DOMAIN não definida no .env.${NC}"
    exit 1
fi

EMAIL_CERTBOT=${EMAIL:-"admin@$DOMAIN"}

# Verificar se a porta 80 está em uso
if lsof -Pi :80 -sTCP:LISTEN -t >/dev/null ; then
    echo -e "${YELLOW}  [!] A porta 80 já está em uso. Parando serviços conflitantes temporariamente...${NC}"
    docker compose down || true
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
