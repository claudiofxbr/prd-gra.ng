#!/usr/bin/env bash
# vps-bootstrap.sh - Bootstrap completo para VPS Hostinger KVM 2
# Dominio: xavierbr-vps.tech
# Execute como root: bash vps-bootstrap.sh
set -euo pipefail

DOMAIN="xavierbr-vps.tech"
APP_DIR="/opt/prd-gra"
DEPLOY_USER="deploy"

# Derivar nome do volume a partir do diretorio da aplicacao (Docker Compose usa basename do dir como prefixo)
APP_NAME=$(basename "$APP_DIR")   # prd-gra
CERT_VOLUME_NAME="${APP_NAME}_certbot-certs"

# ─────────────────────────────────────────────────────────────
# 1. Atualizar sistema
# ─────────────────────────────────────────────────────────────
echo "==> [1/7] Atualizando sistema..."
apt-get update -qq
apt-get upgrade -y -qq
# docker-compose-plugin: necessario para 'docker compose' (V2, sem hifen)
apt-get install -y -qq curl wget git ufw fail2ban certbot docker-compose-plugin

# ─────────────────────────────────────────────────────────────
# 2. Firewall
# ─────────────────────────────────────────────────────────────
echo "==> [2/7] Configurando firewall (UFW)..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# fail2ban: protecao basica contra brute-force SSH
echo "==> [2/7] Configurando fail2ban para SSH..."
cat > /etc/fail2ban/jail.local <<'FAIL2BAN'
[sshd]
enabled  = true
port     = ssh
maxretry = 5
bantime  = 3600
findtime = 600
FAIL2BAN
systemctl enable fail2ban
systemctl restart fail2ban
echo "    fail2ban configurado: max 5 tentativas SSH, ban por 1h."

# ─────────────────────────────────────────────────────────────
# 3. Instalar Docker
# ─────────────────────────────────────────────────────────────
echo "==> [3/7] Instalando Docker..."
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sh
  systemctl enable docker
  systemctl start docker
else
  echo "    Docker ja instalado: $(docker --version)"
fi

# Verificar Docker Compose V2 (plugin)
if ! docker compose version &>/dev/null; then
  echo "    Instalando docker-compose-plugin separadamente..."
  apt-get install -y -qq docker-compose-plugin
fi
echo "    Docker Compose: $(docker compose version)"

# ─────────────────────────────────────────────────────────────
# 4. Criar usuario de deploy
# ─────────────────────────────────────────────────────────────
echo "==> [4/7] Configurando usuario '$DEPLOY_USER'..."
if ! id "$DEPLOY_USER" &>/dev/null; then
  useradd -m -s /bin/bash "$DEPLOY_USER"
fi
usermod -aG docker "$DEPLOY_USER"

mkdir -p /home/"$DEPLOY_USER"/.ssh
chmod 700 /home/"$DEPLOY_USER"/.ssh

if [ -f /root/.ssh/authorized_keys ]; then
  cp /root/.ssh/authorized_keys /home/"$DEPLOY_USER"/.ssh/authorized_keys
  chmod 600 /home/"$DEPLOY_USER"/.ssh/authorized_keys
  chown -R "$DEPLOY_USER":"$DEPLOY_USER" /home/"$DEPLOY_USER"/.ssh
  echo "    Chave SSH copiada de /root."
else
  echo "    AVISO: /root/.ssh/authorized_keys nao encontrado."
  echo "    Adicione a chave publica SSH do CI/CD manualmente em:"
  echo "    /home/$DEPLOY_USER/.ssh/authorized_keys"
fi

# ─────────────────────────────────────────────────────────────
# 5. Criar diretorio da aplicacao
# ─────────────────────────────────────────────────────────────
echo "==> [5/7] Criando diretorio $APP_DIR..."
mkdir -p "$APP_DIR"
chown -R "$DEPLOY_USER":"$DEPLOY_USER" "$APP_DIR"
chmod 750 "$APP_DIR"

# ─────────────────────────────────────────────────────────────
# 6. Certificado SSL (Let's Encrypt via certbot standalone)
# ─────────────────────────────────────────────────────────────
echo "==> [6/7] Obtendo certificado SSL para $DOMAIN..."
echo ""
echo "    PRE-REQUISITO: o registro A do DNS de $DOMAIN"
echo "    deve apontar para o IP desta VPS antes de continuar."
echo "    Porta 80 deve estar LIVRE (nginx ainda nao esta rodando neste ponto)."
echo ""
read -r -p "    O DNS ja esta propagado e a porta 80 esta livre? (s/N) " dns_ok </dev/tty
if [[ ! "$dns_ok" =~ ^[sS]$ ]]; then
  echo "    Pulando emissao do certificado. Execute manualmente quando o DNS propagar:"
  echo "      certbot certonly --standalone -d $DOMAIN --agree-tos -m SEU@EMAIL.COM"
  echo "    Depois copie os certificados para o volume Docker:"
  echo "      docker volume create ${CERT_VOLUME_NAME}"
  echo "      CERT_VOLUME=\$(docker volume inspect ${CERT_VOLUME_NAME} --format '{{.Mountpoint}}')"
  echo "      cp -rL /etc/letsencrypt/. \"\$CERT_VOLUME/\""
  echo ""
else
  read -r -p "    Informe seu e-mail para o Let's Encrypt: " le_email </dev/tty

  # Garantir que porta 80 esteja livre antes de usar standalone
  if ss -tlnp | grep -q ':80 '; then
    echo "    AVISO: porta 80 em uso. Parando servico..."
    fuser -k 80/tcp 2>/dev/null || true
    sleep 2
  fi

  certbot certonly --standalone \
    --agree-tos \
    --no-eff-email \
    -m "$le_email" \
    -d "$DOMAIN"

  # Criar volume Docker e copiar certificados
  docker volume create "$CERT_VOLUME_NAME" 2>/dev/null || true
  CERT_VOLUME=$(docker volume inspect "$CERT_VOLUME_NAME" --format '{{.Mountpoint}}')
  cp -rL /etc/letsencrypt/. "$CERT_VOLUME/"
  echo "    Certificado copiado para o volume Docker: $CERT_VOLUME"

  # Script de renovacao reutilizavel (evita linha de cron longa e fragil)
  cat > /usr/local/bin/renew-certs.sh <<RENEW_SCRIPT
#!/usr/bin/env bash
set -euo pipefail
CERT_VOLUME_NAME="${CERT_VOLUME_NAME}"
APP_DIR="${APP_DIR}"
# Parar nginx temporariamente para liberar porta 80
docker compose -f "\$APP_DIR/docker-compose.yml" stop nginx 2>/dev/null || true
# Renovar certificado
certbot renew --quiet --standalone
# Recriar volume e copiar novos certificados
docker volume rm "\$CERT_VOLUME_NAME" 2>/dev/null || true
docker volume create "\$CERT_VOLUME_NAME"
CERT_MOUNT=\$(docker volume inspect "\$CERT_VOLUME_NAME" --format '{{.Mountpoint}}')
cp -rL /etc/letsencrypt/. "\$CERT_MOUNT/"
# Reiniciar nginx com novo certificado
docker compose -f "\$APP_DIR/docker-compose.yml" start nginx
echo "Certificado renovado e nginx reiniciado: \$(date)"
RENEW_SCRIPT
  chmod +x /usr/local/bin/renew-certs.sh

  # Cron: renovacao automatica domingo as 03h com log
  (crontab -l 2>/dev/null || true; echo "0 3 * * 0 /usr/local/bin/renew-certs.sh >> /var/log/certbot-renew.log 2>&1") | crontab -
  echo "    Renovacao automatica configurada (domingo as 03h via /usr/local/bin/renew-certs.sh)."
fi

# ─────────────────────────────────────────────────────────────
# 7. Proximos passos
# ─────────────────────────────────────────────────────────────
echo ""
echo "==> [7/7] Proximos passos"
echo ""
echo "  1. Configure os seguintes Secrets no repositorio GitHub"
echo "     (Settings -> Secrets and variables -> Actions):"
echo ""
echo "     VPS_HOST            = IP publico desta VPS"
echo "     VPS_USER            = deploy"
echo "     VPS_SSH_KEY         = conteudo da chave privada SSH do usuario deploy"
echo "     DATABASE_URL        = postgresql://user:pass@ep-xxx.neon.tech/prdgra?sslmode=verify-full"
echo "     JWT_SECRET          = (gere com: openssl rand -base64 64)"
echo "     NEXT_PUBLIC_API_URL = https://${DOMAIN}/api"
echo "     CORS_ALLOWED_ORIGINS= https://${DOMAIN}"
echo "     DOMAIN              = ${DOMAIN}"
echo "     TRUSTED_PROXY_IP    = (veja passo 2 abaixo)"
echo ""
echo "  2. Apos o primeiro deploy (git push origin main), descubra o IP"
echo "     interno do container nginx na frontend-net e atualize TRUSTED_PROXY_IP."
echo "     O nginx esta nas redes frontend-net E backend-net (necessario para proxy /api)."
echo ""
echo "       docker inspect \$(docker compose -f ${APP_DIR}/docker-compose.yml ps -q nginx) \\"
echo "         --format '{{json .NetworkSettings.Networks}}' | python3 -m json.tool"
echo ""
echo "     Copie o campo \"IPAddress\" dentro da chave \"*_frontend-net\"."
echo "     Atualize o Secret TRUSTED_PROXY_IP no GitHub com esse valor."
echo "     Depois faca um novo push para aplicar."
echo ""
echo "  3. Validacao pos-deploy:"
echo "       # Status dos containers"
echo "       docker compose -f ${APP_DIR}/docker-compose.yml ps"
echo ""
echo "       # Logs"
echo "       docker compose -f ${APP_DIR}/docker-compose.yml logs -f --tail=50"
echo ""
echo "       # Smoke test"
echo "       curl -sk https://${DOMAIN}/api/actuator/health | python3 -m json.tool"
echo ""
echo "       # Frontend"
echo "       curl -sk https://${DOMAIN} | grep -q '<html' && echo 'Frontend OK'"
echo ""
echo "Bootstrap concluido. Esta VPS esta pronta para receber o primeiro deploy via GitHub Actions."
