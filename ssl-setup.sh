#!/usr/bin/env bash
# ssl-setup.sh - Gera certificado Let's Encrypt para xavierbr-vps.tech
#
# Uso: bash ssl-setup.sh EMAIL
#   EMAIL: e-mail para registro no Let's Encrypt (obrigatorio)
#
# Pre-requisitos:
#   1. DNS registro A de xavierbr-vps.tech apontando para o IP desta VPS
#   2. Porta 80 livre (containers parados ou nginx parado)
#   3. certbot instalado (apt-get install -y certbot)
set -euo pipefail

# E-mail passado como argumento — sem read interativo (compativel com SSH nao-TTY)
LE_EMAIL="${1:-}"
if [[ -z "$LE_EMAIL" ]]; then
  echo "ERRO: informe o e-mail como argumento."
  echo "Uso: bash ssl-setup.sh SEU@EMAIL.COM"
  exit 1
fi
echo "==> E-mail Let's Encrypt: $LE_EMAIL"

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
  echo "==> Instalando certbot via snap (metodo oficial para Ubuntu 20+)..."
  apt-get update -qq
  apt-get install -y -qq snapd
  snap install --classic certbot 2>/dev/null || apt-get install -y -qq certbot
  ln -sf /snap/bin/certbot /usr/bin/certbot 2>/dev/null || true
fi
# Garantir que certbot e executavel e nao e wrapper quebrado
if ! certbot --version &>/dev/null; then
  echo "ERRO: certbot instalado mas nao funcional."
  echo "Tente: snap install --classic certbot && ln -sf /snap/bin/certbot /usr/bin/certbot"
  exit 1
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
# 3. Emitir certificado
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
# Criar volume se não existir (primeira vez)
docker volume create "$CERT_VOLUME" 2>/dev/null || true
CERT_MOUNT=$(docker volume inspect "$CERT_VOLUME" --format '{{.Mountpoint}}')
cp -rL /etc/letsencrypt/. "$CERT_MOUNT/"

# O Certbot cria diretorios numerados (xavierbr-vps.tech-0001, -0002...) a cada nova emissao.
# O nginx.conf referencia apenas '${DOMAIN}' sem sufixo. Garantir que o diretorio base
# sempre contenha o certificado mais recente (Let's Encrypt), nao um autoassinado anterior.
LATEST_CERT_DIR=$(ls -dt /etc/letsencrypt/live/${DOMAIN}* 2>/dev/null | grep -v "^/etc/letsencrypt/live/${DOMAIN}$" | head -1)
if [ -n "$LATEST_CERT_DIR" ]; then
  echo "    Sincronizando cert mais recente: $LATEST_CERT_DIR -> ${DOMAIN}/"
  mkdir -p "$CERT_MOUNT/live/${DOMAIN}"
  for f in fullchain.pem privkey.pem cert.pem chain.pem; do
    [ -f "$LATEST_CERT_DIR/$f" ] && cp "$LATEST_CERT_DIR/$f" "$CERT_MOUNT/live/${DOMAIN}/$f"
  done
fi
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

# Parar nginx para liberar porta 80
docker compose -f "\$APP_DIR/docker-compose.yml" stop nginx 2>/dev/null || true

# Renovar certificado (só age se faltar < 30 dias)
certbot renew --quiet --standalone

# Backup do volume atual antes de destrui-lo — garante rollback se a copia falhar
CERT_MOUNT_OLD=\$(docker volume inspect "\$CERT_VOLUME" --format '{{.Mountpoint}}' 2>/dev/null || echo "")
BACKUP_DIR="/tmp/certbot-backup-\$(date +%s)"
if [ -n "\$CERT_MOUNT_OLD" ] && [ -d "\$CERT_MOUNT_OLD" ]; then
  mkdir -p "\$BACKUP_DIR"
  cp -rL "\$CERT_MOUNT_OLD/." "\$BACKUP_DIR/" 2>/dev/null || true
fi

# Recriar volume e copiar novos certificados
docker volume rm "\$CERT_VOLUME" 2>/dev/null || true
docker volume create "\$CERT_VOLUME"
CERT_MOUNT=\$(docker volume inspect "\$CERT_VOLUME" --format '{{.Mountpoint}}')
if ! cp -rL /etc/letsencrypt/. "\$CERT_MOUNT/"; then
  echo "ERRO: falha ao copiar certificados. Restaurando backup..."
  if [ -n "\$BACKUP_DIR" ] && [ -d "\$BACKUP_DIR" ]; then
    cp -rL "\$BACKUP_DIR/." "\$CERT_MOUNT/"
  fi
fi
[ -n "\$BACKUP_DIR" ] && rm -rf "\$BACKUP_DIR"

# Reiniciar nginx com novo certificado
docker compose -f "\$APP_DIR/docker-compose.yml" start nginx
echo "Certificado renovado: \$(date)"
RENEW
chmod +x /usr/local/bin/renew-certs.sh

# Cron 2x/semana (segunda e quinta, 03h) — Let's Encrypt recomenda verificacao frequente
# para garantir renovacao dentro da janela de 30 dias antes do vencimento.
if ! crontab -l 2>/dev/null | grep -q 'renew-certs'; then
  (crontab -l 2>/dev/null || true; echo "0 3 * * 1,4 /usr/local/bin/renew-certs.sh >> /var/log/certbot-renew.log 2>&1") | crontab -
  echo "    Cron de renovacao configurado (segunda e quinta, 03h)."
else
  echo "    Cron de renovacao ja existe (verifique se usa '* * 1,4' para 2x/semana)."
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
