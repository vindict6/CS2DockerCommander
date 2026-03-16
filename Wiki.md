# 📖 CS2 Docker Commander - Complete Wiki
<sup>Brought to you by BONE from <a href="https://onlyzaps.gg">OnlyZaps.gg</a></sup>

Welcome to the CS2 Docker Commander Wiki! This wiki is designed to guide both laymen and advanced users through the entire structure, deployment, and management of the CS2 Server repository.

> **⚡ Tailored for CS2-SimpleAdmin, MetaMod, and CounterStrikeSharp ⚡**  
> *This container is fully pre-configured out-of-the-box to download, mount, and manage CounterStrikeSharp and its necessary ecosystem dependencies upon boot.*

---

## ⚙️ Deployment Configuration

The server is now highly configurable via the `deployment_settings.json` file in the root of the repository. You can change these settings to customize how your server is deployed without modifying the workflow files.

### Available Settings

| Setting | Default | Description |
| :--- | :--- | :--- |
| `SIMPLEADMIN_LOCALHOST_DB` | `true` | Enables the built-in MariaDB server for CS2-SimpleAdmin. |
| `GAME_PORT` | `27015` | The UDP/TCP port for game traffic. |
| `GOTV_PORT` | `27020` | The UDP port for GOTV (SourceTV) relay. |
| `GOTV_ENABLED` | `false` | Enables or disables GOTV. If enabled, it uses the port defined in `GOTV_PORT`. |
| `CONTAINER_NAME` | `cs2-server` | The name of the Docker container. Useful if running multiple servers on one host. |
| `DOCKER_VOLUME_NAME` | `cs2-data` | The name of the Docker volume for persistent data. Change this to run multiple distinct server instances. |

**Example `deployment_settings.json`:**
```json
{
  "SIMPLEADMIN_LOCALHOST_DB": true,
  "GAME_PORT": 27015,
  "GOTV_PORT": 27020,
  "CONTAINER_NAME": "cs2-server",
  "DOCKER_VOLUME_NAME": "cs2-data",
  "GOTV_ENABLED": false
}
```

> **Note:** The `GAME_PORT` and `GOTV_PORT` you specify here are automatically exposed in the Docker container during the build process.

---

## 📄 Understanding Your Server Layout (For Laymen)

Before we start running commands and clicking buttons, it's important to understand how the server actually works. Don't worry, this sounds complex but we've broken it down to be very simple!

### The Container
Think of a **Docker Container** like an isolated mini-computer that lives entirely inside your main (Host) machine. It has its own files, its own software running, and connects to the internet independently. Our CS2 server runs completely inside this container.

Inside the container:
- The base game files live in `/CS2`.
- Our custom configuration, scripts, and initial databases live in the `/app/` directory.
- Every time you rebuild or update the server using GitHub Actions, the container is destroyed and cleanly rebuilt from scratch! 

Wait... won't my game data and database get deleted? This is where **Docker Volumes** come in!

### The Docker Volume (`cs2-data`)
If deleting the container deletes the files inside, how do we keep your game maps, your downloaded add-ons, and your active player database safe?
We use a **Volume** called `cs2-data`. Think of a volume like an external USB flash drive that you plug into your container.

1. The `cs2-data` volume is securely stored independently on your host machine.
2. When the container starts, it "plugs in" this volume into the `/CS2` folder inside the container.
3. Everything the server downloads (plugins, maps) or saves (MySQL data) goes straight onto this volume. 
4. When the container updates and restarts, it plugs that same volume back in. Your database, logs, and game server assets instantly return exactly as they were!

---

## 📄 Initial Setup & GitHub Secrets

### 1. Host Machine Requirements
Because this server directly manipulates local Docker configurations, **you must have a GitHub Actions Runner installed and configured as a service on your target host server.** During repository setup, go to your GitHub repository **Settings** -> **Actions** -> **Runners** to securely bind your host machine to receive these commands.

### 2. GitHub Secrets Configuration
To manage and securely configure this server automatically, we utilize GitHub Actions workflows. To allow GitHub Actions to safely build your server and protect your passwords without placing them into public code for the world to see, you need to configure **GitHub Secrets**.

You must go to your repository on GitHub, click on **Settings** -> **Secrets and variables** -> **Actions**, and add the following keys:

- `RCON_PASSWORD`: The remote administration password for your CS2 server. (Required for in-game admin and remote connection commands).
- `STEAM_ACCOUNT_TOKEN`: Your Game Server Login Token (GSLT) from Steam. (Required to make the server visible to the public internet and tie it to your Steam account).
- `SA_DB_PASS`: Your secure password for the generated MariaDB database for SimpleAdmin server admins (`cs2_admin`). The server will automatically lock the database down using this password upon booting up.
- `GITHUB_TOKEN`: Generally, this is automatically provided by GitHub Actions for basic functionality, but if your setup utilizes automated private asset downloading (from other private Github repos), you will need to map a Classic Personal Access Token explicitly here so the container can download off GitHub during boot.

> **💡 Note on Custom Secrets:** Any additional secrets you define in GitHub (e.g. `STEAM_API_KEY`, `WEBHOOK_URL`) will automatically form part of the deployment's environment variables. You can inject them into any of your `.json` configuration files via string substitution seamlessly! Simply wrap the secret name like `${YOUR_SECRET_NAME}` inside your plugin configs natively in Git, and the server will automatically fill them upon boot!

---

## 📄 Managing the Server from the Host Machine

As the host machine admin, there are essential commands you will run via terminal to manually monitor or interact with the server. All these commands are executed directly on the host server where Docker is running.

**1. Viewing Live Server Logs**  
If you want to read what the server is currently outputting into the terminal, who is joining, or look out for crash errors, run:
```bash
# View the live streaming logs
docker logs -f cs2-server

# View just the recent last 100 lines and follow locally
docker logs --tail 100 -f cs2-server
```

**2. Executing into the Running Server (Exec in)**  
If you need to peek inside the container while it's actively running (to view a live file, manually adjust something via CLI, or run a test command):
```bash
# Open an interactive bash terminal inside the server as the 'steam' user
docker exec -it cs2-server /bin/bash
```

**3. Manually Restarting the Server**
```bash
docker restart cs2-server
```

**4. Stopping the Server**
```bash
docker stop cs2-server
```

---

## 📄 Database Migrations & Management

During the initial startup cycle, the server natively sets up a MariaDB database server inside the container. **Please note: this local database functionality is strictly configured to only be used for CS2-SimpleAdmin databases.** Because the MySQL directory is pushed natively into the `/CS2` directory line, the database files are permanently saved onto your `cs2-data` volume and persist across all reboots.

### How to Automatically Migrate an Existing Database
If you have an existing backup of your database (e.g., you are moving from another host, migrating admins over, or restoring a crashed backup) and you want it automatically imported into the live database:

**Method 1: The Volume Root Import (Recommended & Automatic)**
1. Move your SQL backup file and rename it to exactly `.cs2_admin_backup.sql`.
2. Place this file directly into the **root of your container volume**.
   - Your Volume is mapped to `/CS2` inside the container. Placing the file in the root of the `cs2-data` volume means it shows up as `/CS2/.cs2_admin_backup.sql` inside the container system.
3. The next time the server is restarted or rebuilt, the boot script (`entrypoint.sh`) will actively search for this hidden file.
4. **Behavior**: If found, it will automatically initiate the import into the new database namespace (`cs2_admin`), map all your tables, and then crucially **delete** the `.cs2_admin_backup.sql` file immediately so it never erroneously runs the migration twice!
5. *Wait, what if it doesn't see the file?* If this file is not present, the initialization script will simply continue utilizing what is already imported and running in your database from previous saves without touching it!

**Method 2: Static Deployment File**
If you include an `cs2_admin_backup.sql` file natively inside the `/databases/` folder of this Github repository, it is deployed to `/app/databases/` inside the container. The startup process *will* import it. However, because it is baked directly into the image's code, it will not delete it and will continually rewrite the database on every reboot. This method is great for a fixed default initialization schema, but not recommended for migrating massive amounts of live player data. 

---

## 📄 GitHub Actions Overview (The Buttons to Click)

This repository uses automated workflows (GitHub Actions) to do all the heavy lifting. Instead of SSH-ing into your host every time you update a `.json` configuration file, you trigger an action directly from the GitHub UI under the **"Actions"** tab.

Here is what each Action workflow does:

**1. Build and Deploy CS2 Server (`deploy.yml`)**
- **What it does:** The absolute "Full Reset and Update" button.
- It completely stops the existing server (with a 30-second graceful shutdown window), wipes out the container, and builds a brand new container from scratch (with `--no-cache`) using the newest repository files you just pushed.
- On boot, the entrypoint runs a **3-step SteamCMD update process** with automatic escalation:
  1. **Simple Update** — Attempts a fast differential update using the existing app manifest.
  2. **Validate** — If the simple update fails, cleans up temp files and retries with full file validation (`+app_update 730 validate`).
  3. **Clean Validate** — If validation also fails, deletes the app manifest (`appmanifest_730.acf`) and runs a fresh validate from scratch.
- Before running SteamCMD, the entrypoint cleans up stale lock files, incomplete downloads, and cached packages from previous runs. IPv6 is temporarily disabled at the kernel level during the update to prevent common SteamCMD connection errors (0x6), and re-enabled immediately after.
- Run this on large game-changing push days or when a full CS2 base game update is needed.

**2. Fast Update CS2 Server (`fast_update.yml`)**
- **What it does:** Similar to deploy, but forcefully skips the entire SteamCMD update process (all 3 steps above are bypassed).
- Use this when you've just updated a custom configuration, modified a CS2Sharp Plugin parameter, or updated an admin JSON file inside your repository.
- Because it flags `SKIP_CS2_UPDATE=true` into the environment, it immediately reconstructs the Docker configuration and applies your fast patches locally in a fraction of the time.

**3. Inject SQL Backup to Volume (`injectsql.yml`)**
- **What it does:** Safely pushes an SQL database backup explicitly into the persistent Docker Volume utilizing a temporary container without breaking the actual running game server.
- It copies the `cs2_admin_backup.sql` from your repository directly onto the `cs2-data` drive. Run this if you need to stage a rollback or a massive database migration. (*Note: You must restart the server afterwards to trigger the automatic data migration routine documented in the Database Migrations & Management section.*)

**4. Retrieve Live CSS Configs (`css_config_retrieval.yml`)**
- **What it does:** Securely extracts Counter-Strike Sharp (`configs`) directory files live off the running server and packages them directly back into the GitHub Actions dashboard tab as a downloadable Artifact (`.zip`).
- Have you ever wondered what dynamically generated configurations the server spawned in after a new plugin was booted for the first time? Run this Action, and GitHub will provide you a zip folder containing exactly what configurations are running actively on the server volume in real time. You can use these files to update your local repository and push them structurally back up!

---

## 📄 Repository Configuration Examples

This deployment relies heavily on Infrastructure as Code. Below are examples of every configuration layer managed by this repository so you understand how to naturally structure your edits.

### 1. Root Deployment Settings (`deployment_settings.json`)
Controls global deployment parameters across container boot cycles.
```json
{
  "SIMPLEADMIN_LOCALHOST_DB": true
}
```

### 2. Server Configuration (`server_config/server.xml`)
Replaces the standard `server.cfg`. It pushes these standard console variables directly into the engine. Let's look at an example:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!--
  Define the standard server.cfg settings here.
  The RCON password is automatically injected by the deployment script securely.
-->
<server>
    <arg value="log on" />
    <arg value='hostname "My Awesome CS2 Server"' />
    <arg value="mp_match_end_changelevel 1" />
    <arg value="mp_drop_knife_enable true" />
    <arg value="mp_spectators_max 10" />
    <arg value="mp_solid_teammates 2" />
    <arg value="sv_hibernate_when_empty false" />
    <arg value="mp_autokick 0" />
    <arg value="bot_all_weapons 1" />
</server>
```

### 3. Server Startup Parameters (`server_config/startup.xml`)
These arguments define what the CS2 executable runs on boot (e.g., ports, default map, bots, workshop collections).
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!--
  Define the startup arguments for the CS2 dedicated server here.
  These will be parsed and passed to the executable on boot.
  Note: +sv_setsteamaccount is injected securely via environment variables at runtime.
-->
<startup>
    <arg value="-dedicated" />
    <arg value="-console" />
    <arg value="-usercon" />
    <arg value="-ip 0.0.0.0" />
    <arg value="+game_type 0" />
    <arg value="+game_mode 0" />
    <arg value="+map de_dust2" />
    <arg value="+bot_quota 64" />
    <arg value="+mp_taser_recharge_time 1" />
    <arg value="+host_workshop_map 3408790618" />
</startup>
```

### 4. Custom GitHub Asset Downloader (`server_config/custom_assets.xml`)
This system automates downloading and extracting release zips directly into the CS2 directory upon a full container deployment without using FTP.
```xml
<?xml version="1.0" encoding="UTF-8"?>
<assets>
    <!-- Downloads the 1st asset (a zip) from the latest SimpleAdmin release and extracts it to the addons folder -->
    <asset
        url="https://github.com/daffyyyy/CS2-SimpleAdmin/releases/latest"
        asset_indexes="1"
        types="zip"
        dests="/CS2/game/csgo/addons/"
        excludes="counterstrikesharp/plugins/CS2-SimpleAdmin_FunCommands/*" />
</assets>
```

### 5. CS2-SimpleAdmin Admins File (`configs/admins.json`)
The structured list of base game administrators utilizing CS2-SimpleAdmin.
```json
{
  "76561198984876518": {
    "identity": "76561198026954051",
    "immunity": 100,
    "flags": [
      "@css/root"
    ]
  }
}
```

### 6. CounterStrikeSharp Core Plugins (`configs/plugins/CS2-SimpleAdmin/CS2-SimpleAdmin.json`)
Example structure for plugin configuration injected natively into the live CounterStrikeSharp directories on updates. 

**Note on Secrets Integration:** The deployment system natively supports dynamic variable injection of your GitHub Secrets! Inside any JSON configuration file (such as database credentials or API keys), you can simply use the `${SECRET_NAME}` syntax. The deployment pipeline will safely overwrite that field with your actual GitHub Secret value before copying it into the Docker Volume. Make sure your secrets perfectly match the names of the environment variables passed in the GitHub Actions!

See the dynamic `${SA_DB_PASS}` variable usage alongside the database configurations tailored for MariaDB below:
```json
{
  "ConfigVersion": 25,
  "DatabaseConfig": {
    "DatabaseType": "MySQL",
    "DatabaseHost": "localhost",
    "DatabasePort": 3306,
    "DatabaseUser": "cs2_admin_user",
    "DatabasePassword": "${SA_DB_PASS}",
    "DatabaseName": "cs2_admin",
    "DatabaseSSlMode": "preferred"
  },
  "OtherSettings": {
    "ShowActivityType": 0,
    "TeamSwitchType": 1,
    "KickTime": 5,
    "BanType": 1,
    "TimeMode": 1,
    "DisableDangerousCommands": true,
    "MaxBanDuration": 10080
  }
}
```