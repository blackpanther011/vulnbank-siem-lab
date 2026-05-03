#!/bin/bash
# =============================================================
# VulnBank SIEM Lab — Reset Script
# Tears down and optionally rebuilds the lab from scratch
# =============================================================
# Usage: sudo ./scripts/reset-lab.sh [--full]
#   --full  also removes Wazuh (slow — use for clean reinstall)
# =============================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

ok()   { echo -e "${GREEN}✓ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
info() { echo -e "→ $1"; }

[[ $EUID -ne 0 ]] && { echo -e "${RED}Run as root.${NC}"; exit 1; }

FULL_RESET=false
[[ "${1:-}" == "--full" ]] && FULL_RESET=true

echo -e "\n${CYAN}VulnBank SIEM Lab — Reset${NC}\n"

# Stop and remove VulnBank
if [ -d /opt/vuln-bank ]; then
  info "Stopping VulnBank containers"
  cd /opt/vuln-bank && docker-compose down -v 2>/dev/null
  ok "VulnBank stopped"
fi

# Prune stopped containers and unused images
docker system prune -f > /dev/null 2>&1
ok "Docker cleaned up"

if $FULL_RESET; then
  warn "Full reset: removing Wazuh installation"
  if [ -f /tmp/wazuh-install.sh ]; then
    bash /tmp/wazuh-install.sh -u 2>/dev/null || true
  fi
  rm -rf /var/ossec/ /etc/wazuh-* 2>/dev/null || true
  ok "Wazuh removed"
fi

echo -e "\n${GREEN}Reset complete.${NC}"
echo "To redeploy: sudo ./scripts/setup-kali.sh   (or setup-ubuntu.sh)"
