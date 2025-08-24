FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Paris

# Install base dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        lsb-release wget gosu apt-transport-https gnupg2 curl jq gettext-base \
        apache2 memcached libssl-dev supervisor ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Add the official SOGo nightly repo dynamically (avoid duplicate lines)
RUN LATEST_VERSION=$(curl -s https://api.github.com/repos/Alinto/sogo/releases/latest \
      | jq -r '.tag_name' | awk -F '[.-]' '{print $2}') && \
    DISTRO=$(lsb_release -c -s) && \
    echo "deb [signed-by=/usr/share/keyrings/sogo-archive-keyring.gpg] \
         http://packages.sogo.nu/nightly/${LATEST_VERSION}/ubuntu/ $DISTRO $DISTRO" \
         > /etc/apt/sources.list.d/sogo.list && \
    wget -qO- https://keys.openpgp.org/vks/v1/by-fingerprint/74FFC6D72B925A34B5D356BDF8A27B36A6E2EAE9 \
         | gpg --dearmor -o /usr/share/keyrings/sogo-archive-keyring.gpg && \
    apt-get update && \
    apt-get install -y sogo sope4.9-gdl1-postgresql sope4.9-gdl1-mysql && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# DB client libs (optional: for troubleshooting)
RUN apt-get update && apt-get install -y \
        libpq-dev postgresql-client libmysqlclient-dev \
        --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Enable required Apache modules
RUN a2enmod headers proxy proxy_http rewrite ssl

# Move SOGo's data directory to /srv
RUN usermod --home /srv/lib/sogo sogo

# Runtime environment tweaks
ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libssl.so
ENV USEWATCHDOG=YES

# Copy supervisor config + init scripts
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY apache2.sh /etc/init.d/apache2.sh
COPY sogod.sh /etc/init.d/sogod.sh
COPY memcached.sh /etc/init.d/memcached.sh

# Make scripts executable
RUN chmod +x /etc/init.d/apache2.sh /etc/init.d/sogod.sh /etc/init.d/memcached.sh

# Expose volumes and ports
VOLUME /srv
EXPOSE 80 443 8800

# Start supervisord (manages apache2, memcached, sogod)
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
