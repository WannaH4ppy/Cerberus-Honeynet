# 🍯 Honeypot Command Center & REAL-OS Environment

A comprehensive, containerized research environment designed for real-time detection, isolation, and analysis of cyberattacks. This project integrates low and medium-interaction traps with a custom, high-interaction **REAL-OS** environment. It features advanced obfuscation mechanisms and instantaneous log export via a **Push Architecture**.

## System Architecture
The system relies on rigorous network segmentation (**Docker Networks**), dividing the infrastructure into two distinct zones:

### 1. DMZ Zone (172.25.0.0/24) – Attack Surface
* **REAL-OS:** A custom High-Interaction container (Ubuntu 22.04) featuring a fake web server, database, honeytokens (AWS/MySQL), and a hidden auditing system.
* **Cowrie:** A Medium-Interaction honeypot emulating SSH and Telnet services to capture brute-force attacks and shell interaction.
* **Dionaea:** A Low-Interaction honeypot designed to capture malware via protocols such as SMB, HTTP, and FTP.
* **Snort NIDS:** An Intrusion Detection System listening directly on the DMZ virtual bridge.

### 2. Management Zone (172.26.0.0/24)
* **Promtail & Loki:** Log aggregator and non-relational database for real-time telemetry.
* **Grafana:** Interactive dashboard mapping attack vectors to the global **MITRE ATT&CK** matrix.
* **Portainer:** Graphical user interface for container environment management.

---

## 🍯 Key Features & Security
* **Strict Network Containment:** Automatic injection of `iptables` rules into the `DOCKER-USER` chain from the host level. It enforces absolute blocking of escape attempts to private networks (RFC 1918) and provides DoS protection using the `limit` module (max 20 packets/s).
* **Advanced Stealth & Obfuscation:** The REAL-OS environment is engineered to delay detection by intruders:
    * **Process Mystification:** Masking the main process (PID 1) using `exec -a /sbin/init tail -f /dev/null`.
    * **Hidden Artifacts:** Tracking agents operate in-memory under the guise of `systemd-journald` and `systemd-udevd` processes.
    * **Immutable Keylogger:** An invisible shell-level keylogger based on hidden, `readonly` `PROMPT_COMMAND` variables.
* **Anti-Forensics Resilience (Push Architecture):** Container compromise does not result in evidence loss. Logs and captured malicious files are streamed in real-time to the isolated Loki database before an intruder can execute `rm -rf /var/log/`.
* **Semi-Automatic Rollback:** Rapid restoration of clean environments (Infrastructure as Code) managed entirely through an integrated **PowerShell Command Center**.
* **Hard Resource Limits:** Strict CPU and RAM allocation combined with Healthcheck mechanisms to prevent resource exhaustion crashes.

---

## 🍯 Installation & Deployment
### Prerequisites
* **Docker & Docker Compose**
* **Windows Subsystem for Linux (WSL2)** – recommended for `.wslconfig` environment tuning.
* **PowerShell 5.1+**

### Startup Procedure
The entire lifecycle of the environment is managed by the custom `Honeypot-Control.ps1` PowerShell script. Manual intervention in the Docker engine is not required.
