# Use standard SteamCMD image starting as root to install dependencies
FROM cm2network/steamcmd:root

# Install required tools (Added sudo, libelf1 for execstack, and p7zip-full for WinRAR zip support)
# Added mariadb-server and mariadb-client
# Added gettext-base for envsubst
RUN apt-get update && \
    apt-get install -y curl wget jq xmlstarlet unzip sed sudo ca-certificates libicu-dev libelf1 p7zip-full mariadb-server mariadb-client gettext-base && \
    rm -rf /var/lib/apt/lists/*

# Manually download and install execstack from the Ubuntu Focal archives (since Debian removed it)
RUN wget -qO execstack.deb http://archive.ubuntu.com/ubuntu/pool/universe/p/prelink/execstack_0.0.20131005-1_amd64.deb && \
    dpkg -i execstack.deb && \
    rm execstack.deb

# Grant the steam user passwordless sudo so it can execute execstack in the entrypoint
RUN echo "steam ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

ENV CS2_DIR=/CS2

# Prepare directory and assign ownership to the steam user
RUN mkdir -p ${CS2_DIR} && chown steam:steam ${CS2_DIR}

# Switch to the non-root steam user
USER steam
WORKDIR ${CS2_DIR}

# We move all deployment logic to a temporary /app/ directory inside the container
COPY --chown=steam:steam server_config/ /app/server_config/
COPY --chown=steam:steam configs/ /app/configs/
COPY --chown=steam:steam databases/ /app/databases/
COPY --chown=steam:steam deployment_settings.json /app/deployment_settings.json
COPY --chown=steam:steam entrypoint.sh /app/entrypoint.sh

RUN chmod +x /app/entrypoint.sh

# Open necessary ports (Game ports and Database)
EXPOSE 27015/tcp 27015/udp 27020/udp

# Start the initialization script
ENTRYPOINT ["/app/entrypoint.sh"]
