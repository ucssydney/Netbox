# Changelog

All notable changes to this NetBox deployment script will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-21

### Added
- Initial release of NetBox bare-metal deployment script
- Support for Debian 13 (Trixie)
- Automated installation of full NetBox stack (PostgreSQL, Redis, Gunicorn, Nginx)
- Auto-generation of cryptographic secrets (SECRET_KEY, API_TOKEN_PEPPERS)
- Automatic device type import from 10 vendors:
  - Ubiquiti (~100+ device types)
  - Cisco (~112 device types)
  - Lenovo (~46 device types)
  - Fortinet
  - tp-link (~1 device type)
  - Dell (~136 device types)
  - HP (~22 device types)
  - HPE (~429 device types)
  - HPE Aruba
  - Synology
- Idempotent script design (safe to re-run)
- Systemd service configuration for NetBox
- Nginx reverse proxy configuration
- Daily housekeeping cron job
- Automatic admin user creation
- Comprehensive error handling and logging
- Color-coded console output
- Detailed completion summary with credentials

### Security
- Random SECRET_KEY generation
- Random API_TOKEN_PEPPER generation
- Secure PostgreSQL password configuration
- Admin password prompt on first login

### Documentation
- Comprehensive README with installation instructions
- Troubleshooting guide
- Post-installation checklist
- MIT License
- .gitignore for repository hygiene

## [Unreleased]

### Planned
- TLS/SSL certificate configuration support
- Optional LDAP/Active Directory integration
- Backup script for database and media
- Docker deployment option
- Additional vendor support based on community requests

---

## Version History

- **1.0.0** - Initial public release
