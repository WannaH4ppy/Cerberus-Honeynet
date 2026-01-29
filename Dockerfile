FROM ubuntu:22.04

# 1.Instalacja pakietów
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    openssh-server \
    rsyslog \
    iproute2 \
    nano \
    && rm -rf /var/lib/apt/lists/*

# 2.Konfiguracja SSH
# Tworzymy katalog wymagany przez SSHD (bo nie uzywamy 'service')
RUN mkdir -p /run/sshd
RUN echo 'root:root' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

#KONFIGURACJA RSYSLOG
# Wyłączamy imklog (moduł kernela, nie działa w dockerze)
RUN sed -i '/imklog/s/^/#/' /etc/rsyslog.conf
# Włączamy nasłuchiwanie na sockecie /dev/log (kluczowe dla komendy logger)
RUN sed -i '/imuxsock/s/^#//' /etc/rsyslog.conf

#SZPIEG BASHA
RUN echo 'export PROMPT_COMMAND="history -a; logger -t HACKER_CMD -p user.info \"\$(history 1)\""' >> /etc/bash.bashrc
RUN echo 'export PROMPT_COMMAND="history -a; logger -t HACKER_CMD -p user.info \"\$(history 1)\""' >> /root/.bashrc

# Tworzenie skryptu startowego (WERSJA "DIRECT EXECUTION")
# Omijamy komendę 'service' i uruchamiamy demony bezpośrednio.
RUN printf '#!/bin/bash\n\
echo "--- INICJALIZACJA KONTENERA ---"\n\
\n\
# 1. Naprawa uprawnień i plików logów\n\
chown root:adm /var/log\n\
chmod 775 /var/log\n\
touch /var/log/syslog\n\
touch /var/log/auth.log\n\
\n\
chown syslog:adm /var/log/syslog /var/log/auth.log\n\
chmod 666 /var/log/syslog /var/log/auth.log\n\
\n\
# 2. Uruchamianie usług BEZPOŚREDNIO (omijamy 'service')\n\
echo "Startuję rsyslogd..."\n\
/usr/sbin/rsyslogd\n\
\n\
sleep 1\n\
echo "Startuję sshd..."\n\
/usr/sbin/sshd\n\
\n\

echo "--- SYSTEM GOTOWY ---"\n\
# 4. Utrzymanie kontenera przy życiu\n\
tail -f /var/log/syslog\n' > /start.sh

# 4.Start
RUN chmod +x /start.sh
EXPOSE 22
CMD ["/start.sh"]
