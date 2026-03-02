#!/bin/bash
set -e

if [ "$SKIP_CS2_UPDATE" = "true" ]; then
    echo "SKIP_CS2_UPDATE is set to true. Skipping CS2 base game update via SteamCMD..."
else
    echo "Updating CS2 Dedicated Server (Differential update)..."
    ~/steamcmd/steamcmd.sh +force_install_dir ${CS2_DIR} +login anonymous +app_update 730 validate +quit
fi

# Check deployment settings for MariaDB
ENABLE_LOCALHOST_DB="true" # Default to true if not specified
if [ -f "/app/deployment_settings.json" ]; then
    # Use jq to extract the boolean value. handle possible null/files
    SETTING_VAL=$(jq -r '.SIMPLEADMIN_LOCALHOST_DB // "true"' /app/deployment_settings.json)
    if [ "$SETTING_VAL" = "false" ]; then
        ENABLE_LOCALHOST_DB="false"
    fi
fi

if [ "$ENABLE_LOCALHOST_DB" = "true" ]; then
    echo "Setting up MariaDB (SIMPLEADMIN_LOCALHOST_DB=true)..."
    sudo mkdir -p ${CS2_DIR}/mysql_data

    # Ensure permissions and symlink logic
    # Stop service first if running (installer might start it)
    sudo service mariadb stop || sudo service mysql stop || true

    # If persistent data exists, use it. If not, initializing new data dir.
    if [ -d "${CS2_DIR}/mysql_data/mysql" ]; then
        echo "Using existing MariaDB data..."
    else
        echo "Initializing fresh MariaDB data directory..."
        # Copy initial data from default install location if available
        if [ -d "/var/lib/mysql" ]; then
            sudo cp -ra /var/lib/mysql/. ${CS2_DIR}/mysql_data/
        else
            # Fallback if /var/lib/mysql is missing or empty
            sudo mysql_install_db --user=mysql --datadir=${CS2_DIR}/mysql_data
        fi
    fi

    # Link /var/lib/mysql to our persistent directory
    sudo rm -rf /var/lib/mysql
    sudo ln -s ${CS2_DIR}/mysql_data /var/lib/mysql
    sudo chown -R mysql:mysql ${CS2_DIR}/mysql_data

    # Start MariaDB
    echo "Starting MariaDB service..."
    sudo service mariadb start || sudo service mysql start

    # wait for mariadb to be ready
    echo "Waiting for MariaDB to be ready..."
    until sudo mysqladmin ping --silent; do
        echo "MariaDB is unavailable - sleeping"
        sleep 1
    done

    echo "Configuring MariaDB..."
    # Check if backup file exists to restore
    # Look in the repo's databases/ folder (copied to /app/databases inside container)
    BACKUP_FILE="/app/databases/cs2_admin_backup.sql"
    
    # Also support hidden file in root of volume for manual overrides if needed (optional, keeping for backward compat or manual drop)
    HIDDEN_BACKUP_FILE="${CS2_DIR}/.cs2_admin_backup.sql"

    if [ -f "$HIDDEN_BACKUP_FILE" ]; then
        BACKUP_FILE="$HIDDEN_BACKUP_FILE"
    fi

    echo "Ensuring administrative database user..."
    # Secure installation and setup DB/User
    # Check if DB exists
    sudo mysql -e "CREATE DATABASE IF NOT EXISTS cs2_admin;"

    # Create user if not exists (or update password)
    # Note: Identify simply by password again updates it
    sudo mysql -e "CREATE USER IF NOT EXISTS 'cs2_admin_user'@'%' IDENTIFIED BY '${SA_DB_PASS}';"
    sudo mysql -e "ALTER USER 'cs2_admin_user'@'%' IDENTIFIED BY '${SA_DB_PASS}';"
    sudo mysql -e "GRANT ALL PRIVILEGES ON cs2_admin.* TO 'cs2_admin_user'@'%' REQUIRE SSL;"
    sudo mysql -e "FLUSH PRIVILEGES;"

    if [ -f "$BACKUP_FILE" ]; then
        echo "Found backup file: $BACKUP_FILE. Restoring..."
        # Use the root account (default socket auth) to restore
        if sudo mysql cs2_admin < "$BACKUP_FILE"; then
            echo "Restore complete."
            # Only delete if it was the temp hidden file in the volume, not the repo file
            if [ "$BACKUP_FILE" = "$HIDDEN_BACKUP_FILE" ]; then
                 rm -f "$BACKUP_FILE"
                 echo "Deleted hidden backup file."
            fi
        else
            echo "ERROR: Failed to restore backup file."
        fi
    else
        echo "No backup file found (${BACKUP_FILE}). Using existing database state."
    fi
else
    echo "Skipping MariaDB setup (SIMPLEADMIN_LOCALHOST_DB=false)."
fi

echo "Fetching latest MetaMod..."
MM_LATEST=$(curl -s "https://mms.alliedmods.net/mmsdrop/2.0/mmsource-latest-linux" || true)
if [ -n "$MM_LATEST" ] && [[ "$MM_LATEST" == *".tar.gz"* ]]; then
    wget -qO mms.tar.gz "https://mms.alliedmods.net/mmsdrop/2.0/${MM_LATEST}" || true
    if [ -s mms.tar.gz ] && tar -tzf mms.tar.gz >/dev/null 2>&1; then
        tar -xzf mms.tar.gz -C ${CS2_DIR}/game/csgo/ || true
        echo "MetaMod successfully extracted."
    else
        echo "Warning: Downloaded MetaMod archive is invalid. Skipping."
    fi
    rm -f mms.tar.gz
else
    echo "Warning: Could not fetch MetaMod list. Skipping update and using existing files."
fi

echo "Fetching latest CounterStrikeSharp (with-runtime)..."
CSS_URL=$(curl -sL "https://api.github.com/repos/roflmuffin/CounterStrikeSharp/releases/latest" | jq -r '.assets[]? | select((.name | test("linux")) and (.name | test("with-runtime"))) | .browser_download_url' 2>/dev/null | head -n 1 || true)

if [ -n "$CSS_URL" ] && [ "$CSS_URL" != "null" ]; then
    echo "Downloading CSS from: $CSS_URL"
    wget -O css.zip "$CSS_URL" || true
    if [ -s css.zip ]; then
        echo "Extracting CounterStrikeSharp..."
        unzip -o css.zip -d ${CS2_DIR}/game/csgo/ || echo "Warning: Failed to unzip CounterStrikeSharp."
        
        echo "Applying permission and security fixes to CounterStrikeSharp..."
        chmod -R 755 ${CS2_DIR}/game/csgo/addons/counterstrikesharp/bin/ || true

        echo "Clearing executable stack flag from counterstrikesharp.so..."
        sudo execstack -c /CS2/game/csgo/addons/counterstrikesharp/bin/linuxsteamrt64/counterstrikesharp.so || echo "Warning: execstack failed."

        echo "CounterStrikeSharp successfully extracted and applied over Metamod files."
    else
        echo "Warning: Downloaded css.zip is empty or invalid."
    fi
    rm -f css.zip
else
    echo "Warning: Failed to retrieve CounterStrikeSharp URL from GitHub API."
fi

echo "Applying MetaMod to gameinfo.gi..."
if [ -f ${CS2_DIR}/game/csgo/gameinfo.gi ]; then
    if ! grep -q "Game.*csgo/addons/metamod" ${CS2_DIR}/game/csgo/gameinfo.gi; then
        sed -i '0,/Game[[:blank:]]*csgo/s//Game\tcsgo\/addons\/metamod\n\t\t\tGame\tcsgo/' ${CS2_DIR}/game/csgo/gameinfo.gi
    fi
fi

echo "Downloading custom assets..."
if [ -f /app/server_config/custom_assets.xml ]; then
    bash -c 'xmlstarlet sel -t -m "//asset" -v "@url" -o "|" -v "@asset_indexes" -o "|" -v "@types" -o "|" -v "@dests" -o "|" -v "@excludes" -n /app/server_config/custom_assets.xml | while IFS="|" read -r url indexes types dests excludes; do
        if [ -n "$url" ]; then
            IFS="," read -ra IDX_ARRAY <<< "$indexes"
            IFS="," read -ra TYPE_ARRAY <<< "$types"
            IFS="," read -ra DEST_ARRAY <<< "$dests"
            # Separate excludes by comma (per asset index), allowing multiple patterns via space or specialized delimiter if needed
            # For simplicity, we assume one "excludes string" per asset index, which can contain multiple patterns separated by space if supported by unzip -x
            IFS="," read -ra EXCLUDE_ARRAY <<< "$excludes"
            
            # Clean URL to prevent invisible \r characters from breaking the curl request
            url=$(echo "$url" | tr -d "\r\n ")
            API_URL=$(echo "$url" | sed "s|https://github.com/|https://api.github.com/repos/|")
            
            for i in "${!IDX_ARRAY[@]}"; do
                idx=$((${IDX_ARRAY[$i]} - 1))
                type=$(echo "${TYPE_ARRAY[$i]}" | tr -d "\r\n ")
                dest=$(echo "${DEST_ARRAY[$i]}" | tr -d "\r\n")
                exclude_pattern=$(echo "${EXCLUDE_ARRAY[$i]}" | tr -d "\r\n")
                
                [ -z "$dest" ] && dest="${CS2_DIR}/game/csgo/"
                [ -z "$type" ] && type="zip"
                
                asset_url=""
                
                # Try fetching with token first (for private repos)
                if [ -n "$GITHUB_TOKEN" ]; then
                    asset_url=$(curl -sL -H "Authorization: Bearer $GITHUB_TOKEN" "$API_URL" | jq -r ".assets[$idx]?.browser_download_url" 2>/dev/null || true)
                fi
                
                # If token fails (cross-repo 401s), fallback to anonymous public access
                if [ -z "$asset_url" ] || [ "$asset_url" = "null" ]; then
                    asset_url=$(curl -sL "$API_URL" | jq -r ".assets[$idx]?.browser_download_url" 2>/dev/null || true)
                fi
                
                if [ "$asset_url" != "null" ] && [ -n "$asset_url" ]; then
                    echo "Downloading $type from $asset_url to $dest"
                    mkdir -p "$dest"
                    if [ "$type" = "zip" ]; then
                        # Removed -q flags so any errors are visible in logs
                        wget -O plugin.zip "$asset_url" || echo "ERROR: wget failed to download $asset_url"
                        
                        # Prepare exclusion args for unzip
                        # Usage: unzip file.zip -d dest -x "pattern1" "pattern2"
                        unzip_opts=""
                        if [ -n "$exclude_pattern" ]; then
                           # Split by space to allow multiple exclusions
                           # e.g. "addons/configs/* addons/logs/*"
                           unzip_opts="-x $exclude_pattern"
                           echo "Excluding: $exclude_pattern"
                        fi

                        # Try standard unzip first, fallback to 7z if WinRAR used advanced compression
                        # Note: 7z exclusion syntax is different (-xr!pattern) so detailed mapping is hard.
                        # We apply exclusion mainly to unzip here.
                        unzip -o plugin.zip -d "$dest" $unzip_opts || {
                            echo "Standard unzip failed. Attempting 7z extraction (fallback for WinRAR)..."
                            # 7zip exclusion logic if needed: -xr!pattern
                            sevenz_opts=""
                            if [ -n "$exclude_pattern" ]; then
                                for pattern in $exclude_pattern; do
                                    sevenz_opts="$sevenz_opts -xr!$pattern"
                                done
                            fi
                            7z x -y plugin.zip -o"$dest" $sevenz_opts || echo "ERROR: Failed to extract plugin.zip completely."
                        }
                        rm -f plugin.zip
                    else
                        wget -P "$dest" "$asset_url" || echo "ERROR: wget failed for $asset_url"
                    fi
                else
                    echo "WARNING: Could not resolve download URL for $url. Check if release is public and set as Latest."
                fi
            done
        fi
    done' || echo "Warning: custom_assets.xml parsing failed."
fi

echo "Syncing configurations..."
TARGET_CONFIG_DIR="${CS2_DIR}/game/csgo/addons/counterstrikesharp/configs"
mkdir -p "$TARGET_CONFIG_DIR"

if [ -d "/app/configs" ]; then
    cd /app/configs
    find . -type f | while read -r file; do
        # Extract directory path for the file relative to /app/configs
        dir_path=$(dirname "$file")
        
        # Create corresponding directory in target
        mkdir -p "$TARGET_CONFIG_DIR/$dir_path"
        
        # Process file with envsubst and write to target
        # We invoke envsubst with a list of currently defined variables to prevent accidentally
        # wiping out internal ${VAR} syntax that isn't an environment variable.
        # This command creates a string '$VAR1 $VAR2 ...' for all current env vars.
        # Note: This might hit command line length limits if there are huge numbers of env vars,
        # but for a container it's usually fine.
        defined_vars=""
        for v in $(env | cut -d= -f1); do
            defined_vars="$defined_vars \${$v} \$$v"
        done
        envsubst "$defined_vars" < "$file" > "$TARGET_CONFIG_DIR/$file"
    done
    cd - >/dev/null
else
    echo "Warning: /app/configs directory not found."
fi

# cp -ru /app/configs/plugins/* ${CS2_DIR}/game/csgo/addons/counterstrikesharp/configs/plugins/ 2>/dev/null || true

echo "Generating server.cfg and starting..."
SERVER_CFG_DEST="${CS2_DIR}/game/csgo/cfg/server.cfg"
mkdir -p "${CS2_DIR}/game/csgo/cfg"
rm -f "$SERVER_CFG_DEST"

if [ -f /app/server_config/server.xml ]; then
    xmlstarlet sel -t -m "//arg" -v "@value" -n /app/server_config/server.xml > "$SERVER_CFG_DEST"
else
    touch "$SERVER_CFG_DEST"
fi

# Apply the RCON password securely
if [ -n "$RCON_PASSWORD" ]; then
    echo "rcon_password \"$RCON_PASSWORD\"" >> "$SERVER_CFG_DEST"
fi

if [ -f /app/server_config/startup.xml ]; then
    STARTUP_ARGS=$(xmlstarlet sel -t -m "//arg" -v "@value" -o " " /app/server_config/startup.xml)
else
    STARTUP_ARGS="-dedicated +map de_dust2"
fi

# Apply the Steam Account Token securely
if [ -n "$STEAM_ACCOUNT_TOKEN" ]; then
    STARTUP_ARGS="$STARTUP_ARGS +sv_setsteamaccount $STEAM_ACCOUNT_TOKEN"
fi

echo "Starting Dedicated Server..."
cd "${CS2_DIR}/game"
exec ./bin/linuxsteamrt64/cs2 $STARTUP_ARGS
