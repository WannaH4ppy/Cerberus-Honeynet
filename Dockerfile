FROM ubuntu:22.04

# 1. Instalacja pakietów
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    openssh-server \
    rsyslog \
    iproute2 \
    nano \
    wget \
    inotify-tools \
    apache2\
    php \
    libapache2-mod-php \
    iputils-ping\
    telnet\
    curl\
    mysql-client \
    && rm -rf /var/lib/apt/lists/*



#WEB SERVER CONTENT
RUN echo "<html><h1>Firmowy Portal Pracowniczy</h1><p>Dostep tylko dla upowaznionych.</p></html>" > /var/www/html/index.html

#plik robots.txt
RUN echo "User-agent: *" > /var/www/html/robots.txta
RUN echo "Disallow: /admin_panel/" >> /var/www/html/robots.txt
RUN echo "Disallow: /passwords/" >> /var/www/html/robots.txt

# Tworzymy te foldery eby nie bylo 404 jak sprawdzi
RUN mkdir -p /var/www/html/admin_panel
RUN mkdir -p /var/www/html/passwords
RUN echo "Admin Login" > /var/www/html/admin_panel/index.html

# 1.  katalogi pod "serwer WWW"
RUN mkdir -p /var/www/html
RUN mkdir -p /var/backups/sql

# 2.FAŁSZYWY PLIK KONFIGURACYJNY (Honeytoken)
RUN echo "<?php" > /var/www/html/config.php && \
    echo "// Database configuration" >> /var/www/html/config.php && \
    echo "\$db_host = 'localhost';" >> /var/www/html/config.php && \
    echo "\$db_user = 'root';" >> /var/www/html/config.php && \
    echo "\$db_pass = 'SuperTajneHaslo2024!';" >> /var/www/html/config.php && \
    echo "\$db_name = 'clients_db';" >> /var/www/html/config.php && \
    echo "?>" >> /var/www/html/config.php

# 3.BACKUP BAZY DANYCH fakeowy
RUN echo "-- MySQL dump 10.13" > /var/backups/sql/users_dump.sql && \
    echo "-- Host: localhost    Database: clients_db" >> /var/backups/sql/users_dump.sql && \
    echo "INSERT INTO users (id, login, password) VALUES (1, 'admin', 'md5_hash_here');" >> /var/backups/sql/users_dump.sql && \
    echo "INSERT INTO users (id, login, password) VALUES (2, 'ceo', 'qwerty12345');" >> /var/backups/sql/users_dump.sql


#CRON JOBS
# 1.Tworzymy skrypt "backupu"
RUN echo '#!/bin/bash' > /usr/local/bin/daily_backup.sh
RUN echo '# Skrypt backupu bazy danych - v1.2' >> /usr/local/bin/daily_backup.sh
RUN echo 'DB_USER="backup_user"' >> /usr/local/bin/daily_backup.sh
RUN echo 'DB_PASS="Xy7#b9@Lm2"' >> /usr/local/bin/daily_backup.sh # Fałszywe hasło!
RUN echo 'tar -czf /var/backups/site_backup_$(date +%F).tar.gz /var/www/html' >> /usr/local/bin/daily_backup.sh
RUN chmod +x /usr/local/bin/daily_backup.sh


RUN mkdir -p /root/.aws
RUN echo "[default]" > /root/.aws/credentials
RUN echo "aws_access_key_id = AKIAIOSFODNN7EXAMPLE" >> /root/.aws/credentials
RUN echo "aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY" >> /root/.aws/credentials
RUN echo "[default]" > /root/.aws/config
RUN echo "region = us-east-1" >> /root/.aws/config

# 2.harmonogramu
RUN echo "0 3 * * * root /usr/local/bin/daily_backup.sh" > /etc/cron.d/backup-job
# 4.HISTORIA BASH
RUN touch /root/.bash_history
RUN echo "apt update" >> /root/.bash_history
RUN echo "apt install mysql-server apache2" >> /root/.bash_history
RUN echo "systemctl status apache2" >> /root/.bash_history
RUN echo "nano /etc/apache2/sites-available/000-default.conf" >> /root/.bash_history
RUN echo "cd /var/www/html" >> /root/.bash_history
RUN echo "ls -la" >> /root/.bash_history
RUN echo "nano config.php" >> /root/.bash_history
RUN echo "cat config.php" >> /root/.bash_history
RUN echo "mysql -u root -p" >> /root/.bash_history
RUN echo "mysqldump -u root -p clients_db > /var/backups/sql/users_dump.sql" >> /root/.bash_history
RUN echo "ping -c 4 8.8.8.8" >> /root/.bash_history
RUN echo "ssh root@172.25.0.250" >> /root/.bash_history
RUN echo "ping google.com" >> /root/.bash_history
RUN echo "exit" >> /root/.bash_history

#5.Notatki Administratora
RUN echo "Marek, zrestartuj bazę po aktualizacji. Hasło do roota to nadal to stare." > /root/TODO.txt

#fake users
RUN useradd -m -s /bin/bash deploy
RUN useradd -m -s /bin/bash webmaster
RUN echo 'deploy:deploy2024' | chpasswd
RUN echo 'webmaster:admin1' | chpasswd

#KLUCZE SSH
RUN mkdir -p /root/.ssh
# Generujemy klucz, ktory donikad nie prowadzi 
RUN ssh-keygen -t rsa -b 2048 -f /root/.ssh/id_rsa -q -N ""
# Zmieniamy nazwe na "produkcyjna"
RUN mv /root/.ssh/id_rsa /root/.ssh/id_rsa_backup_prod

# 2. Konfiguracja SSH
RUN mkdir -p /run/sshd
RUN echo 'root:root' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config



# 1. nasluch na gniezdzie UNIX (niezbedne dla komendy logger)
# 2. imklog (logi kernela nie dzialaja w kontenerze)
# 3. WYMUSZAMY prace jako root ($PrivDropToUser)
RUN sed -i '/imklog/s/^/#/' /etc/rsyslog.conf && \
    sed -i '/imuxsock/s/^#//' /etc/rsyslog.conf && \
    echo '$PrivDropToUser root' >> /etc/rsyslog.conf && \
    echo '$PrivDropToGroup root' >> /etc/rsyslog.conf

#PROBLEMU Z "sh"
RUN rm /bin/sh && ln -s /bin/bash /bin/sh
ENV ENV="/etc/bash.bashrc"

#STEALTH USUWANIE KONFLIKTOW
RUN sed -i 's/^HISTSIZE=/#HISTSIZE=/' /etc/bash.bashrc /root/.bashrc /etc/skel/.bashrc && \
    sed -i 's/^HISTFILESIZE=/#HISTFILESIZE=/' /etc/bash.bashrc /root/.bashrc /etc/skel/.bashrc && \
    sed -i 's/^PROMPT_COMMAND=/#PROMPT_COMMAND=/' /etc/bash.bashrc /root/.bashrc /etc/skel/.bashrc

#BASH SPY

RUN echo 'if [ -z "$TRAP_ACTIVE" ]; then' > /etc/hacker_trap.sh
# KROK 1: Zapisz historie z RAM do dysku
RUN echo '    export PROMPT_COMMAND="history -a; ' >> /etc/hacker_trap.sh
# KROK 2: Wypisz ostatnia linie historii do pliku tmp (bez numeru linii dzieki sed)
RUN echo '    history 1 | sed \"s/^[ ]*[0-9]\+[ ]*//\" > /tmp/.cmd_trap; ' >> /etc/hacker_trap.sh
# KROK 3: zawartosc pliku do sysloga (flaga -f) oraz dodatkowo do ukrytego pliku (backup)
RUN echo '    logger -t HACKER_CMD -p user.info -f /tmp/.cmd_trap; ' >> /etc/hacker_trap.sh
RUN echo '    cat /tmp/.cmd_trap >> /var/log/.hacker_history"' >> /etc/hacker_trap.sh
# Blokada zmiennych
RUN echo '    readonly PROMPT_COMMAND HISTFILE HISTSIZE HISTIGNORE' >> /etc/hacker_trap.sh
RUN echo '    export TRAP_ACTIVE=1' >> /etc/hacker_trap.sh
RUN echo 'fi' >> /etc/hacker_trap.sh

RUN sed -i 's/\r//g' /etc/hacker_trap.sh

# Podpinamy czysta pulapke do startu systemu
RUN echo "source /etc/hacker_trap.sh" >> /etc/bash.bashrc
RUN echo "source /etc/hacker_trap.sh" >> /root/.bashrc

# 3. Skrypt startowy
RUN echo '#!/bin/bash' > /start.sh
RUN echo 'echo "--- INICJALIZACJA KONTENERA ---"' >> /start.sh


# 1. AWS Credentials
RUN echo 'mkdir -p /root/.aws' >> /start.sh
RUN echo 'echo "[default]" > /root/.aws/credentials' >> /start.sh
RUN echo 'echo "aws_access_key_id = AKIAIOSFODNN7EXAMPLE" >> /root/.aws/credentials' >> /start.sh
RUN echo 'echo "aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY" >> /root/.aws/credentials' >> /start.sh
RUN echo 'echo "[default]" > /root/.aws/config' >> /start.sh
RUN echo 'echo "region = us-east-1" >> /root/.aws/config' >> /start.sh

# 2. Historia Bash (Tylko jesli plik jest pusty)
RUN echo 'if [ ! -s /root/.bash_history ]; then' >> /start.sh
RUN echo '    echo "apt update" >> /root/.bash_history' >> /start.sh
RUN echo '    echo "mysql -u root -p" >> /root/.bash_history' >> /start.sh
RUN echo '    echo "nano /var/www/html/config.php" >> /root/.bash_history' >> /start.sh
RUN echo '    echo "aws configure" >> /root/.bash_history' >> /start.sh
RUN echo '    chown root:root /root/.bash_history' >> /start.sh
RUN echo 'fi' >> /start.sh

# Czyszczenie PID rsysloga
RUN echo 'rm -f /var/run/rsyslogd.pid' >> /start.sh
# Uprawnienia
RUN echo 'chown root:adm /var/log && chmod 775 /var/log' >> /start.sh
RUN echo 'touch /var/log/syslog /var/log/auth.log' >> /start.sh
RUN echo 'chmod 666 /var/log/syslog /var/log/auth.log' >> /start.sh
#APACHE (Tworzymy folder, ktry znika przez wolumen) ---
RUN echo 'mkdir -p /var/log/apache2' >> /start.sh
RUN echo 'echo "ServerName localhost" >> /etc/apache2/apache2.conf' >> /start.sh
# Start usug
RUN echo 'echo "Startuje rsyslogd..." && /usr/sbin/rsyslogd' >> /start.sh
# Czekamy chwile az rsyslog utworzy /dev/log
RUN echo 'sleep 2' >> /start.sh
#apache
RUN echo 'echo "Startuje Apache..." && service apache2 start' >> /start.sh
RUN echo 'echo "Startuje sshd..." && /usr/sbin/sshd' >> /start.sh
RUN echo 'echo "--- SYSTEM GOTOWY ---"' >> /start.sh
# --- MONITORING GLOBALNY (ZAAWANSOWANY KAMUFLAŻ) ---

# 1. Kopiujemy inotifywait jako fałszywy demon zarządzania urządzeniami (udevd).
# Demon udevd w rzeczywistości często przyjmuje argumenty i ścieżki, więc flagi -m -r wtopią się w tło.
RUN mkdir -p /lib/systemd/ && cp /usr/bin/inotifywait /lib/systemd/systemd-udevd

# 2. Tworzymy główny skrypt jako fałszywy journald (klasyczny demon logujący).
RUN echo '#!/bin/bash' > /lib/systemd/systemd-journald && \
    echo '/lib/systemd/systemd-udevd -m -r -e close_write,create,delete /root /etc /var/www/html /var/backups /tmp | while read path action file; do' >> /lib/systemd/systemd-journald && \
    echo '    logger -t HONEYPOT_ALERT "NARUSZENIE INTEGRALNOSCI: Sciezka: ${path} | Plik: ${file} | Akcja: ${action}"' >> /lib/systemd/systemd-journald && \
    echo '    if [[ "${action}" == *"CLOSE_WRITE"* || "${action}" == *"CREATE"* ]]; then' >> /lib/systemd/systemd-journald && \
    echo '        if [ -f "${path}${file}" ]; then' >> /lib/systemd/systemd-journald && \
    echo '            hash=$(sha256sum "${path}${file}" | cut -d" " -f1)' >> /lib/systemd/systemd-journald && \
    echo '            logger -t HONEYPOT_IOC "NOWY ARTEFAKT: Plik: ${path}${file} | SHA256: ${hash}"' >> /lib/systemd/systemd-journald && \
    echo '        fi' >> /lib/systemd/systemd-journald && \
    echo '    fi' >> /lib/systemd/systemd-journald && \
    echo 'done' >> /lib/systemd/systemd-journald

# 3. Nadajemy uprawnienia wykonywania BEZPOŚREDNIO dla pliku.
RUN chmod +x /lib/systemd/systemd-journald

# 4. W start.sh wywołujemy go jako czystą binarkę (dzięki temu w ps aux zniknie napis /bin/bash!)
RUN echo '/lib/systemd/systemd-journald &' >> /start.sh

# --- MASKOWANIE PID 1 ---
# Zamiast 'sleep infinity', używamy 'tail -f /dev/null'. 
# Dzięki temu PID 1 przedstawi się jako '/sbin/init -f /dev/null', co wygląda jak naturalne parametry bootowania.
RUN echo 'exec -a /sbin/init tail -f /dev/null' >> /start.sh

# Oczyszczanie pliku startowego i nadawanie praw
RUN sed -i 's/\r//g' /start.sh && chmod +x /start.sh

EXPOSE 22
CMD ["/start.sh"]
