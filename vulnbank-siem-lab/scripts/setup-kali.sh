#!/bin/bash
# =============================================================
# VulnBank SIEM Lab — Automated Setup Script for Kali Linux
# =============================================================
# Usage: sudo ./scripts/setup-kali.sh
# =============================================================

set -euo pipefail

# --- Colours ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

banner() {
  echo -e "\n${CYAN}${BOLD}========================================${NC}"
  echo -e "${CYAN}${BOLD}  VulnBank SIEM Lab — Kali Linux Setup  ${NC}"
  echo -e "${CYAN}${BOLD}========================================${NC}\n"
}

step()    { echo -e "\n${YELLOW}[${1}/${TOTAL_STEPS}] ${2}...${NC}"; }
ok()      { echo -e "${GREEN}  ✓ ${1}${NC}"; }
info()    { echo -e "  → ${1}"; }
err()     { echo -e "${RED}  ✗ ${1}${NC}"; exit 1; }

TOTAL_STEPS=6

# --- Root check ---
[[ $EUID -ne 0 ]] && err "Run as root: sudo ./scripts/setup-kali.sh"

banner

# --- Step 1: Docker ---
step 1 "Installing Docker and dependencies"
apt-get update -qq
apt-get install -y docker.io docker-compose curl git nano net-tools > /dev/null
systemctl enable --now docker
ok "Docker $(docker --version | awk '{print $3}' | tr -d ',') installed"

# --- Step 2: VulnBank ---
step 2 "Deploying VulnBank (vulnerable banking app)"
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

# --- Step 3: Wazuh download ---
step 3 "Downloading Wazuh installer"
cd /tmp
curl -sO https://packages.wazuh.com/4.x/wazuh-install.sh
chmod +x wazuh-install.sh
ok "Wazuh installer downloaded"

# --- Step 4: Wazuh install ---
step 4 "Installing Wazuh all-in-one (20–30 min — go get a coffee ☕)"
info "The -i flag ignores Kali's non-standard system checks"
bash wazuh-install.sh -a -i 2>&1 | tee /tmp/wazuh-install.log

# Try to extract the admin password from the log
WAZUH_PASSWORD=$(grep -oP "(?<=Password: ).*" /tmp/wazuh-install.log | tail -1 || true)
if [ -z "$WAZUH_PASSWORD" ]; then
  echo -e "${YELLOW}  ⚠ Could not auto-capture password — scroll up and save it manually.${NC}"
else
  echo "$WAZUH_PASSWORD" > /root/wazuh_admin_password.txt
  chmod 600 /root/wazuh_admin_password.txt
  ok "Password saved to /root/wazuh_admin_password.txt"
fi

ok "Wazuh installed"

# --- Step 5: Log collection config ---
step 5 "Configuring Wazuh to monitor Docker container logs"
OSSEC_CONF="/var/ossec/etc/ossec.conf"

if ! grep -q "docker/containers" "$OSSEC_CONF"; then
  # Backup original
  cp "$OSSEC_CONF" "${OSSEC_CONF}.bak"

  # Inject Docker log localfile block before closing </ossec_config>
  sed -i 's|</ossec_config>|  <localfile>\n    <log_format>syslog</log_format>\n    <location>/var/lib/docker/containers/*/*.log</location>\n  </localfile>\n\n</ossec_config>|' "$OSSEC_CONF"
  ok "Docker log monitoring added to ossec.conf"
else
  ok "Docker log monitoring already configured"
fi

systemctl restart wazuh-agent 2>/dev/null || true

# --- Step 6: Custom detection rules ---
step 6 "Installing custom VulnBank detection rules"
cat > /var/ossec/etc/rules/local_rules.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!--
  VulnBank SIEM Lab — Custom Wazuh Rules
  Author: [Your Name]
  Last updated: 2026
-->
<group name="local,vulnbank,">

  <!-- ─────────────────────────────────────────────────────── -->
  <!-- SQL Injection Detection                                  -->
  <!-- Looks for common SQLi patterns in web request fields     -->
  <!-- ─────────────────────────────────────────────────────── -->
  <rule id="100001" level="10">
    <decoded_as>web-accesslog</decoded_as>
    <regex>(%27|%22|\bOR\b|\bAND\b|\bSELECT\b|\bUNION\b|\bDROP\b)</regex>
    <description>SQL injection pattern detected in web request</description>
    <group>attack,sql_injection,</group>
    <mitre>
      <id>T1190</id>
    </mitre>
  </rule>

  <!-- ─────────────────────────────────────────────────────── -->
  <!-- Cross-Site Scripting (XSS) Detection                     -->
  <!-- ─────────────────────────────────────────────────────── -->
  <rule id="100002" level="10">
    <decoded_as>web-accesslog</decoded_as>
    <regex>(&lt;script|javascript:|onerror=|onload=|alert\()</regex>
    <description>XSS payload detected in web request</description>
    <group>attack,xss,</group>
    <mitre>
      <id>T1059.007</id>
    </mitre>
  </rule>

  <!-- ─────────────────────────────────────────────────────── -->
  <!-- Failed Login — base rule (child rule counts these)       -->
  <!-- NOTE: Tune the field name to match VulnBank's actual     -->
  <!-- login response. Check docker logs to confirm format.     -->
  <!-- ─────────────────────────────────────────────────────── -->
  <rule id="100004" level="3">
    <decoded_as>json</decoded_as>
    <field name="status">failed|error|invalid</field>
    <description>VulnBank: failed login attempt</description>
    <group>authentication_failed,</group>
  </rule>

  <!-- ─────────────────────────────────────────────────────── -->
  <!-- Brute Force Detection                                    -->
  <!-- Fires when 100004 triggers 10+ times in 2 min from      -->
  <!-- the same source IP                                       -->
  <!-- ─────────────────────────────────────────────────────── -->
  <rule id="100003" level="10" frequency="10" timeframe="120">
    <if_matched_sid>100004</if_matched_sid>
    <same_source_ip />
    <description>Brute force attack detected: 10+ failed logins in 2 minutes</description>
    <group>attack,brute_force,authentication_failures,</group>
    <mitre>
      <id>T1110</id>
    </mitre>
  </rule>

  <!-- ─────────────────────────────────────────────────────── -->
  <!-- Directory Traversal Detection                            -->
  <!-- ─────────────────────────────────────────────────────── -->
  <rule id="100005" level="10">
    <decoded_as>web-accesslog</decoded_as>
    <regex>(\.\.\/|\.\.\\|%2e%2e%2f|%252e%252e)</regex>
    <description>Directory traversal attempt detected</description>
    <group>attack,path_traversal,</group>
    <mitre>
      <id>T1083</id>
    </mitre>
  </rule>

</group>
EOF

systemctl restart wazuh-manager

ok "Custom rules installed and Wazuh manager restarted"

# --- Final summary ---
echo -e "\n${GREEN}${BOLD}============================================${NC}"
echo -e "${GREEN}${BOLD}  ✓ Installation Complete!                  ${NC}"
echo -e "${GREEN}${BOLD}============================================${NC}"
echo
echo -e "  📊 Wazuh Dashboard : ${YELLOW}https://localhost${NC}"
echo -e "  🔑 Username        : ${YELLOW}admin${NC}"
echo -e "  🔐 Password        : ${YELLOW}${WAZUH_PASSWORD:-'(see scroll-up or /root/wazuh_admin_password.txt)'}${NC}"
echo -e "  💳 VulnBank App    : ${YELLOW}http://localhost:5000${NC}"
echo
echo -e "${CYAN}Next steps:${NC}"
echo "  1. Open Firefox → https://localhost"
echo "  2. Accept the self-signed certificate warning"
echo "  3. Log in with the credentials above"
echo "  4. Menu → Discover to see VulnBank events"
echo "  5. Run: sudo ./scripts/attack-simulator.sh all"
echo
