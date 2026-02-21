#!/usr/bin/env bash
# ==============================================================================
# Git Repository Setup Helper
# ==============================================================================
# This script helps you initialize and push this repository to GitHub
#
# Usage:
#   bash setup_git_repo.sh
# ==============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     NetBox Deployment Script - Git Repository Setup         ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "Git is not installed. Installing..."
    sudo apt-get update -qq
    sudo apt-get install -y git
fi

# Get repository details from user
echo -e "${YELLOW}Please provide your GitHub repository details:${NC}"
echo ""
read -p "GitHub username: " GITHUB_USER
read -p "Repository name (e.g., netbox-deployment): " REPO_NAME
echo ""

# Initialize git if not already initialized
if [ ! -d .git ]; then
    echo "Initializing Git repository..."
    git init
    echo ""
fi

# Configure git user if not set
if [ -z "$(git config user.name)" ]; then
    read -p "Your name for Git commits: " GIT_NAME
    git config user.name "$GIT_NAME"
fi

if [ -z "$(git config user.email)" ]; then
    read -p "Your email for Git commits: " GIT_EMAIL
    git config user.email "$GIT_EMAIL"
fi

# Add all files
echo "Staging files..."
git add .

# Check if there are changes to commit
if git diff --cached --quiet; then
    echo "No changes to commit."
else
    # Create initial commit
    echo "Creating initial commit..."
    git commit -m "feat: initial commit - NetBox deployment script with device type import

- Complete NetBox bare-metal installation script for Debian 13
- Automated PostgreSQL, Redis, Gunicorn, Nginx setup
- Pre-configured device type import for 10 vendors
- 800+ device types from Ubiquiti, Cisco, Dell, HP, HPE, Lenovo, Fortinet, Synology, tp-link
- Comprehensive documentation and guides
- MIT License"
fi

# Set main branch
git branch -M main

# Add remote (if not already added)
REMOTE_URL="https://github.com/${GITHUB_USER}/${REPO_NAME}.git"
if ! git remote get-url origin &> /dev/null; then
    echo "Adding remote origin..."
    git remote add origin "$REMOTE_URL"
else
    echo "Updating remote origin..."
    git remote set-url origin "$REMOTE_URL"
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    Setup Complete!                           ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  Next Steps:                                                 ║${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}║  1. Create a new repository on GitHub:                      ║${NC}"
echo -e "${GREEN}║     https://github.com/new                                   ║${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}║     Repository name: ${REPO_NAME}                            ║${NC}"
echo -e "${GREEN}║     Description: NetBox bare-metal deployment script        ║${NC}"
echo -e "${GREEN}║     Public/Private: Your choice                              ║${NC}"
echo -e "${GREEN}║     DO NOT initialize with README, .gitignore, or license    ║${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}║  2. Push to GitHub:                                          ║${NC}"
echo -e "${GREEN}║     git push -u origin main                                  ║${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}║  3. Update README.md with your repo URL                      ║${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}║  Your remote URL:                                            ║${NC}"
echo -e "${GREEN}║  ${REMOTE_URL}${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
