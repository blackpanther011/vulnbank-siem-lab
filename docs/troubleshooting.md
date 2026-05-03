# 🔧 Troubleshooting

Common issues and their fixes. If your problem is not listed here, open a GitHub Issue.

---

## VulnBank

### VulnBank not accessible at http://localhost:5000

```bash
# Check if the container is running
docker ps

# If the container is not listed, start it
cd /opt/vuln-bank && docker-compose up -d

# If it appears but keeps restarting, check the logs
docker logs $(docker ps -aq --filter "name=vuln") --tail 30
```

### Port 5000 already in use

```bash
# Find what is using port 5000
sudo lsof -i :5000

# Stop that process, then restart VulnBank
docker-compose down && docker-compose up -d
```

### VulnBank container exits immediately

```bash
# Check build errors
cd /opt/vuln-bank
docker-compose up --build    # without -d so you see the output
```

This usually means a missing dependency in the Docker image. Make sure you have internet access and try rebuilding.

---

## Wazuh Installation

### Wazuh installer fails on Kali Linux

The installer checks for supported operating systems. Kali is not on the official list.

```bash
# Always use the -i (ignore) flag on Kali
sudo bash wazuh-install.sh -a -i
```

### Installation hangs at "Starting Wazuh indexer"

The indexer needs at least 2 GB of RAM just for itself. If your VM has less than 4 GB total, it may time out.

```bash
# Check available memory
free -h

# Reduce indexer heap (set before installing, or after if indexer is installed)
sudo mkdir -p /etc/systemd/system/wazuh-indexer.service.d
sudo tee /etc/systemd/system/wazuh-indexer.service.d/memory.conf <<EOF
[Service]
Environment="ES_JAVA_OPTS=-Xms512m -Xmx512m"
EOF

sudo systemctl daemon-reload
sudo systemctl restart wazuh-indexer
```

### I forgot to copy the admin password

```bash
# It was saved by the setup script
cat /root/wazuh_admin_password.txt

# If you ran the installer manually and it is not there, reset it
sudo /usr/share/wazuh-indexer/plugins/opensearch-security/tools/wazuh-passwords-tool.sh -u admin -p 'NewPassword123!'
```

---

## Wazuh Dashboard

### Dashboard shows "Could not connect to Wazuh API"

```bash
# Check all Wazuh services are running
sudo systemctl status wazuh-manager wazuh-indexer wazuh-dashboard

# Restart in order
sudo systemctl restart wazuh-indexer
sleep 30
sudo systemctl restart wazuh-manager
sudo systemctl restart wazuh-dashboard
```

### SSL certificate warning in browser

This is expected. Wazuh uses a self-signed certificate by default.

- Chrome / Edge: Click **Advanced** → **Proceed to localhost**
- Firefox: Click **Advanced** → **Accept the Risk and Continue**

This is safe for a local lab. Do not install this certificate in a production environment.

### Dashboard loads but shows no events

```bash
# Check the agent is connected
sudo /var/ossec/bin/agent_control -l

# Generate a test alert manually
sudo /var/ossec/bin/wazuh-logtest
# Paste this line and press Enter:
# Dec 25 20:45:02 MyHost sshd[1234]: Failed password for admin from 192.168.1.100 port 22
```

---

## Log Collection

### VulnBank logs not appearing in Wazuh Discover

**Step 1:** Confirm Docker logs exist at the expected path.

```bash
docker ps   # get the container ID
ls /var/lib/docker/containers/   # should show one or more directories
ls /var/lib/docker/containers/<id>/   # should show a *-json.log file
```

**Step 2:** Confirm the path is in `ossec.conf`.

```bash
grep -A3 "docker" /var/ossec/etc/ossec.conf
```

If you see nothing, add the localfile block manually:

```bash
sudo nano /var/ossec/etc/ossec.conf
```

Add inside `<ossec_config>`:

```xml
<localfile>
  <log_format>syslog</log_format>
  <location>/var/lib/docker/containers/*/*.log</location>
</localfile>
```

**Step 3:** Fix permissions if needed.

```bash
sudo chmod 755 /var/lib/docker/containers
sudo chmod 644 /var/lib/docker/containers/*/*.log
sudo systemctl restart wazuh-agent
```

**Step 4:** Tail the Wazuh agent log to see if it is reading anything.

```bash
sudo tail -f /var/ossec/logs/ossec.log | grep -i "docker\|vuln\|container"
```

---

## Custom Rules

### My custom rule is not firing

```bash
# Test the rule syntax — Wazuh will report errors here
sudo /var/ossec/bin/wazuh-analysisd -t

# Use the log testing tool to simulate a log line
sudo /var/ossec/bin/wazuh-logtest
```

Paste a sample log line from VulnBank. The tool tells you which decoder parsed it and which rules matched.

### Rule 100004 (failed login) not matching

The rule uses `<decoded_as>json</decoded_as>` which means the log line must be valid JSON. Check what VulnBank actually outputs:

```bash
docker logs $(docker ps -q --filter name=vuln) 2>&1 | tail -30
```

If the log is plain text (not JSON), change the rule to use `<match>` instead of `<field>`:

```xml
<rule id="100004" level="3">
  <match>failed|invalid password|authentication failed</match>
  <description>VulnBank: failed login attempt</description>
</rule>
```

---

## Quick Reset

If things are badly broken and you want to start fresh:

```bash
sudo ./scripts/reset-lab.sh          # removes VulnBank only
sudo ./scripts/reset-lab.sh --full   # removes VulnBank AND Wazuh
```

Then re-run the setup script.

---

*Still stuck? Open a GitHub Issue with: the error message, OS version, and the output of `sudo systemctl status wazuh-manager`.*
