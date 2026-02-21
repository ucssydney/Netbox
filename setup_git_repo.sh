# Quick Start Guide

Get NetBox running in 5 minutes.

## Prerequisites

- Debian 13 (Trixie) server
- Root/sudo access
- Internet connection

## Installation

```bash
# 1. Download the script
wget https://raw.githubusercontent.com/YOUR_USERNAME/netbox-deployment/main/deploy_netbox.sh
chmod +x deploy_netbox.sh

# 2. Edit configuration (REQUIRED)
nano deploy_netbox.sh
# Change these lines:
#   DB_PASS="YourStrongDBPasswordHere"
#   ALLOWED_HOSTS="['netbox.example.com']"  # or your IP
#   NGINX_SERVER_NAME="netbox.example.com"

# 3. Run the script
sudo ./deploy_netbox.sh

# 4. Wait ~10-15 minutes for completion
```

## First Login

```
URL: http://your-server-ip/
Username: admin
Password: ChangeThisPassword!
```

**⚠️ CHANGE THE PASSWORD IMMEDIATELY**

## Verify Device Types

1. Navigate to **Organization → Manufacturers**
2. You should see: Ubiquiti, Cisco, Dell, HP, HPE, Lenovo, Fortinet, Synology, tp-link
3. Click any manufacturer → see imported device types

## Next Steps

- [ ] Change admin password
- [ ] Create additional users (optional)
- [ ] Configure LDAP/SSO (optional)
- [ ] Set up TLS/SSL for production
- [ ] Configure backup strategy
- [ ] Read [full documentation](README.md)

## Troubleshooting

**Can't access web UI?**
```bash
sudo systemctl status netbox nginx
sudo journalctl -u netbox -n 50
```

**Device types missing?**
```bash
# Re-run import manually
cd /tmp/netbox-device-type-import
source venv/bin/activate
export NETBOX_URL="http://localhost"
export NETBOX_TOKEN="[your-api-token-from-install]"
export VENDORS="Ubiquiti,Cisco,Dell,HP,HPE,Lenovo,Fortinet,Synology,tp-link,HPE Aruba"
python3 import_devices.py
```

---

For detailed documentation, see [README.md](README.md)
