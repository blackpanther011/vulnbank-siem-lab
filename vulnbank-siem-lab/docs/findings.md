# 📋 Findings Log

This document records what was done during each lab run, what Wazuh detected, and what the real-world analyst response would be. Keeping this kind of log is standard practice in a SOC and turns a "I set up a tool" project into evidence of analytical thinking.

---

## How to Use This File

After running each attack scenario, fill in a new entry below using the template. Be specific — copy the actual alert data from Wazuh, not what you expected to see.

```
## Finding: [Attack name]
Date: YYYY-MM-DD
Environment: Kali / Ubuntu

### What I did
[Describe the attack — tool used, payload, target endpoint]

### What Wazuh detected
Rule ID:
Rule level:
Alert description:
Source IP:
Payload / log field visible in alert:

### Was the rule tuning needed?
[Did the rule fire as written, or did you have to change it? What did you change and why?]

### Real-world response
[What would a SOC analyst do with this alert? Steps 1, 2, 3.]

### Screenshot
[Link to screenshots/filename.png]
```

---

## Findings

<!-- ─────────────────────────────────────────────── -->
<!-- Replace the entries below with your own results -->
<!-- ─────────────────────────────────────────────── -->

---

## Finding: SQL Injection — Login Bypass

**Date:** [fill in]
**Environment:** Kali Linux

### What I did

Sent the payload `' OR '1'='1` in the username field of `http://localhost:5000/login` using both the browser and curl. Also ran `attack-simulator.sh sql-injection` which sent 7 different SQL injection variants.

### What Wazuh detected

- **Rule ID:** 100001
- **Rule level:** 10 (HIGH)
- **Description:** SQL injection pattern detected in web request
- **Source IP:** 127.0.0.1
- **Payload visible in alert:** [copy from Wazuh here]
- **MITRE technique:** T1190

### Was rule tuning needed?

[Note here whether rule 100001 fired on the first attempt, or if you had to adjust the regex.]

### Real-world response

1. Identify whether the login succeeded (check for a session token in subsequent requests)
2. If the login succeeded → critical incident; revoke sessions, lock the account, notify the app team
3. If the login failed → attempted attack; block the source IP, log for trend analysis
4. Review the application code for the vulnerable query and raise a patch ticket

### Screenshot

`screenshots/sql-injection-alert.png`

---

## Finding: Brute Force Attack

**Date:** [fill in]
**Environment:** Kali Linux

### What I did

Sent 12 rapid failed login attempts using a curl loop targeting the `admin` account. Attempts were 300 ms apart.

### What Wazuh detected

- **Rule ID (base):** 100004 — fired on each individual failure
- **Rule ID (threshold):** 100003 — fired after the 10th failure
- **Rule level:** 10 (HIGH)
- **Description:** Brute force: 10+ failed logins in 2 minutes from same IP
- **Source IP:** 127.0.0.1
- **MITRE technique:** T1110

### Was rule tuning needed?

[Note here whether the base rule 100004 correctly matched VulnBank's JSON log format. If not, describe what the actual log format was and what you changed the `<field>` match to.]

### Real-world response

1. Immediately lock the targeted account (admin) for 30 minutes
2. Block the source IP at the web application firewall
3. Alert the account owner that an attempted compromise occurred
4. Check authentication logs for the 10–15 minutes before the threshold fired to see if the attacker succeeded before the alert triggered
5. Investigate whether the same IP targeted other accounts

### Screenshot

`screenshots/brute-force-detection.png`

---

## Finding: XSS Payload Injection

**Date:** [fill in]
**Environment:** Kali Linux

### What I did

[Fill in]

### What Wazuh detected

- **Rule ID:** 100002
- **Rule level:** [fill in]
- **Payload visible:** [fill in]

### Was rule tuning needed?

[Fill in]

### Real-world response

[Fill in]

---

## Finding: Directory Traversal

**Date:** [fill in]
**Environment:** Kali Linux

### What I did

[Fill in]

### What Wazuh detected

[Fill in]

### Real-world response

[Fill in]

---

## Summary Table

| Attack | Rule ID | Level | Fired? | Tuning Required? |
|--------|---------|-------|--------|-----------------|
| SQL Injection | 100001 | 10 | | |
| XSS | 100002 | 10 | | |
| Brute Force (threshold) | 100003 | 10 | | |
| Failed Login (base) | 100004 | 3 | | |
| Path Traversal | 100005 | 10 | | |

---

*Keep this file updated as you expand the lab. Each new finding you document makes this a stronger portfolio piece.*
