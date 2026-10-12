<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset=".github/assets/betterlytics-logo-full-inline-light.svg">
  <source media="(prefers-color-scheme: light)" srcset=".github/assets/betterlytics-logo-full-inline-dark.svg">
  <img alt="Betterlytics" src=".github/assets/betterlytics-logo-full-inline-dark.svg" width="320">
</picture>

**Self-host Betterlytics with Docker**

[Main repository](https://github.com/betterlytics/betterlytics) | [Self-Hosting Guide](https://betterlytics.io/docs/installation/self-hosting) | [Website](https://betterlytics.io)

</div>

---

## Documentation

The [Self-Hosting Guide](https://betterlytics.io/docs/installation/self-hosting) has everything you need to run your own instance: requirements, deployment modes, the configuration reference, upgrading and troubleshooting.

## Quick Start

Rather skip the reading? These three steps get an instance running.

> [!NOTE]
> **Prerequisites**
> - Docker Engine 25+ and Docker Compose v2.24+
> - An x86_64 (amd64) machine. The image is not published for ARM

### 1. Configure

Run the interactive setup script to generate a `.env` file:

```bash
chmod +x setup.sh
./setup.sh
```

Or copy `.env.example` to `.env` and fill in the values manually.

> [!TIP]
> Just want to try it out?<br>
> Pick **Try locally** in the setup script to run locally.

### 2. Deploy

```bash
docker compose up -d --wait
```

### 3. Create the first account

Open your instance URL in a browser and create your account.

---

<div align="center">

If you find Betterlytics useful, consider giving it a star!

[![GitHub stars](https://img.shields.io/github/stars/betterlytics/betterlytics?style=social)](https://github.com/betterlytics/betterlytics)

</div>
