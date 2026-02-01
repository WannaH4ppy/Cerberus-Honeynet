FROM ubuntu:22.04

# 1. Instalacja pakietów
# wget jest kluczowy dla honeypota!
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    openssh-server \
    rsyslog \
    iproute2 \
    nano \
    wget \
    && rm -rf /var/lib/apt/lists/*

# 2. Konfiguracja SSH
RUN mkdir -p /run/sshd
RUN echo 'root:root' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# --- KONFIGURACJA RSYSLOG ---
RUN sed -i '/imklog/s/^/#/' /etc/rsyslog.conf
RUN sed -i '/imuxsock/s/^#//' /etc/rsyslog.conf

# ---NAPRAWA PROBLEMU Z "sh"---

# Usuwamy prawdziwe 'sh' (dash) i wstawiamy link do basha.
# Dzięki temu haker wpisując 'sh' wchodzi do basha, którego kontrolujemy.
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Wymuszamy ładowanie configu.
# Bash udający sh normalnie olewa pliki .bashrc.
# Ta zmienna zmusza go do przeczytania pliku konfiguracyjnego przy starcie.
ENV ENV="/etc/bash.bashrc"

# --- SZPIEG BASHA (Hardened) ---
# A. Konfiguracja globalna (/etc/bash.bashrc)
# Ustawiamy logger
RUN echo 'export PROMPT_COMMAND="history -a; logger -t HACKER_CMD -p user.info \"\$(history 1)\""' >> /etc/bash.bashrc
# ZABEZPIECZENIA: Blokujemy zmianę tych zmiennych przez hakera
RUN echo 'readonly PROMPT_COMMAND' >> /etc/bash.bashrc
RUN echo 'readonly HISTFILE' >> /etc/bash.bashrc
RUN echo 'readonly HISTSIZE' >> /etc/bash.bashrc
RUN echo 'readonly HISTIGNORE' >> /etc/bash.bashrc

# B. Konfiguracja dla roota (/root/.bashrc) - jako zapas
RUN echo 'export PROMPT_COMMAND="history -a; logger -t HACKER_CMD -p user.info \"\$(history 1)\""' >> /root/.bashrc
RUN echo 'readonly PROMPT_COMMAND' >> /root/.bashrc
# Tutaj też blokujemy resztę, dla pewności
RUN echo 'readonly HISTFILE HISTSIZE HISTIGNORE' >> /root/.bashrc

# 3. Tworzenie skryptu startowego
RUN printf '#!/bin/bash\n\
echo "--- INICJALIZACJA KONTENERA ---"\n\
\n\
# 1. Naprawa uprawnień\n\
chown root:adm /var/log\n\
chmod 775 /var/log\n\
touch /var/log/syslog\n\
touch /var/log/auth.log\n\
\n\
chown syslog:adm /var/log/syslog /var/log/auth.log\n\
chmod 666 /var/log/syslog /var/log/auth.log\n\
\n\
# 2. Uruchamianie usług\n\
echo "Startuje rsyslogd..."\n\
/usr/sbin/rsyslogd\n\
\n\
sleep 1\n\
echo "Startuje sshd..."\n\
/usr/sbin/sshd\n\
\n\
echo "--- SYSTEM GOTOWY ---"\n\
# 4. Utrzymanie kontenera\n\
tail -f /var/log/syslog\n' > /start.sh

# 4. Start
RUN chmod +x /start.sh
EXPOSE 22
CMD ["/start.sh"]
