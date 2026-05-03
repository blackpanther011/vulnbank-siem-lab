# 🛡️ Detection Rules

Custom Wazuh rules written specifically for this lab. Source file: `rules/local_rules.xml`.

---

## Rule Summary

| Rule ID | Name | Level | Trigger |
|---------|------|-------|---------|
| 100001 | SQL Injection | 10 (HIGH) | SQL keywords or encoded chars in web request |
| 100002 | XSS | 10 (HIGH) | Script tags or JS event handlers in request |
| 100003 | Brute Force | 10 (HIGH) | 10+ rule-100004 alerts in 2 min, same IP |
| 100004 | Failed Login | 3 (INFO) | JSON `status` field contains failure keyword |
| 100005 | Path Traversal | 10 (HIGH) | `../` or URL-encoded equivalents in URL |

---

## Rule 100001 — SQL Injection

```xml
<rule id="100001" level="10">
  <decoded_as>web-accesslog</decoded_as>
  <regex>(%27|%22|\bOR\b|\bAND\b|\bSELECT\b|\bUNION\b|\bDROP\b)</regex>
  <description>SQL injection attempt detected in web request</description>
  <mitre><id>T1190</id></mitre>
</rule>
```

**Why level 10?** Wazuh's built-in scale runs 0–15. Level 10 is "high severity" — it shows up in the default Security Events dashboard and can trigger active responses. Level 7–9 is medium; 12+ is critical.

**What the regex matches:**

| Pattern | Meaning |
|---------|---------|
| `%27` | URL-encoded single quote `'` |
| `%22` | URL-encoded double quote `"` |
| `\bOR\b` | SQL `OR` keyword (word boundary prevents matching "word") |
| `UNION` | `UNION SELECT` is the classic column-extraction payload |
| `DROP` | Destructive SQL command |

**MITRE:** T1190 — Exploit Public-Facing Application (Initial Access tactic).

---

## Rule 100002 — Cross-Site Scripting

```xml
<rule id="100002" level="10">
  <decoded_as>web-accesslog</decoded_as>
  <regex>(&lt;script|javascript:|onerror=|onload=|alert\()</regex>
  <description>XSS payload detected in web request</description>
  <mitre><id>T1059.007</id></mitre>
</rule>
```

**Note:** In Wazuh XML, `<` must be written as `&lt;` to avoid breaking the XML structure. The regex is therefore `&lt;script` which matches the literal string `<script`.

**MITRE:** T1059.007 — JavaScript (Execution via scripting).

---

## Rules 100004 + 100003 — Failed Login and Brute Force

These two rules work together. Rule 100004 fires once per failed login. Rule 100003 is a **frequency-based** rule — it fires only when 100004 has triggered 10 or more times within a 120-second window from the same source IP.

```xml
<!-- Base rule — one event per failure -->
<rule id="100004" level="3">
  <decoded_as>json</decoded_as>
  <field name="status">failed|error|invalid|unauthorized</field>
  <description>VulnBank: single failed authentication attempt</description>
</rule>

<!-- Correlation rule — fires after threshold -->
<rule id="100003" level="10" frequency="10" timeframe="120">
  <if_matched_sid>100004</if_matched_sid>
  <same_source_ip />
  <description>Brute force: 10+ failed logins in 2 minutes from same IP</description>
  <mitre><id>T1110</id></mitre>
</rule>
```

**⚠️ Tuning required:** The `<field name="status">` match depends on VulnBank's JSON log format. Run the lab, check what a failed login actually logs, and update this pattern to match. See [attack-simulation.md](attack-simulation.md#rule-tuning-notes) for how to inspect the logs.

**MITRE:** T1110 — Brute Force (Credential Access tactic).

---

## Rule 100005 — Directory Traversal

```xml
<rule id="100005" level="10">
  <decoded_as>web-accesslog</decoded_as>
  <regex>(\.\.\/|\.\.\\|%2e%2e%2f|%252e%252e)</regex>
  <description>Directory traversal attempt detected</description>
  <mitre><id>T1083</id></mitre>
</rule>
```

**Patterns covered:**

| Pattern | Encoding |
|---------|----------|
| `../` | Clear-text |
| `..\` | Windows-style |
| `%2e%2e%2f` | Single URL-encoded |
| `%252e%252e` | Double URL-encoded (bypasses some filters) |

---

## MITRE ATT&CK Mapping

| Rule | Technique | Tactic |
|------|-----------|--------|
| 100001 | T1190 — Exploit Public-Facing Application | Initial Access |
| 100002 | T1059.007 — JavaScript | Execution |
| 100003 | T1110 — Brute Force | Credential Access |
| 100005 | T1083 — File and Directory Discovery | Discovery |

Wazuh automatically displays these mappings under the **MITRE ATT&CK** tab in the dashboard.

---

## Deploying or Updating Rules

```bash
# Copy to Wazuh rules directory
sudo cp rules/local_rules.xml /var/ossec/etc/rules/local_rules.xml

# Validate syntax before restarting
sudo /var/ossec/bin/wazuh-analysisd -t

# Apply changes
sudo systemctl restart wazuh-manager
```

---

## Writing New Rules — Quick Reference

```xml
<rule id="1XXXXX" level="N">
  <decoded_as>DECODER_NAME</decoded_as>
  <match>literal string to find</match>           <!-- OR use regex -->
  <regex>regular expression</regex>
  <field name="json_field">value_pattern</field>  <!-- for JSON logs -->
  <description>Human-readable description</description>
  <group>comma,separated,groups,</group>
  <mitre><id>TXXXX</id></mitre>
</rule>
```

**Level guide:**

| Level | Meaning |
|-------|---------|
| 0 | Ignored |
| 1–3 | Informational |
| 4–6 | Low |
| 7–9 | Medium |
| 10–11 | High |
| 12–14 | Critical |
| 15 | Maximum — triggers all active responses |

---

*Next: [Findings Log →](findings.md)*
