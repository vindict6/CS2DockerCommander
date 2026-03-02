<div align="center">

# ⚡ CS2 Docker Commander
<sub>Brought to you by BONE from <a href="https://onlyzaps.gg">OnlyZaps.gg</a></sub><br>

*Automated, Containerized, and Highly Configurable Counter-Strike 2 Dedicated Server Deployment*

[![Docker](https://img.shields.io/badge/Docker-2CA5E0?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=for-the-badge&logo=github-actions&logoColor=white)](https://github.com/features/actions)
[![Counter-Strike 2](https://img.shields.io/badge/Counter--Strike_2-FFA500?style=for-the-badge&logo=counter-strike&logoColor=white)](https://www.counter-strike.net/)
[![MariaDB](https://img.shields.io/badge/MariaDB-003545?style=for-the-badge&logo=mariadb&logoColor=white)](https://mariadb.org/)

<a href="https://buymeacoffee.com/theboneman"><img src="https://img.shields.io/badge/Buy_Me_A_Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black" alt="Buy Me A Coffee"></a>

---

### Welcome to the most seamless Counter-Strike 2 server management experience. 

> **⚡ Tailored for CS2-SimpleAdmin, MetaMod, and CounterStrikeSharp ⚡**  
> *This container is fully pre-configured out-of-the-box to download, mount, and manage CounterStrikeSharp and its necessary ecosystem dependencies upon boot.*

This repository is a fully automated infrastructure-as-code solution for deploying a **Counter-Strike 2 Dedicated Server**. 
Built on Docker and powered by GitHub Actions, it completely handles the heavy lifting: SteamCMD updates, MetaMod & CounterStrikeSharp installations, dynamic plugin downloads, database migrations, and live config updates—all without you ever needing to FTP into a server.

It natively manages the game environment configuration while utilizing persistent Docker Volumes to ensure your maps, databases, and custom plugins are perfectly preserved across every update footprint.

> **NEW: Easy Deployment Configuration!**  
> You can now easily configure your ports, container name, volume name, and GOTV settings in `deployment_settings.json` without touching any code.
> This allows you to easily deploy multiple servers on one host!

<br>

<a href="./Wiki.md">
  <picture>
    <img src="https://img.shields.io/badge/📖_OPEN_THE_COMPLETE_WIKI_➔-1f2328?style=for-the-badge&labelColor=238636&logo=readthedocs&logoColor=white" width="400" alt="Read the Wiki">
  </picture>
</a>

<br><br>

</div>

## ✨ Key Features

- **🎮 100% Containerized:** Runs securely inside an isolated Docker container. No messy host machine dependencies.
- **☁️ Infrastructure as Code (IaC):** Server settings, launch parameters, and plugins are defined in simple XML/JSON files. Keep your entire environment version-controlled and safely backed up to GitHub.
- **🔄 Automated CI/CD Pipelines:** Out-of-the-box GitHub Actions to spin up the server, securely compile secrets, update the base game, or perform lightning-fast hot-reloads of your simple configs.
- **🛡️ Built-in Database Node:** Features fully automated, persistent MariaDB integration for handling advanced admin systems and player stats securely out of the public eye.
- **📦 Dynamic Asset Fetcher:** The system automatically scrapes, downloads, and extracts the latest releases of your compiled server plugins directly from GitHub on boot.

<br>

<div align="center">

> ### Need to know how to set up your secrets, use the host commands, or automatically migrate your database?  
> **All step-by-step tutorials and technical documentation have been relocated to the comprehensive Wiki.**
> 
> [**Click here to read the Wiki**](./Wiki.md)

</div>

<hr>

<div align="center">
  <p><i>Managed automatically via GitHub Workflows • Designed for scalability and absolute ease of use</i></p>
</div>
