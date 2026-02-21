# NetBox Bare-Metal Deployment Script

Automated deployment script for NetBox on Debian 13 (Trixie) with pre-populated device types from major infrastructure vendors.

## 🚀 Features

- **Complete NetBox Stack**: Installs PostgreSQL, Redis, Gunicorn, and Nginx
- **Production-Ready**: Systemd services, housekeeping cron, proper security
- **Pre-Populated Device Library**: Automatically imports 800+ device types from 10 vendors
- **Idempotent**: Safe to re-run without breaking existing installations
- **Auto-Configuration**: Generates secrets, creates admin user, configures all services

## 📦 What Gets Installed

### Core Components
- **NetBox** (latest stable release)
- **PostgreSQL** (database)
- **Redis** (caching & task queue)
- **Gunicorn** (WSGI server)
- **Nginx** (reverse proxy)

### Device Types Pre-Loaded
The script automatically imports device types for:

| Vendor | Count | Coverage |
|--------|-------|----------|
| **HPE** | ~429 | ProLiant servers, Aruba switches |
| **Dell** | ~136 | PowerEdge servers, switches, storage |
| **Cisco** | ~112 | Catalyst, ASR, ISR, Nexus |
| **Ubiquiti** | ~100+ | UniFi, EdgeRouter, switches, APs |
| **Lenovo** | ~46 | ThinkSystem servers, networking |
| **HP** | ~22 | Legacy HP gear |
| **HPE Aruba** | Various | Aruba-specific networking |
| **Fortinet** | Various | FortiGate, FortiSwitch, FortiAP |
| **Synology** | Various | RackStation, DiskStation NAS |
| **tp-link** | ~1 | Switches, routers |

**Total: ~800+ device types**

## 🔧 Requirements

- **OS**: Debian 13 (Trixie) - testing/unstable
  - Also works on Debian 12 with Python 3.12+ installed
- **Access**: Root/sudo privileges
- **Resources**: 
  - 2GB+ RAM recommended
  - 10GB+ disk space
  - Internet connection for package installation

## 📋 Pre-Installation

Before running the script, edit the configuration section at the top:

```bash
# --- NetBox version tag ---
NETBOX_VERSION="v4.2.3"

# --- Database ---
DB_USER="netbox"
DB_PASS="YourStrongDBPasswordHere"       # ⚠️ CHANGE THIS
DB_NAME="netbox"

# --- NetBox host / network ---
ALLOWED_HOSTS="['*']"                    # Or ['netbox.example.com', '192.168.1.10']

# --- Nginx ---
NGINX_LISTEN_PORT=80
NGINX_SERVER_NAME="netbox.yourcompany.com"
```

## 🚀 Installation

1. **Download the script:**
   ```bash
   wget https://raw.githubusercontent.com/YOUR_USERNAME/netbox-deployment/main/deploy_netbox.sh
   chmod +x deploy_netbox.sh
   ```

2. **Edit the configuration** (see Pre-Installation section above)

3. **Run the script:**
   ```bash
   sudo ./deploy_netbox.sh
   ```

4. **Installation takes ~10-15 minutes** depending on your connection speed

## 🎯 Post-Installation

Once complete, you'll see:

```
╔══════════════════════════════════════════════════════════════╗
║            NetBox deployment complete!                      ║
╠══════════════════════════════════════════════════════════════╣
║  Web UI  →  http://netbox.yourcompany.com:80                ║
║  Admin user   : admin                                       ║
║  Admin pass   : ChangeThisPassword!                         ║
║  DB password  : [your DB password]                          ║
║  API token    : [generated token]                           ║
║                                                              ║
║  Device types imported for:                                  ║
║    Ubiquiti · Cisco · Dell · Lenovo · Fortinet               ║
║    HP · HPE · HPE Aruba · tp-link · Synology                 ║
║  → Change the admin password on first login!                 ║
╚══════════════════════════════════════════════════════════════╝
```

### Critical First Steps

1. **Change the admin password** immediately
2. **Save the API token** somewhere secure
3. Navigate to **Organization → Manufacturers** to verify device types imported

## 🔒 Security Considerations

- The script generates random `SECRET_KEY` and `API_TOKEN_PEPPERS`
- Default admin password is `ChangeThisPassword!` - **CHANGE IT IMMEDIATELY**
- Database password must be set in the config before running
- Consider setting up TLS/SSL for production (add cert paths to config)

## 🛠️ What the Script Does

1. ✅ Updates system packages
2. ✅ Installs PostgreSQL + creates database/user
3. ✅ Installs Redis
4. ✅ Clones NetBox from official repo
5. ✅ Generates cryptographic secrets
6. ✅ Writes configuration.py
7. ✅ Runs upgrade.sh (venv, migrations, static files)
8. ✅ Creates admin superuser
9. ✅ Configures Gunicorn systemd service
10. ✅ Configures Nginx reverse proxy
11. ✅ Sets up daily housekeeping cron
12. ✅ Imports 800+ device types from 10 vendors

## 🔄 Updating NetBox

To upgrade to a newer version:

1. Edit `NETBOX_VERSION` in the script
2. Re-run: `sudo ./deploy_netbox.sh`

The script will:
- Pull the new version
- Checkout the specified tag
- Run migrations
- Restart services

## 🐛 Troubleshooting

### Python version error
```
Error: Python 3.12+ is required
```
**Solution**: Debian 13 ships with Python 3.13. If on Debian 12, install from backports:
```bash
sudo apt install python3.12
```

### NetBox won't start
```bash
sudo systemctl status netbox
sudo journalctl -u netbox -n 50
```

### Database connection issues
Check PostgreSQL is running:
```bash
sudo systemctl status postgresql
```

Verify credentials in `/opt/netbox/netbox/netbox/configuration.py`

### Nginx errors
```bash
sudo nginx -t
sudo systemctl status nginx
```

### Device types not imported
Re-run just the import section manually:
```bash
cd /tmp/netbox-device-type-import
source venv/bin/activate
export NETBOX_URL="http://localhost"
export NETBOX_TOKEN="[your token]"
export VENDORS="Ubiquiti,Cisco,Lenovo,Fortinet,tp-link,Dell,HP,HPE,HPE Aruba,Synology"
python3 import_devices.py
```

## 📂 File Locations

- **NetBox root**: `/opt/netbox`
- **Configuration**: `/opt/netbox/netbox/netbox/configuration.py`
- **Virtual environment**: `/opt/netbox/venv`
- **Media uploads**: `/opt/netbox/netbox/media`
- **Systemd service**: `/etc/systemd/system/netbox.service`
- **Nginx config**: `/etc/nginx/sites-available/netbox`
- **Housekeeping cron**: `/etc/cron.daily/netbox-housekeeping`

## 🔗 Useful Commands

```bash
# Restart NetBox
sudo systemctl restart netbox

# View NetBox logs
sudo journalctl -u netbox -f

# Check service status
sudo systemctl status netbox postgresql redis-server nginx

# Access NetBox shell
cd /opt/netbox/netbox
source /opt/netbox/venv/bin/activate
python3 manage.py shell

# Create additional superusers
cd /opt/netbox/netbox
source /opt/netbox/venv/bin/activate
python3 manage.py createsuperuser
```

## 📚 Resources

- [NetBox Documentation](https://netboxlabs.com/docs/netbox/)
- [NetBox GitHub](https://github.com/netbox-community/netbox)
- [Device Type Library](https://github.com/netbox-community/devicetype-library)
- [NetBox Community Slack](https://netdev.chat/)

## 🤝 Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Test your changes thoroughly
4. Submit a pull request

## ⚖️ License

This deployment script is provided as-is under the MIT License.

NetBox itself is licensed under Apache 2.0 by NetBox Labs.

## 🙏 Credits

- **NetBox**: [NetBox Labs](https://netboxlabs.com/) & the NetBox community
- **Device Type Library**: [netbox-community/devicetype-library](https://github.com/netbox-community/devicetype-library)
- **Import Script**: [netbox-community/Device-Type-Library-Import](https://github.com/netbox-community/Device-Type-Library-Import)

---

**Need help?** Open an issue or reach out via NetBox community channels.
