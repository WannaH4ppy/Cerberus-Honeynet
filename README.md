# 🍯 Advanced Hybrid Honeypot & Threat Intelligence Lab

Kompleksowe, skonteneryzowane środowisko badawcze służące do detekcji, izolacji i analizy cyberataków w czasie rzeczywistym.
Projekt łączy pułapki o niskiej i średniej interakcji z autorskim, wysoce interaktywnym środowiskiem **REAL-OS**.
Wyposażony w zaawansowane mechanizmy maskowania (Obfuscation) oraz natychmiastowy eksport logów (Push Architecture).

## Architektura Systemu

System opiera się na rygorystycznej segmentacji sieciowej (Docker Networks), dzieląc infrastrukturę na dwie strefy:

1. **Strefa DMZ (`172.25.0.0/24`) - Przestrzeń ataku:**
   * **REAL-OS** - Autorski kontener High-Interaction (Ubuntu 22.04) z fałszywym serwerem WWW, bazą danych, honeytokenami (AWS/MySQL) i ukrytym systemem audytującym.
   * **Cowrie** - Honeypot Medium-Interaction emulujący ataki na usługi SSH oraz Telnet.
   * **Dionaea** - Honeypot Low-Interaction łapiący złośliwe oprogramowanie (Malware) m.in. z wykorzystaniem protokołów SMB, HTTP, FTP.
   * **Snort NIDS** - System wykrywania intruzów nasłuchujący bezpośrednio na wirtualnym mostku strefy DMZ.

2. **Strefa Management (`172.26.0.0/24`):**
   * **Promtail & Loki** - Agregator logów i nierelacyjna baza danych.
   * **Grafana** - Interaktywny pulpit nawigacyjny (Dashboard) mapujący wektory ataków na globalną matrycę **MITRE ATT&CK**.
   * **Portainer** - Graficzny interfejs zarządzania środowiskiem kontenerowym.

## ✨ Kluczowe funkcjonalności i zabezpieczenia

* **Ścisła Izolacja Sieciowa (Containment):** Automatyczne wstrzykiwanie reguł `iptables` do łańcucha `DOCKER-USER` z poziomu hosta.
*  Bezwzględne blokowanie prób ucieczki do sieci prywatnych (RFC 1918) oraz ochrona przed atakami DoS za pomocą modułu `limit` (max 20 pakietów/s).
* **Zaawansowane Maskowanie (Stealth & Obfuscation):** Środowisko REAL-OS zostało zaprojektowane z myślą o opóźnieniu demaskacji przez intruza:
  * Mistyfikacja głównego procesu (PID 1) przy użyciu polecenia `exec -a /sbin/init tail -f /dev/null`.
  * Ukrywanie agentów śledzących w systemie plików (narzędzia operują w pamięci pod przykrywką procesów `systemd-journald` oraz `systemd-udevd`).
  * Niewidoczny, niemożliwy do wyłączenia z poziomu powłoki keylogger oparty o ukryte i zablokowane zmienne `PROMPT_COMMAND` (Readonly).
* **Odporność na Anti-Forensics (Push Architecture):** Utrata kontenera nie oznacza utraty dowodów.
*  Logi i pozyskane złośliwe pliki są w czasie rzeczywistym streamowane do odizolowanej bazy Loki, zanim intruz zdąży zrealizować komendę `rm -rf /var/log/`.
* **Półautomatyczny Rollback:** Błyskawiczne odtwarzanie czystego środowiska (Infrastructure as Code) zarządzane w pełni z poziomu zintegrowanego centrum dowodzenia w środowisku PowerShell.
* **Twarde Limity Zasobów (Hard Limits):** Ścisła alokacja zasobów CPU i RAM oraz mechanizmy Healthcheck zapobiegające awariom wynikającym z wyczerpania zasobów.

## 🚀 Instalacja i Uruchomienie

### Wymagania wstępne:
* Docker & Docker Compose
* Windows Subsystem for Linux (WSL2) - zalecane ze względu na konfigurację środowiskową `.wslconfig`
* PowerShell 5.1+

### Procedura startowa:
Całym cyklem życia środowiska zarządza autorski skrypt PowerShell `Honeypot-Control.ps1`. Nie wymaga to ręcznego ingerowania w silnik Dockera.
