# 🔧 Installation Guide

## Platform Support

| Distribution | Version | Script | Notes |
|-------------|---------|--------|-------|
| Kali Linux | 2024.1+ | `setup-kali.sh` | Requires `-i` flag on Wazuh installer |
| Ubuntu Server | 22.04 LTS | `setup-ubuntu.sh` | Officially supported, no extra flags |
| Ubuntu Server | 24.04 LTS | `setup-ubuntu.sh` | Officially supported |
| Debian | 11 / 12 | Manual | Minor package name differences |

---

## Method 1: Automated Script (Recommended)

### Kali Linux

```bash
git clone https://github.com/yourusername/vulnbank-siem-lab.git
cd vulnbank-siem-lab
chmod +x scripts/setup-kali.sh
sudo ./scripts/setup-kali.sh
```

### Ubuntu Server

```bash
git clone https://github.com/yourusername/vulnbank-siem-lab.git
cd vulnbank-siem-lab
chmod +x scripts/setup-ubuntu.sh
sudo ./scripts/setup-ubuntu.sh
```

Both scripts:
- Install Docker
- Clone and start VulnBank
- Download and run the Wazuh all-in-one installer
- Configure Docker log collection in `ossec.conf`
- Deploy custom detection rules
- Save the Wazuh admin password to `/root/wazuh_admin_password.txt`

---

## Method 2: Manual Installation

### Phase 1 — Deploy VulnBank

**Install Docker**

```bash
# Kali / Debian / Ubuntu
sudo apt update && sudo apt install -y docker.io docker-compose
sudo systemctl enable --now docker

# Verify
docker --version
docker-compose --version
```

> Ubuntu Server users: for a newer Docker version use the official CE repo.
> See `scripts/setup-ubuntu.sh` for the exact commands.

**Deploy VulnBank**

```bash
git clone https://github.com/Commando-X/vuln-bank.git
cd vuln-bank
docker-compose up --build -d

# Confirm it is running
docker ps
curl -I http://localhost:5000   # expect 200 OK
```

---

### Phase 2 — Install Wazuh

```bash
curl -sO https://packages.wazuh.com/4.x/wazuh-install.sh

# Ubuntu / Debian — standard install
sudo bash wazuh-install.sh -a

# Kali Linux — add -i to bypass the system compatibility check
sudo bash wazuh-install.sh -a -i
```

> ⏱️ This takes **20–30 minutes**. At the end the terminal prints an admin password — **copy it immediately**.

---

### Phase 3 — Configure Log Collection

Find out which path Docker is using for container logs:

```bash
docker ps                         # note the container ID
docker inspect <id> | grep LogPath
```

It is almost always `/var/lib/docker/containers/<id>/<id>-json.log`.

Edit the Wazuh agent config:

```bash
sudo nano /var/ossec/etc/ossec.conf
```

Add this block anywhere inside `<ossec_config>`:

```xml
<localfile>
  <log_format>syslog</log_format>
  <location>/var/lib/docker/containers/*/*.log</location>
</localfile>
```

Restart the agent:

```bash
sudo systemctl restart wazuh-agent
```

---

### Phase 4 — Install Custom Rules

Copy the rules file from this repo:

```bash
sudo cp rules/local_rules.xml /var/ossec/etc/rules/local_rules.xml
sudo systemctl restart wazuh-manager
```

---

### Phase 5 — Access the Dashboard

1. Open a browser and go to `https://localhost`
2. Click **Advanced → Accept the Risk** (self-signed certificate — normal)
3. Log in: username `admin`, password from the installation output
4. Navigate to **Discover** to confirm VulnBank logs are flowing

---

## Platform Differences — Kali vs Ubuntu

| Item | Kali Linux | Ubuntu Server |
|------|-----------|---------------|
| Wazuh installer flag | `-a -i` | `-a` |
| Docker package | `docker.io` | Docker CE (official repo) |
| Firewall | None by default | `ufw` — script adds rules |
| Dashboard access | Browser on same machine | Browser on host or via IP |
| System check | Fails without `-i` | Passes out of the box |

---

## Post-Installation Checklist

- [ ] `http://localhost:5000` shows the VulnBank login page
- [ ] `https://localhost` shows the Wazuh dashboard
- [ ] Wazuh dashboard login works with `admin` credentials
- [ ] **Agents** section shows at least one connected agent
- [ ] **Discover** shows recent events from VulnBank

---

## Low-Resource Systems (less than 4 GB RAM)

Wazuh's indexer is the heaviest component. Reduce its heap:

```bash
sudo mkdir -p /etc/systemd/system/wazuh-indexer.service.d
sudo tee /etc/systemd/system/wazuh-indexer.service.d/memory.conf <<EOF
[Service]
Environment="ES_JAVA_OPTS=-Xms512m -Xmx512m"
EOF

sudo systemctl daemon-reload
sudo systemctl restart wazuh-indexer
```

---

## Uninstalling

```bash
# Remove VulnBank
cd /opt/vuln-bank
sudo docker-compose down -v
sudo docker system prune -a -f

# Remove Wazuh
cd /tmp
sudo bash wazuh-install.sh -u

# Or use the reset script
sudo ./scripts/reset-lab.sh --full
```

---

*Next: [Attack Simulation →](attack-simulation.md)*
