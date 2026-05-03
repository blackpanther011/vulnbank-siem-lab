# 🔐 VulnBank SIEM Lab — Wazuh Security Monitoring

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Wazuh](https://img.shields.io/badge/Wazuh-4.x-blue)](https://wazuh.com)
[![Kali Linux](https://img.shields.io/badge/Kali-Linux-557C94?logo=kalilinux&logoColor=white)](https://kali.org)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04%2F24.04-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![Docker](https://img.shields.io/badge/Docker-24.0+-2496ED?logo=docker&logoColor=white)](https://docker.com)
[![Platform](https://img.shields.io/badge/Platform-Kali%20%7C%20Ubuntu-brightgreen)]()

> **A hands-on blue team lab** — deploy a vulnerable banking app, monitor it with an enterprise SIEM, simulate real attacks, and watch the detections fire in real time.

---

## 📌 Table of Contents

- [Overview](#-overview)
- [Architecture](#-architecture)
- [Quick Start](#-quick-start)
- [Attack Scenarios](#-attack-scenarios)
- [Sample Detections](#-sample-detections)
- [Documentation](#-documentation)
- [Skills Demonstrated](#-skills-demonstrated)
- [Roadmap](#-roadmap)

---

## 🎯 Overview

This lab simulates a real-world SOC environment inside a single VM. It combines:

| Component | Role | Tech |
|-----------|------|------|
| **VulnBank** | Intentionally vulnerable target | Python / Docker |
| **Wazuh** | SIEM — log collection, correlation, alerting | Wazuh 4.x (all-in-one) |
| **Attack Tools** | Simulated attacker | SQLmap, Hydra, curl |

**What you get:**
- Real-time detection of OWASP Top 10 attacks
- Custom correlation rules tuned to VulnBank's log format
- Full end-to-end workflow from deployment → attack → alert → analysis

---

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                        Single VM (Kali / Ubuntu)                  │
│                                                                    │
│  ┌─────────────────┐    logs     ┌──────────────────────────────┐ │
│  │   VulnBank App  │ ──────────► │         Wazuh SIEM           │ │
│  │  (Docker :5000) │             │  ┌────────┐  ┌───────────┐  │ │
│  └─────────────────┘             │  │ Agent  │  │ Dashboard │  │ │
│                                  │  │        │  │  (:443)   │  │ │
│  ┌─────────────────┐             │  └────────┘  └───────────┘  │ │
│  │  Attack Tools   │ ──attacks─► │  ┌──────────────────────┐   │ │
│  │  (SQLmap, etc.) │             │  │  Custom Rules Engine  │   │ │
│  └─────────────────┘             │  └──────────────────────┘   │ │
│                                  └──────────────────────────────┘ │
│                                                                    │
│  Docker log path: /var/lib/docker/containers/*/*.log               │
└──────────────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start

### Prerequisites

- VM with **minimum 4 GB RAM, 30 GB disk**
- VMware Workstation / VirtualBox
- Kali Linux 2024.1+ **or** Ubuntu Server 22.04 / 24.04

### One-command setup

**Kali Linux**
```bash
git clone https://github.com/yourusername/vulnbank-siem-lab.git
cd vulnbank-siem-lab
chmod +x scripts/setup-kali.sh
sudo ./scripts/setup-kali.sh
```

**Ubuntu Server**
```bash
git clone https://github.com/yourusername/vulnbank-siem-lab.git
cd vulnbank-siem-lab
chmod +x scripts/setup-ubuntu.sh
sudo ./scripts/setup-ubuntu.sh
```

> ⏱️ Installation takes **20–30 minutes**. The script saves your Wazuh admin password to `/root/wazuh_admin_password.txt`.

### Access

| Service | URL | Credentials |
|---------|-----|-------------|
| Wazuh Dashboard | `https://localhost` | `admin` / *(saved by script)* |
| VulnBank App | `http://localhost:5000` | *(register on first use)* |

For step-by-step instructions, see the full [Installation Guide →](docs/installation-guide.md)

---

## 🎮 Attack Scenarios

Run the included simulator to generate real detections:

```bash
# SQL Injection
sudo ./scripts/attack-simulator.sh sql-injection

# Brute Force Login
sudo ./scripts/attack-simulator.sh brute-force

# XSS Injection
sudo ./scripts/attack-simulator.sh xss

# Full sequence
sudo ./scripts/attack-simulator.sh all
```

See [Attack Simulation Guide →](docs/attack-simulation.md) for manual walkthroughs and expected results.

---

## 📊 Sample Detections

### SQL Injection Alert
```json
{
  "timestamp": "2026-05-01T14:23:45Z",
  "rule": { "id": "100001", "level": 10, "description": "SQL injection pattern detected" },
  "data": {
    "srcip": "127.0.0.1",
    "url": "/login",
    "payload": "' OR '1'='1"
  },
  "mitre": { "technique": "T1190", "tactic": "Initial Access" }
}
```

### Detection Rules Included

| Rule ID | Attack Type | Severity | Trigger |
|---------|-------------|----------|---------|
| 100001 | SQL Injection | HIGH (10) | Pattern match in URL/body |
| 100002 | XSS | HIGH (10) | Script tags in request |
| 100003 | Brute Force | MEDIUM (7) | 10+ failures in 2 min |
| 100004 | Failed Login | INFO (3) | Single failed auth |

Full rule documentation: [Detection Rules →](docs/detection-rules.md)

---

## 📚 Documentation

| Doc | Contents |
|-----|----------|
| [Architecture](docs/architecture.md) | How all components connect |
| [Installation Guide](docs/installation-guide.md) | Kali + Ubuntu setup, platform comparison |
| [Attack Simulation](docs/attack-simulation.md) | Manual and automated attack walkthroughs |
| [Detection Rules](docs/detection-rules.md) | Custom Wazuh rules explained |
| [Findings Log](docs/findings.md) | What was detected and why it matters |
| [Troubleshooting](docs/troubleshooting.md) | Common issues and fixes |

---

## 🎯 Skills Demonstrated

| Domain | What This Lab Covers |
|--------|---------------------|
| **SIEM Engineering** | Wazuh all-in-one deployment, agent configuration, log pipeline |
| **Log Management** | Docker container log collection, JSON parsing, field extraction |
| **Detection Engineering** | Custom correlation rules, threshold-based alerting, MITRE mapping |
| **Offensive Security** | SQL injection, XSS, brute force — understanding attacker TTPs |
| **Security Analysis** | Alert triage, event investigation, finding root cause |
| **DevSecOps** | Containerised target app, scripted deployment, repeatable environments |

**Interview talking points:**
- *"I deployed an enterprise SIEM from scratch and configured it to ingest Docker container logs"*
- *"I wrote custom detection rules tuned to the app's specific log format — not just generic rules"*
- *"I documented what each attack produced, what Wazuh caught, and what the real-world response would be"*

---

## 🗺️ Roadmap

- [x] Wazuh all-in-one deployment (Kali)
- [x] VulnBank Docker integration
- [x] Custom detection rules (SQLi, XSS, brute force)
- [x] Automated setup scripts (Kali + Ubuntu)
- [x] Attack simulator script
- [ ] Add screenshots from live lab runs
- [ ] Suricata IDS for network-level detection
- [ ] TheHive integration for incident response
- [ ] Windows VM as a second monitored endpoint
- [ ] Wazuh File Integrity Monitoring (FIM) on VulnBank

---

## 📸 Screenshots

> *Screenshots coming once lab run is complete — see `screenshots/` folder.*

| View | Description |
|------|-------------|
| `dashboard-overview.png` | Main Wazuh security events dashboard |
| `sql-injection-alert.png` | SQL injection alert with payload visible |
| `brute-force-detection.png` | Brute force threshold alert |
| `agent-connected.png` | Wazuh agent successfully connected |

---

## 📝 License

MIT — feel free to fork and use for your own portfolio.

---

## 🙏 Acknowledgments

- [Wazuh](https://wazuh.com) — open-source SIEM platform
- [VulnBank by Commando-X](https://github.com/Commando-X/vuln-bank) — vulnerable banking application
- [Kali Linux](https://kali.org) — penetration testing distribution

---

*Built as a hands-on portfolio project to demonstrate blue team skills. Open an issue if you find a bug or want to suggest a new attack scenario.*
