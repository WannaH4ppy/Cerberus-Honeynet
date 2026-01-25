FROM ubuntu:22.04

# 1. Instalacja pakietów
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    openssh-server \
    auditd \
    rsyslog \
    iproute2 \
    nano \
    && rm -rf /var/lib/apt/lists/*

# 2. Konfiguracja SSH
RUN mkdir /var/run/sshd
RUN echo 'root:root' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# --- NOWOŚĆ 1: Naprawa rsyslog (wyłączenie imklog) ---
# To usuwa błąd "Operation not permitted" i pozwala rsyslogowi wstać bez marudzenia
RUN sed -i '/imklog/s/^/#/' /etc/rsyslog.conf

# --- NOWOŚĆ 2: Szpieg Basha (Podwójne uderzenie) ---
# Zapisujemy pułapkę w DWÓCH miejscach. 
# /etc/bash.bashrc - dla sesji interaktywnych SSH
# /root/.bashrc - dla sesji roota (np. docker exec), która czasem pomija pliki systemowe
# Zmieniono 'local6.info' na 'user.info' (pewniejsze zapisywanie do syslog)
RUN echo 'export PROMPT_COMMAND="history -a; logger -t HACKER_CMD -p user.info \"\$(history 1)\""' >> /etc/bash.bashrc
RUN echo 'export PROMPT_COMMAND="history -a; logger -t HACKER_CMD -p user.info \"\$(history 1)\""' >> /root/.bashrc

# 3. Tworzenie skryptu startowego
RUN echo '#!/bin/bash\n\
# --- TO JEST KLUCZOWE: Tworzymy plik, bo przez Volume folder jest pusty ---\n\
touch /var/log/syslog\n\
chown syslog:adm /var/log/syslog\n\
chmod 666 /var/log/syslog\n\
# ------------------------------------------------------------------------\n\
service rsyslog start\n\
# Auditd może zgłaszać błędy bez pid:host, ale próbujemy go uruchomić\n\
service auditd start || echo "Auditd failed to start but continuing..."\n\
auditctl -w /etc/passwd -p wa -k passwd_access || true\n\
/usr/sbin/sshd -D' > /start.sh

# 4. Nadanie uprawnień
RUN chmod +x /start.sh
EXPOSE 22

# 5. Start
CMD ["/start.sh"]