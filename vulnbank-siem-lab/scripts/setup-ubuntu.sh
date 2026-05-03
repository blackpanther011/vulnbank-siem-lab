#!/bin/bash
# =============================================================
# VulnBank SIEM Lab — Automated Setup Script for Ubuntu Server
# Tested on Ubuntu 22.04 LTS and 24.04 LTS
# =============================================================
# Usage: sudo ./scripts/setup-ubuntu.sh
# =============================================================
# Key differences from Kali script:
#   - Uses Docker CE from official repo (not docker.io)
#   - Wazuh installer does NOT need the -i (ignore check) flag
#   - ufw firewall rules added for dashboard access
# =============================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

banner() {
  echo -e "\n${CYAN}${BOLD}===========================================${NC}"
  echo -e "${CYAN}${BOLD}  VulnBank SIEM Lab — Ubuntu Server Setup  ${NC}"
  echo -e "${CYAN}${BOLD}===========================================${NC}\n"
}

step() { echo -e "\n${YELLOW}[${1}/${TOTAL_STEPS}] ${2}...${NC}"; }
ok()   { echo -e "${GREEN}  ✓ ${1}${NC}"; }
info() { echo -e "  → ${1}"; }
err()  { echo -e "${RED}  ✗ ${1}${NC}"; exit 1; }

TOTAL_STEPS=7

[[ $EUID -ne 0 ]] && err "Run as root: sudo ./scripts/setup-ubuntu.sh"

banner

# --- Step 1: System update ---
step 1 "Updating system packages"
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y ca-certificates curl gnupg lsb-release git nano net-tools > /dev/null
ok "System updated"

# --- Step 2: Docker CE (official repo — more up-to-date than docker.io) ---
step 2 "Installing Docker CE from official repository"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -qq
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin > /dev/null
systemctl enable --now docker

ok "Docker $(docker --version | awk '{print $3}' | tr -d ',') installed"

# Create a docker-compose shim so the old "docker-compose" command still works
if ! command -v docker-compose &>/dev/null; then
  ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose 2>/dev/null || true
fi

# --- Step 3: VulnBank ---
step 3 "Deploying VulnBank"
if [ -d /opt/vuln-bank ]; then
  info "Existing deployment found — pulling latest"
  cd /opt/vuln-bank && git pull -q
else
  git clone -q https://github.com/Commando-X/vuln-bank.git /opt/vuln-bank
fi
cd /opt/vuln-bank
docker-compose up --build -d
sleep 5

if curl -s -o /dev/null -w "%{http_code}" http://localhost:5000 | grep -q "200\|302"; then
  ok "VulnBank running at http://localhost:5000"
else
  echo -e "${YELLOW}  ⚠ VulnBank may still be starting — check with: docker ps${NC}"
fi

# --- Step 4: Wazuh ---
step 4 "Downloading Wazuh installer"
cd /tmp
curl -sO https://packages.wazuh.com/4.x/wazuh-install.sh
chmod +x wazuh-install.sh
ok "Installer ready"

step 5 "Installing Wazuh (20–30 min ☕)"
info "Ubuntu is officially supported — no -i flag needed"
bash wazuh-install.sh -a 2>&1 | tee /tmp/wazuh-install.log

WAZUH_PASSWORD=$(grep -oP "(?<=Password: ).*" /tmp/wazuh-install.log | tail -1 || true)
if [ -z "$WAZUH_PASSWORD" ]; then
  echo -e "${YELLOW}  ⚠ Could not auto-capture password — scroll up and save it.${NC}"
else
  echo "$WAZUH_PASSWORD" > /root/wazuh_admin_password.txt
  chmod 600 /root/wazuh_admin_password.txt
  ok "Password saved to /root/wazuh_admin_password.txt"
fi
ok "Wazuh installed"

# --- Step 6: Log collection ---
step 6 "Configuring Wazuh Docker log monitoring"
OSSEC_CONF="/var/ossec/etc/ossec.conf"

if ! grep -q "docker/containers" "$OSSEC_CONF"; then
  cp "$OSSEC_CONF" "${OSSEC_CONF}.bak"
  sed -i 's|</ossec_config>|  <localfile>\n    <log_format>syslog</log_format>\n    <location>/var/lib/docker/containers/*/*.log</location>\n  </localfile>\n\n</ossec_config>|' "$OSSEC_CONF"
  ok "Docker log path added to ossec.conf"
else
  ok "Already configured"
fi

systemctl restart wazuh-agent 2>/dev/null || true

# --- Step 7: Rules + firewall ---
step 7 "Installing detection rules and configuring firewall"

cat > /var/ossec/etc/rules/local_rules.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<group name="local,vulnbank,">

  <rule id="100001" level="10">
    <decoded_as>web-accesslog</decoded_as>
    <regex>(%27|%22|\bOR\b|\bAND\b|\bSELECT\b|\bUNION\b|\bDROP\b)</regex>
    <description>SQL injection pattern detected in web request</description>
    <group>attack,sql_injection,</group>
    <mitre><id>T1190</id></mitre>
  </rule>

  <rule id="100002" level="10">
    <decoded_as>web-accesslog</decoded_as>
    <regex>(&lt;script|javascript:|onerror=|onload=|alert\()</regex>
    <description>XSS payload detected in web request</description>
    <group>attack,xss,</group>
    <mitre><id>T1059.007</id></mitre>
  </rule>

  <rule id="100004" level="3">
    <decoded_as>json</decoded_as>
    <field name="status">failed|error|invalid</field>
    <description>VulnBank: failed login attempt</description>
    <group>authentication_failed,</group>
  </rule>

  <rule id="100003" level="10" frequency="10" timeframe="120">
    <if_matched_sid>100004</if_matched_sid>
    <same_source_ip />
    <description>Brute force: 10+ failed logins in 2 minutes</description>
    <group>attack,brute_force,</group>
    <mitre><id>T1110</id></mitre>
  </rule>

  <rule id="100005" level="10">
    <decoded_as>web-accesslog</decoded_as>
    <regex>(\.\.\/|\.\.\\|%2e%2e%2f)</regex>
    <description>Directory traversal attempt detected</description>
    <group>attack,path_traversal,</group>
    <mitre><id>T1083</id></mitre>
  </rule>

</group>
EOF

systemctl restart wazuh-manager

# Open firewall for dashboard (Ubuntu has ufw)
if command -v ufw &>/dev/null; then
  ufw allow 443/tcp comment "Wazuh dashboard" 2>/dev/null || true
  ufw allow 5000/tcp comment "VulnBank" 2>/dev/null || true
  ok "ufw rules added (443, 5000)"
fi

ok "Detection rules installed"

# --- Summary ---
SERVER_IP=$(hostname -I | awk '{print $1}')
echo -e "\n${GREEN}${BOLD}============================================${NC}"
echo -e "${GREEN}${BOLD}  ✓ Installation Complete!                  ${NC}"
echo -e "${GREEN}${BOLD}============================================${NC}"
echo
echo -e "  📊 Wazuh Dashboard : ${YELLOW}https://localhost${NC} or ${YELLOW}https://${SERVER_IP}${NC}"
echo -e "  🔑 Username        : ${YELLOW}admin${NC}"
echo -e "  🔐 Password        : ${YELLOW}${WAZUH_PASSWORD:-'(see /root/wazuh_admin_password.txt)'}${NC}"
echo -e "  💳 VulnBank App    : ${YELLOW}http://localhost:5000${NC} or ${YELLOW}http://${SERVER_IP}:5000${NC}"
echo
echo -e "${CYAN}Next steps:${NC}"
echo "  1. Browse to https://localhost (accept the self-signed cert)"
echo "  2. Log in with admin credentials above"
echo "  3. Run attacks: sudo ./scripts/attack-simulator.sh all"
echo
