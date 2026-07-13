# Server Utils
## Debian onboarding
For onboarding Debian servers (works on AMD64 and ARM64). Performs the following:
- Updates and installs packages
- Sets timezone
- Disables wireless interfaces on Raspberry Pis
- Sets up MOTD
- Installs Docker
- Installs Komodo Periphery
```
curl -fsSL https://raw.githubusercontent.com/sloraris/server-utils/refs/heads/main/debian-config.sh | sudo bash
```
