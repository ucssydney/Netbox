#!/bin/bash
# ==============================================================================
# NetBox Bare-Metal Deployment Script - Debian 13 (Trixie)
# ==============================================================================
# What this script does:
#   1. Installs all system dependencies (PostgreSQL, Redis, Python 3.12+, Nginx)
#   2. Creates the PostgreSQL database and user
#   3. Clones NetBox from the official repo (latest stable tag)
#   4. Generates SECRET_KEY and API_TOKEN_PEPPER automatically
#   5. Writes configuration.py with your DB/Redis/host settings
#   6. Runs the official upgrade.sh to set up venv + migrations
#   7. Creates the admin superuser
#   8. Configures Gunicorn + Nginx for production
#   9. Enables + starts all services
#  10. Runs the Device-Type-Library-Import to pull device types for:
#      Ubiquiti, Cisco, Dell, Lenovo, Fortinet, HP, HPE, HPE Aruba, tp-link, Synology
#
# Usage:
#   sudo bash deploy_netbox.sh
#
# BEFORE you run this, edit the variables in the CONFIG block below.
# ==============================================================================

set -euo pipefail

# ==============================================================================
# >>>  CONFIGURATION - EDIT THESE BEFORE RUNNING  <<<
# ==============================================================================

# --- NetBox version tag (check https://github.com/netbox-community/netbox/releases) ---
NETBOX_VERSION="v4.2.3"                  # e.g. v4.2.3

# --- Database ---
DB_USER="netbox"
DB_PASS="YourStrongDBPasswordHere"       # <<< CHANGE THIS
DB_NAME="netbox"

# --- NetBox host / network ---
# Put your hostname or IP(s) here. Use '*' if unsure right now.
ALLOWED_HOSTS="['*']"                    # e.g. "['netbox.yourcompany.com', '192.168.1.10']"

# --- Gunicorn / Nginx ---
GUNICORN_BIND="127.0.0.1:8001"
GUNICORN_WORKERS=5
GUNICORN_THREADS=3
NGINX_LISTEN_PORT=80                     # change to 443 if you handle TLS at Nginx
# If you have a domain / cert, set these (otherwise leave blank and we skip TLS):
NGINX_SERVER_NAME="netbox.yourcompany.com"   # or leave blank
# NGINX_TLS_CERT="/path/to/cert.pem"
# NGINX_TLS_KEY="/path/to/key.pem"

# ==============================================================================
#  DO NOT EDIT BELOW THIS LINE (unless you know what you're doing)
# ==============================================================================

NETBOX_DIR="/opt/netbox"
NETBOX_USER="netbox"

# Color helpers
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# Sanity check
[[ "$(id -u)" -eq 0 ]] || err "This script must be run as root (sudo)."

# ==============================================================================
# 1. SYSTEM PACKAGES
# ==============================================================================
info "Installing system packages..."
apt-get update -qq
apt-get install -y -qq \
    python3 python3-pip python3-venv python3-dev \
    build-essential \
    libxml2-dev libxslt1-dev libffi-dev libpq-dev libssl-dev zlib1g-dev \
    postgresql postgresql-contrib \
    redis-server \
    nginx \
    git \
    curl wget

# Verify Python >= 3.12
PYVER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
info "Python version: ${PYVER}"
if python3 -c "import sys; sys.exit(0 if sys.version_info >= (3,12) else 1)"; then
    info "Python >= 3.12 confirmed."
else
    err "Python 3.12+ is required. Your system Python is ${PYVER} - please install 3.12+ and rerun."
fi

# ==============================================================================
# 2. POSTGRESQL - create database & user
# ==============================================================================
info "Configuring PostgreSQL..."
systemctl enable postgresql && systemctl start postgresql

# Allow script to be re-run safely (IF EXISTS / IF NOT EXISTS)
sudo -u postgres psql <<EOF
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_USER}') THEN
        CREATE ROLE ${DB_USER} LOGIN PASSWORD '${DB_PASS}';
    ELSE
        ALTER ROLE ${DB_USER} PASSWORD '${DB_PASS}';
    END IF;
END
\$\$;
EOF

sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};" 2>/dev/null || true
sudo -u postgres psql -d "${DB_NAME}" -c "GRANT ALL ON SCHEMA public TO ${DB_USER};"
info "PostgreSQL ready - database '${DB_NAME}', user '${DB_USER}'."

# ==============================================================================
# 3. REDIS
# ==============================================================================
info "Configuring Redis..."
systemctl enable redis-server && systemctl start redis-server
info "Redis is running."

# ==============================================================================
# 4. CLONE NETBOX
# ==============================================================================
info "Cloning NetBox ${NETBOX_VERSION}..."
if [[ -d "${NETBOX_DIR}/.git" ]]; then
    warn "NetBox directory already exists. Pulling latest and checking out ${NETBOX_VERSION}..."
    cd "${NETBOX_DIR}"
    git fetch --all -q
else
    git clone https://github.com/netbox-community/netbox.git "${NETBOX_DIR}"
    cd "${NETBOX_DIR}"
fi
git checkout "${NETBOX_VERSION}"

# ==============================================================================
# 5. CREATE SYSTEM USER & SET OWNERSHIP
# ==============================================================================
info "Setting up netbox system user..."
if ! id "${NETBOX_USER}" &>/dev/null; then
    adduser --system --group "${NETBOX_USER}"
fi
chown --recursive "${NETBOX_USER}" \
    "${NETBOX_DIR}/netbox/media/" \
    "${NETBOX_DIR}/netbox/reports/" \
    "${NETBOX_DIR}/netbox/scripts/"

# ==============================================================================
# 6. GENERATE SECRETS & WRITE configuration.py
# ==============================================================================
info "Generating secrets and writing configuration.py..."
cd "${NETBOX_DIR}/netbox/netbox"
cp configuration_example.py configuration.py

# Generate SECRET_KEY and PEPPER (50+ random alphanumeric characters)
SECRET_KEY=$(python3 -c "import secrets; print(''.join(secrets.choice('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*(-_=+)') for _ in range(50)))")
API_PEPPER=$(python3 -c "import secrets; print(''.join(secrets.choice('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*(-_=+)') for _ in range(50)))")

cat > configuration.py <<CONFEOF
##############################################################################
# NetBox configuration - auto-generated by deploy_netbox.sh
# Generated: $(date -u)
##############################################################################

ALLOWED_HOSTS = ${ALLOWED_HOSTS}

# -- Database -----------------------------------------------------------------
DATABASE = {
    'NAME': '${DB_NAME}',
    'USER': '${DB_USER}',
    'PASSWORD': '${DB_PASS}',
    'HOST': 'localhost',
    'PORT': '',
    'CONN_MAX_AGE': 300,
    'ENGINE': 'django.db.backends.postgresql',
}

# -- Redis --------------------------------------------------------------------
REDIS = {
    'tasks': {
        'HOST': 'localhost',
        'PORT': 6379,
        'PASSWORD': '',
        'DATABASE': 0,
        'SSL': False,
    },
    'caching': {
        'HOST': 'localhost',
        'PORT': 6379,
        'PASSWORD': '',
        'DATABASE': 1,
        'SSL': False,
    }
}

# -- Secrets ------------------------------------------------------------------
SECRET_KEY = '${SECRET_KEY}'

API_TOKEN_PEPPERS = {
    1: '${API_PEPPER}',
}

# -- Misc ---------------------------------------------------------------------
# Uncomment / adjust as needed:
# LOGIN_URL = '/en/account/login'
# TIME_ZONE = 'UTC'
# LANGUAGE_CODE = 'en-us'
CONFEOF

info "configuration.py written."

# ==============================================================================
# 7. RUN upgrade.sh (venv, pip install, migrations, static files)
# ==============================================================================
info "Running NetBox upgrade.sh (this may take a few minutes)..."
# Deactivate any existing venv to avoid conflicts
deactivate 2>/dev/null || true
"${NETBOX_DIR}/upgrade.sh"

# ==============================================================================
# 8. CREATE SUPERUSER
# ==============================================================================
info "Creating admin superuser..."
source "${NETBOX_DIR}/venv/bin/activate"
cd "${NETBOX_DIR}/netbox"

# Only create if no superuser exists yet (idempotent)
EXISTING=$(python3 manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
print(User.objects.filter(is_superuser=True).count())
")
if [[ "${EXISTING}" -eq 0 ]]; then
    python3 manage.py createsuperuser --username admin --email "" --noinput <<< ""
    # Set a known password via Django shell
    python3 manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
u = User.objects.get(username='admin')
u.set_password('ChangeThisPassword!')
u.save()
print('Superuser admin created - password: ChangeThisPassword!')
"
    warn ">>> Log in and change the admin password immediately. <<<"
else
    info "Superuser already exists - skipping."
fi
deactivate

# ==============================================================================
# 9. GUNICORN - service file
# ==============================================================================
info "Writing Gunicorn configuration and systemd service..."

# gunicorn.py config
cat > "${NETBOX_DIR}/gunicorn.py" <<GUNICONF
bind = '${GUNICORN_BIND}'
workers = ${GUNICORN_WORKERS}
threads = ${GUNICORN_THREADS}
timeout = 120
max_requests = 5000
max_requests_jitter = 500
GUNICONF

# systemd unit
cat > /etc/systemd/system/netbox.service <<SVCEOF
[Unit]
Description=NetBox WSGI Server (Gunicorn)
After=network.target postgresql.service redis-server.service
Wants=postgresql.service redis-server.service

[Service]
Type=simple
User=${NETBOX_USER}
Group=${NETBOX_USER}
WorkingDirectory=${NETBOX_DIR}/netbox
ExecStart=${NETBOX_DIR}/venv/bin/gunicorn \
    netbox.wsgi:application \
    --config ${NETBOX_DIR}/gunicorn.py
Restart=on-failure
RestartSec=5
LimitNOFILE=1024

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable netbox
systemctl start netbox
info "Gunicorn (netbox) service started."

# ==============================================================================
# 10. NETBOX HOUSEKEEPING CRON
# ==============================================================================
info "Enabling housekeeping cron..."
ln -sf "${NETBOX_DIR}/contrib/netbox-housekeeping.sh" /etc/cron.daily/netbox-housekeeping
info "Housekeeping cron linked."

# ==============================================================================
# 11. NGINX REVERSE PROXY
# ==============================================================================
info "Writing Nginx reverse-proxy config..."

cat > /etc/nginx/sites-available/netbox <<NGINXEOF
server {
    listen ${NGINX_LISTEN_PORT};
    server_name ${NGINX_SERVER_NAME:-_};

    client_max_body_size 2M;

    location /static/ {
        alias ${NETBOX_DIR}/netbox/netbox/static_files/;
        expires 30d;
        access_log off;
    }

    location /media/ {
        alias ${NETBOX_DIR}/netbox/netbox/media/;
        expires 30d;
        access_log off;
    }

    location / {
        proxy_pass         http://${GUNICORN_BIND};
        proxy_set_header   Host               \$host;
        proxy_set_header   X-Real-IP          \$remote_addr;
        proxy_set_header   X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto  \$scheme;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade            \$http_upgrade;
        proxy_set_header   Connection         "upgrade";
    }
}
NGINXEOF

ln -sf /etc/nginx/sites-available/netbox /etc/nginx/sites-enabled/netbox
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl enable nginx && systemctl restart nginx
info "Nginx is serving NetBox on port ${NGINX_LISTEN_PORT}."

# ==============================================================================
# 12. IMPORT DEVICE TYPES (Ubiquiti, Cisco, Dell, Lenovo, Fortinet, HP, HPE, tp-link, Synology)
# ==============================================================================
info "============================================================"
info " Importing device types via Device-Type-Library-Import"
info " Vendors: Ubiquiti, Cisco, Lenovo, Fortinet, tp-link,"
info "          Dell, HP, HPE, HPE Aruba, Synology"
info "============================================================"

# We need an API token to call NetBox's API. Create one via Django shell.
source "${NETBOX_DIR}/venv/bin/activate"
cd "${NETBOX_DIR}/netbox"

API_TOKEN=$(python3 manage.py shell -c "
from users.models import Token
from django.contrib.auth import get_user_model
User = get_user_model()
user = User.objects.get(username='admin')
token, created = Token.objects.get_or_create(user=user)
print(token.key)
")
info "API token ready."
deactivate

# Clone the Device-Type-Library-Import tool into a temp directory
IMPORT_DIR="/tmp/netbox-device-type-import"
if [[ -d "${IMPORT_DIR}" ]]; then
    cd "${IMPORT_DIR}" && git pull -q
else
    git clone https://github.com/netbox-community/Device-Type-Library-Import.git "${IMPORT_DIR}"
fi

cd "${IMPORT_DIR}"
python3 -m venv venv
source venv/bin/activate
pip install -q -r requirements.txt

# The import script expects NETBOX_URL and NETBOX_TOKEN env vars, plus an optional VENDORS filter.
# It will also auto-clone the devicetype-library repo internally.
export NETBOX_URL="http://localhost:${NGINX_LISTEN_PORT}"
export NETBOX_TOKEN="${API_TOKEN}"
export VENDORS="Ubiquiti,Cisco,Lenovo,Fortinet,tp-link,Dell,HP,HPE,HPE Aruba,Synology"

info "Running import for all selected vendors..."
python3 nb-dt-import.py

deactivate

# ==============================================================================
# DONE
# ==============================================================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            NetBox deployment complete!                      ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  Web UI  →  http://${NGINX_SERVER_NAME:-localhost}:${NGINX_LISTEN_PORT}                         ║${NC}"
echo -e "${GREEN}║  Admin user   : admin                                       ║${NC}"
echo -e "${GREEN}║  Admin pass   : ChangeThisPassword!                         ║${NC}"
echo -e "${GREEN}║  DB password  : ${DB_PASS}                              ║${NC}"
echo -e "${GREEN}║  API token    : ${API_TOKEN}                        ║${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}║  Device types imported for:                                  ║${NC}"
echo -e "${GREEN}║    Ubiquiti · Cisco · Dell · Lenovo · Fortinet               ║${NC}"
echo -e "${GREEN}║    HP · HPE · HPE Aruba · tp-link · Synology                 ║${NC}"
echo -e "${GREEN}║  → Change the admin password on first login!                 ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
