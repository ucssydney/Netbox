# Contributing to NetBox Deployment Script

Thank you for considering contributing to this project! This guide will help you get started.

## 🤝 How to Contribute

### Reporting Bugs

If you find a bug, please open an issue with:
- **Clear description** of the problem
- **Steps to reproduce** the issue
- **Expected behavior** vs actual behavior
- **System information**: Debian version, NetBox version, Python version
- **Relevant logs** from the script output or systemd

### Suggesting Enhancements

Feature requests are welcome! Please:
- Check existing issues to avoid duplicates
- Clearly describe the use case
- Explain why this would benefit other users
- Be open to discussion about implementation

### Pull Requests

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/your-feature-name`
3. **Make your changes**
4. **Test thoroughly** on a clean Debian install
5. **Update documentation** (README, CHANGELOG)
6. **Commit with clear messages**: Use conventional commits format
7. **Push to your fork**
8. **Open a Pull Request** with a detailed description

## 📝 Code Guidelines

### Script Style

- Use `#!/usr/bin/env bash` shebang
- Follow existing code style and indentation (4 spaces)
- Add comments for complex logic
- Use descriptive variable names
- Keep functions focused and single-purpose

### Error Handling

- Always use `set -euo pipefail` at the top
- Check return codes for critical operations
- Provide helpful error messages
- Use the existing `err()`, `warn()`, `info()` functions

### Testing

Before submitting, test on:
- ✅ Fresh Debian 13 (Trixie) installation
- ✅ Re-running the script (idempotency check)
- ✅ Verify NetBox web UI is accessible
- ✅ Confirm device types import successfully

## 📦 Adding New Vendors

To add a new vendor to the device type import:

1. **Verify vendor exists** in [devicetype-library](https://github.com/netbox-community/devicetype-library/tree/master/device-types)
2. **Check exact folder name** (case-sensitive!)
3. **Update VENDORS list** in the script
4. **Update all documentation**:
   - README.md vendor table
   - CHANGELOG.md
   - Info banner in script
   - Completion banner in script
   - Top-of-file comment

### Example

```bash
# In deploy_netbox.sh
export VENDORS="Ubiquiti,Cisco,...,NewVendor"

# Update info banner
info " Vendors: Ubiquiti, Cisco, ..., NewVendor"

# Update README.md table
| **NewVendor** | ~X | Description |
```

## 🔄 Version Updates

When updating NetBox version:

1. Test with the new version thoroughly
2. Update `NETBOX_VERSION` default in script
3. Update README.md
4. Add entry to CHANGELOG.md
5. Tag the release: `git tag v1.x.x`

## 📋 Commit Message Format

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>: <description>

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

**Examples:**
```
feat: add support for Synology device types

fix: correct PostgreSQL permission issue on Debian 13

docs: update troubleshooting section in README
```

## 🧪 Testing Checklist

Before submitting a PR, verify:

- [ ] Script runs without errors on fresh Debian 13
- [ ] NetBox web UI is accessible
- [ ] Admin login works
- [ ] Device types imported successfully
- [ ] All systemd services start correctly
- [ ] Nginx serves content properly
- [ ] Re-running script doesn't break installation
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] No secrets or credentials committed

## 📞 Questions?

- Open a [GitHub Discussion](../../discussions)
- Join [NetBox Community Slack](https://netdev.chat/)
- Create an issue with the `question` label

## 📜 Code of Conduct

- Be respectful and inclusive
- Welcome newcomers
- Focus on constructive feedback
- Assume good intentions

---

Thank you for contributing! 🎉
