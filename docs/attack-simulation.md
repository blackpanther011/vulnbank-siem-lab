# 🎮 Attack Simulation Guide

This guide walks through each attack scenario manually and explains what Wazuh should detect at each step.

> **Before you start:** make sure VulnBank is running (`docker ps`) and you can see events in Wazuh Dashboard → Discover.

---

## Scenario 1 — SQL Injection

**Goal:** Bypass authentication using SQL injection. Wazuh detects rule 100001 (level 10).

### What is SQL injection?

SQL injection exploits web forms that pass user input directly into a database query without sanitisation. The classic payload `' OR '1'='1` turns a login query into one that is always true, granting access without a valid password.

### Manual steps

1. Open `http://localhost:5000` in Firefox.
2. In the **Username** field enter: `' OR '1'='1`
3. In the **Password** field enter anything.
4. Click **Login**.

**Or run it with curl:**

```bash
curl -X POST http://localhost:5000/login \
  -d "username=' OR '1'='1&password=test"
```

**Or use the simulator:**

```bash
sudo ./scripts/attack-simulator.sh sql-injection
```

### What to look for in Wazuh

1. Go to **Discover** (left sidebar)
2. Search: `rule.id:100001`
3. You should see an alert with:
   - Rule level: 10
   - Description: *SQL injection pattern detected in web request*
   - The payload visible in the `data.url` or `full_log` field
   - MITRE technique: T1190

### Real-world response

A SOC analyst seeing this alert would:
1. Check the source IP and determine if it is internal or external
2. Review adjacent log entries for reconnaissance activity
3. Confirm whether the login succeeded (if yes → incident; if no → attempted attack)
4. Block the source IP at the firewall and open an incident ticket

---

## Scenario 2 — Brute Force Login

**Goal:** Try many passwords rapidly. Wazuh detects rule 100003 (level 10) after the threshold is crossed.

### Manual steps (curl loop)

```bash
for i in $(seq 1 15); do
  curl -s -X POST http://localhost:5000/login \
    -d "username=admin&password=wrongpass${i}" > /dev/null
  echo "Attempt $i sent"
  sleep 0.3
done
```

### Automated with Hydra

```bash
# Install if needed
sudo apt install -y hydra

hydra -l admin -P /usr/share/wordlists/rockyou.txt \
  localhost http-post-form \
  "/login:username=^USER^&password=^PASS^:Invalid" \
  -t 4 -V
```

**Or use the simulator:**

```bash
sudo ./scripts/attack-simulator.sh brute-force
```

### What to look for in Wazuh

1. Search: `rule.id:100003`
2. The alert fires after the **10th failed login within a 2-minute window** from the same IP.
3. You will also see the base rule (100004) firing for each individual failure before the threshold is reached.

### Real-world response

- Lock the targeted account temporarily
- Block the source IP at the WAF
- Notify the account owner of the attempted compromise
- Check if the attacker succeeded before triggering the threshold

---

## Scenario 3 — Cross-Site Scripting (XSS)

**Goal:** Inject a script payload into a form field. Wazuh detects rule 100002 (level 10).

### Manual steps

1. Go to `http://localhost:5000`
2. In the **Username** field enter: `<script>alert(1)</script>`
3. Submit the form

**Or with curl:**

```bash
curl -X POST http://localhost:5000/login \
  -d 'username=<script>alert(document.cookie)</script>&password=test'
```

**Or use the simulator:**

```bash
sudo ./scripts/attack-simulator.sh xss
```

### What to look for in Wazuh

1. Search: `rule.id:100002`
2. Alert level 10, description *XSS payload detected*
3. The raw `<script>` tag should be visible in the log data

---

## Scenario 4 — Directory Traversal

**Goal:** Try to access files outside the web root. Wazuh detects rule 100005 (level 10).

### Manual steps

```bash
# Clear-text traversal
curl http://localhost:5000/../../../etc/passwd

# URL-encoded
curl "http://localhost:5000/%2e%2e%2f%2e%2e%2fetc%2fpasswd"

# Double-encoded
curl "http://localhost:5000/%252e%252e%252fetc%252fpasswd"
```

**Or use the simulator:**

```bash
sudo ./scripts/attack-simulator.sh traversal
```

---

## Scenario 5 — Full Attack Chain

Run all scenarios back-to-back to generate a realistic burst of alerts:

```bash
sudo ./scripts/attack-simulator.sh all
```

Then in Wazuh:
1. Go to **Security Events**
2. Set time range to **Last 15 minutes**
3. You should see alerts across multiple rule IDs and severity levels
4. Use the MITRE ATT&CK tab to see the techniques mapped

---

## Verifying Rule Logic

If an expected alert does not appear, debug the rule:

```bash
# Check what VulnBank's actual log output looks like
docker logs $(docker ps -q --filter "ancestor=vuln-bank") --tail 20

# Check that Wazuh received any logs at all
sudo tail -f /var/ossec/logs/ossec.log | grep -i "vuln\|docker"

# Test a rule against a sample log line
sudo /var/ossec/bin/wazuh-logtest
# Then paste a log line and press Enter
```

---

## Rule Tuning Notes

The brute force rule (100003) uses rule 100004 as its base. Rule 100004 looks for `"status": "failed"` in JSON logs. If VulnBank uses a different key (e.g. `"result": "error"` or `"message": "Invalid credentials"`), you must update the `<field>` match in `local_rules.xml`.

**To find the actual format:**

```bash
docker logs $(docker ps -q --filter name=vuln) 2>&1 | grep -i "fail\|error\|invalid" | tail -10
```

Document what you find in [findings.md](findings.md) — showing that you tuned a rule against real data is strong portfolio evidence.

---

*Next: [Detection Rules →](detection-rules.md)*
