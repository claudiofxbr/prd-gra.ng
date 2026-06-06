#!/usr/bin/env bash
# ssl-setup.sh - Gera certificado Let's Encrypt para xavierbr-vps.tech
#
# Execute na VPS como root:
#   bash /tmp/ssl-setup.sh
#
# Pre-requisitos:
#   1. DNS registro A de xavierbr-vps.tech apontando para o IP desta VPS
#   2. Porta 80 livre (containers parados ou nginx parado)
#   3. certbot instalado (apt-get install -y certbot)
set -euo pipefail

DOMAIN="xavierbr-vps.tech"
APP_DIR="/opt/prd-gra"
APP_NAME=$(basename "$APP_DIR")          # prd-gra
CERT_VOLUME="${APP_NAME}_certbot-certs"  # nome do volume Docker Compose

# ──────────────────────────────────────────────────────────────
# 1. Verificar pre-requisitos
# ──────────────────────────────────────────────────────────────
echo ""
echo "==> Configuracao de SSL para $DOMAIN"
echo "    Volume Docker: $CERT_VOLUME"
echo ""

if ! command -v certbot &>/dev/null; then
  echo "==> Instalando certbot..."
  apt-get update -qq
  apt-get install -y -qq certbot
fi

# ──────────────────────────────────────────────────────────────
# 2. Parar nginx (liberar porta 80 para o certbot standalone)
# ──────────────────────────────────────────────────────────────
echo "==> Parando nginx (para liberar porta 80)..."
if docker compose -f "$APP_DIR/docker-compose.yml" ps nginx 2>/dev/null | grep -q "running"; then
  docker compose -f "$APP_DIR/docker-compose.yml" stop nginx
  echo "    nginx parado."
else
  echo "    nginx nao estava rodando (OK)."
fi

# Garantir que a porta 80 esta livre
sleep 2
if ss -tlnp 2>/dev/null | grep -q ':80 ' || netstat -tlnp 2>/dev/null | grep -q ':80 '; then
  echo "    Porta 80 ainda em uso — tentando liberar..."
  fuser -k 80/tcp 2>/dev/null || true
  sleep 2
fi

# ──────────────────────────────────────────────────────────────
# 3. Coletar e-mail
# ──────────────────────────────────────────────────────────────
echo ""
read -r -p "Informe seu e-mail para o Let's Encrypt (ex: claudio.xavier@gmail.com): " LE_EMAIL </dev/tty
if [[ -z "$LE_EMAIL" ]]; then
  echo "ERRO: e-mail obrigatorio."
  exit 1
fi

# ──────────────────────────────────────────────────────────────
# 4. Emitir certificado
# ──────────────────────────────────────────────────────────────
echo ""
echo "==> Emitindo certificado para $DOMAIN..."
certbot certonly --standalone \
  --agree-tos \
  --no-eff-email \
  -m "$LE_EMAIL" \
  -d "$DOMAIN" \
  --non-interactive

echo "    Certificado gerado em: /etc/letsencrypt/live/$DOMAIN/"

# ──────────────────────────────────────────────────────────────
# 5. Copiar para o volume Docker Compose
# ──────────────────────────────────────────────────────────────
echo "==> Copiando certificados para o volume Docker '$CERT_VOLUME'..."
docker volume create "$CERT_VOLUME" 2>/dev/null || true
CERT_MOUNT=$(docker volume inspect "$CERT_VOLUME" --format '{{.Mountpoint}}')
cp -rL /etc/letsencrypt/. "$CERT_MOUNT/"
echo "    Certificados copiados para: $CERT_MOUNT"

# ──────────────────────────────────────────────────────────────
# 6. Configurar renovacao automatica
# ──────────────────────────────────────────────────────────────
echo "==> Configurando renovacao automatica..."
cat > /usr/local/bin/renew-certs.sh <<RENEW
#!/usr/bin/env bash
set -euo pipefail
APP_DIR="${APP_DIR}"
CERT_VOLUME="${CERT_VOLUME}"
docker compose -f "\$APP_DIR/docker-compose.yml" stop nginx 2>/dev/null || true
certbot renew --quiet --standalone
docker volume rm "\$CERT_VOLUME" 2>/dev/null || true
docker volume create "\$CERT_VOLUME"
CERT_MOUNT=\$(docker volume inspect "\$CERT_VOLUME" --format '{{.Mountpoint}}')
cp -rL /etc/letsencrypt/. "\$CERT_MOUNT/"
docker compose -f "\$APP_DIR/docker-compose.yml" start nginx
echo "Certificado renovado: \$(date)"
RENEW
chmod +x /usr/local/bin/renew-certs.sh

# Adicionar ao cron somente se ainda nao existir
if ! crontab -l 2>/dev/null | grep -q 'renew-certs'; then
  (crontab -l 2>/dev/null || true; echo "0 3 * * 0 /usr/local/bin/renew-certs.sh >> /var/log/certbot-renew.log 2>&1") | crontab -
  echo "    Cron de renovacao configurado (domingos 03h)."
else
  echo "    Cron de renovacao ja existe."
fi

# ──────────────────────────────────────────────────────────────
# 7. Reiniciar aplicacao completa
# ──────────────────────────────────────────────────────────────
echo "==> Reiniciando aplicacao..."
if [ -f "$APP_DIR/.env" ]; then
  docker compose -f "$APP_DIR/docker-compose.yml" --env-file "$APP_DIR/.env" up -d --remove-orphans
  echo "    Containers iniciados."
else
  echo "    AVISO: $APP_DIR/.env nao encontrado."
  echo "    Execute o deploy via GitHub Actions ou via deploy.ps1 para gerar o .env."
fi

# ──────────────────────────────────────────────────────────────
# 8. Verificar
# ──────────────────────────────────────────────────────────────
echo ""
echo "==> Verificando certificado..."
sleep 5
if echo Q | openssl s_client -servername "$DOMAIN" -connect "${DOMAIN}:443" 2>/dev/null | grep -q "Verify return code: 0"; then
  echo "    [OK] Certificado TLS valido em https://$DOMAIN"
else
  echo "    [AVISO] Certificado ainda nao verificado (containers podem estar iniciando)."
  echo "    Aguarde 30s e tente: curl -v https://$DOMAIN/prd-gra.ng/"
fi

echo ""
echo "==> Concluido!"
echo "    App:    https://$DOMAIN/prd-gra.ng/"
echo "    API:    https://$DOMAIN/api/actuator/health"
echo "    Certs:  /etc/letsencrypt/live/$DOMAIN/"
echo ""
