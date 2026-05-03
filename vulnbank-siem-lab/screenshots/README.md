# Screenshots

Add real screenshots from your lab here after running the setup.

## Required screenshots (for README table)

| File | What to capture |
|------|----------------|
| `dashboard-overview.png` | The main Wazuh Security Events dashboard with events visible |
| `sql-injection-alert.png` | A rule 100001 alert expanded, showing the payload in the log fields |
| `brute-force-detection.png` | Rule 100003 firing, ideally with the timeline showing the 10 base alerts before it |
| `agent-connected.png` | Wazuh Agents screen showing the agent status as Active |

## Tips for good screenshots

- Use full-screen Firefox, not a small window
- Expand at least one alert so the payload and rule details are visible
- Include the timestamp so it's clear these are from a real run
- Redact any real credentials visible on screen

## How to take them on Kali

```bash
# Install flameshot if not present
sudo apt install -y flameshot

# Launch and capture a region
flameshot gui
```

Then save directly to this folder.
