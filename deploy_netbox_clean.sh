#!/bin/bash
set -euo pipefail

# NetBox Deployment Script for Debian 13
# Edit the configuration section below before running

NETBOX_VERSION="v4.2.3"
DB_USER="netbox"
DB_PASS="YourStrongDBPasswordHere"
DB_NAME="netbox"
ALLOWED_HOSTS="['*']"
GUNICORN_BIND="127.0.0.1:8001"
GUNICORN_WORKERS=5
GUNICORN_THREADS=3
NGINX_LISTEN_PORT=80
NGINX_SERVER_NAME="netbox.yourcompany.com"
NETBOX_DIR="/opt/netbox"
NETBOX_USER="netbox"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

[[ "$(id -u)" -eq 0 ]] || err "This script must be run as root"

info "Installing system packages..."
apt-get update -qq
apt-get install -y -qq python3 python3-pip python3-venv python3-dev build-essential \
    libxml2-dev libxslt1-dev libffi-dev libpq-dev libssl-dev zlib1g-dev \
    postgresql postgresql-contrib redis-server nginx git curl wget

PYVER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
info "Python version: ${PYVER}"
python3 -c "import sys; sys.exit(0 if sys.version_info >= (3,12) else 1)" || \
    err "Python 3.12+ required. Current: ${PYVER}"

info "Configuring PostgreSQL..."
systemctl enable postgresql && systemctl start postgresql

sudo -u postgres psql <<EOSQL
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_USER}') THEN
        CREATE ROLE ${DB_USER} LOGIN PASSWORD '${DB_PASS}';
    ELSE
        ALTER ROLE ${DB_USER} PASSWORD '${DB_PASS}';
    END IF;
END
\$\$;
EOSQL

sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};" 2>/dev/null || true
sudo -u postgres psql -d "${DB_NAME}" -c "GRANT ALL ON SCHEMA public TO ${DB_USER};"

info "Configuring Redis..."
systemctl enable redis-server && systemctl start redis-server

info "Cloning NetBox ${NETBOX_VERSION}..."
if [[ -d "${NETBOX_DIR}/.git" ]]; then
    cd "${NETBOX_DIR}" && git fetch --all -q
else
    git clone https://github.com/netbox-community/netbox.git "${NETBOX_DIR}"
    cd "${NETBOX_DIR}"
fi
git checkout "${NETBOX_VERSION}"

info "Setting up netbox user..."
id "${NETBOX_USER}" &>/dev/null || adduser --system --group "${NETBOX_USER}"
chown -R "${NETBOX_USER}" "${NETBOX_DIR}/netbox/media/" \
    "${NETBOX_DIR}/netbox/reports/" "${NETBOX_DIR}/netbox/scripts/"

info "Generating secrets..."
SECRET_KEY=$(python3 -c "import secrets; print(''.join(secrets.choice('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*(-_=+)') for _ in range(50)))")
API_PEPPER=$(python3 -c "import secrets; print(''.join(secrets.choice('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*(-_=+)') for _ in range(50)))")

cd "${NETBOX_DIR}/netbox/netbox"
cp configuration_example.py configuration.py

cat > configuration.py <<PYCONF
ALLOWED_HOSTS = ${ALLOWED_HOSTS}
DATABASE = {
    'NAME': '${DB_NAME}',
    'USER': '${DB_USER}',
    'PASSWORD': '${DB_PASS}',
    'HOST': 'localhost',
    'PORT': '',
    'CONN_MAX_AGE': 300,
    'ENGINE': 'django.db.backends.postgresql',
}
REDIS = {
    'tasks': {'HOST': 'localhost', 'PORT': 6379, 'PASSWORD': '', 'DATABASE': 0, 'SSL': False},
    'caching': {'HOST': 'localhost', 'PORT': 6379, 'PASSWORD': '', 'DATABASE': 1, 'SSL': False}
}
SECRET_KEY = '${SECRET_KEY}'
API_TOKEN_PEPPERS = {1: '${API_PEPPER}'}
PYCONF

info "Running upgrade.sh..."
deactivate 2>/dev/null || true
"${NETBOX_DIR}/upgrade.sh"

info "Creating admin user..."
source "${NETBOX_DIR}/venv/bin/activate"
cd "${NETBOX_DIR}/netbox"

EXISTING=$(python3 manage.py shell -c "from django.contrib.auth import get_user_model; User=get_user_model(); print(User.objects.filter(is_superuser=True).count())")
if [[ "${EXISTING}" -eq 0 ]]; then
    python3 manage.py createsuperuser --username admin --email "" --noinput <<< ""
    python3 manage.py shell -c "from django.contrib.auth import get_user_model; User=get_user_model(); u=User.objects.get(username='admin'); u.set_password('ChangeThisPassword!'); u.save()"
    warn "Default password: ChangeThisPassword! - CHANGE IT!"
fi
deactivate

info "Configuring Gunicorn..."
cat > "${NETBOX_DIR}/gunicorn.py" <<GCONF
bind = '${GUNICORN_BIND}'
workers = ${GUNICORN_WORKERS}
threads = ${GUNICORN_THREADS}
timeout = 120
max_requests = 5000
max_requests_jitter = 500
GCONF

cat > /etc/systemd/system/netbox.service <<SVCCONF
[Unit]
Description=NetBox WSGI Server
After=network.target postgresql.service redis-server.service
Wants=postgresql.service redis-server.service

[Service]
Type=simple
User=${NETBOX_USER}
Group=${NETBOX_USER}
WorkingDirectory=${NETBOX_DIR}/netbox
ExecStart=${NETBOX_DIR}/venv/bin/gunicorn netbox.wsgi:application --config ${NETBOX_DIR}/gunicorn.py
Restart=on-failure
RestartSec=5
LimitNOFILE=1024

[Install]
WantedBy=multi-user.target
SVCCONF

systemctl daemon-reload && systemctl enable netbox && systemctl start netbox

info "Configuring Nginx..."
cat > /etc/nginx/sites-available/netbox <<NGCONF
server {
    listen ${NGINX_LISTEN_PORT};
    server_name ${NGINX_SERVER_NAME:-_};
    client_max_body_size 2M;

    location /static/ {
        alias ${NETBOX_DIR}/netbox/netbox/static_files/;
        expires 30d;
    }

    location /media/ {
        alias ${NETBOX_DIR}/netbox/netbox/media/;
        expires 30d;
    }

    location / {
        proxy_pass http://${GUNICORN_BIND};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGCONF

ln -sf /etc/nginx/sites-available/netbox /etc/nginx/sites-enabled/netbox
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl enable nginx && systemctl restart nginx

ln -sf "${NETBOX_DIR}/contrib/netbox-housekeeping.sh" /etc/cron.daily/netbox-housekeeping

info "Importing device types..."
source "${NETBOX_DIR}/venv/bin/activate"
cd "${NETBOX_DIR}/netbox"
API_TOKEN=$(python3 manage.py shell -c "from users.models import Token; from django.contrib.auth import get_user_model; User=get_user_model(); user=User.objects.get(username='admin'); token,_=Token.objects.get_or_create(user=user); print(token.key)")
deactivate

IMPORT_DIR="/tmp/netbox-device-type-import"
[[ -d "${IMPORT_DIR}" ]] && cd "${IMPORT_DIR}" && git pull -q || \
    git clone https://github.com/netbox-community/Device-Type-Library-Import.git "${IMPORT_DIR}"

cd "${IMPORT_DIR}"
python3 -m venv venv
source venv/bin/activate
pip install -q -r requirements.txt

export NETBOX_URL="http://localhost:${NGINX_LISTEN_PORT}"
export NETBOX_TOKEN="${API_TOKEN}"
export VENDORS="Ubiquiti,Cisco,Lenovo,Fortinet,tp-link,Dell,HP,HPE,HPE Aruba,Synology"

python3 nb-dt-import.py
deactivate

echo ""
echo -e "${GREEN}NetBox deployment complete!${NC}"
echo -e "URL: http://${NGINX_SERVER_NAME:-localhost}:${NGINX_LISTEN_PORT}"
echo -e "User: admin | Pass: ChangeThisPassword!"
echo -e "API Token: ${API_TOKEN}"
echo ""
