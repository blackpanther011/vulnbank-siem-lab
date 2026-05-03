# 🏗️ Architecture

## Overview

The entire lab runs inside a **single VM**. This keeps resource requirements low and removes the need for network configuration between machines while still producing realistic log data and alerts.

```
┌──────────────────────────────────────────────────────────────────────┐
│                     Kali / Ubuntu VM                                  │
│                                                                       │
│  ┌──────────────────┐          ┌─────────────────────────────────┐   │
│  │   VulnBank       │  stdout/ │        Wazuh (All-in-One)       │   │
│  │   (Docker)       │──stderr─►│                                 │   │
│  │                  │          │  ┌───────────┐  ┌────────────┐  │   │
│  │  Python Flask    │          │  │  Manager  │  │  Indexer   │  │   │
│  │  Port 5000       │          │  │ (rules +  │  │ (storage)  │  │   │
│  └──────────────────┘          │  │  alerts)  │  └────────────┘  │   │
│                                │  └─────┬─────┘                  │   │
│  ┌──────────────────┐          │        │       ┌─────────────┐  │   │
│  │  Attack Tools    │          │        └──────►│  Dashboard  │  │   │
│  │                  │──HTTP──► │                │  Port 443   │  │   │
│  │  SQLmap, Hydra,  │  attacks │                └─────────────┘  │   │
│  │  curl, browser   │          └─────────────────────────────────┘   │
│  └──────────────────┘                                                 │
│                                                                       │
│  Log flow: Docker → /var/lib/docker/containers/*/*.log                │
│            Wazuh agent tails this path → Manager → Indexer            │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Components

### VulnBank

- **What it is:** An intentionally vulnerable Python/Flask banking application running in Docker.
- **Why it exists:** Gives the SIEM something real to monitor. VulnBank accepts logins, processes transfers, and exposes common web vulnerabilities (SQLi, XSS, IDOR, broken auth).
- **Log output:** Application logs stream to stdout/stderr, which Docker captures at `/var/lib/docker/containers/<id>/<id>-json.log`.

### Wazuh (All-in-One)

Wazuh is deployed with all three components on the same host:

| Component | Role |
|-----------|------|
| **Wazuh Manager** | Receives logs from the agent, runs them through the rules engine, generates alerts |
| **Wazuh Indexer** | OpenSearch-based storage for alerts and events |
| **Wazuh Dashboard** | Kibana-based web UI for searching events, viewing alerts, and visualising trends |
| **Wazuh Agent** | Runs on the same host; tails log files and forwards data to the Manager |

### Attack Tools

All attack tools are already present in Kali Linux. On Ubuntu you may need to install some:

```bash
sudo apt install -y hydra sqlmap curl
```

---

## Log Flow (step by step)

```
1. User or script sends HTTP request to VulnBank (:5000)
   ↓
2. Flask processes the request and writes to stdout/stderr
   ↓
3. Docker captures stdout/stderr to:
   /var/lib/docker/containers/<id>/<id>-json.log
   ↓
4. Wazuh agent tails that path (configured in ossec.conf)
   ↓
5. Agent sends log line to Wazuh Manager over port 1514
   ↓
6. Manager decodes the log and runs it against all active rules
   ↓
7. If a rule matches, an alert is created and written to:
   /var/ossec/logs/alerts/alerts.json
   ↓
8. Alert is forwarded to the Indexer for storage
   ↓
9. Alert appears in the Dashboard under Security Events / Discover
```

---

## Ports Reference

| Port | Service | Protocol |
|------|---------|----------|
| 5000 | VulnBank application | HTTP |
| 443 | Wazuh Dashboard | HTTPS |
| 9200 | Wazuh Indexer API | HTTPS (internal) |
| 55000 | Wazuh Manager API | HTTPS (internal) |
| 1514 | Agent–Manager communication | UDP/TCP |
| 1515 | Agent registration | TCP |

---

## Why a Single VM?

Most home lab guides use multiple VMs (an attacker VM, a target VM, a SIEM VM). This lab deliberately runs everything on one machine to:

- Keep hardware requirements low (4 GB RAM minimum vs 8–12 GB for multi-VM)
- Eliminate network configuration complexity
- Let beginners focus on the security concepts, not the infrastructure
- Still produce realistic, real log data — the attacks are real HTTP requests, not simulated events

When you move to a dedicated Ubuntu Server, you can split this into separate VMs with no changes to the application or Wazuh config — just update the agent's `<server>` address in `ossec.conf`.

---

*Next: [Installation Guide →](installation-guide.md)*
