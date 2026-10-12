<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset=".github/assets/betterlytics-logo-full-inline-light.svg">
  <source media="(prefers-color-scheme: light)" srcset=".github/assets/betterlytics-logo-full-inline-dark.svg">
  <img alt="Betterlytics" src=".github/assets/betterlytics-logo-full-inline-dark.svg" width="320">
</picture>

</div>

# Betterlytics - Self-Hosted

Betterlytics is a modern, privacy-first analytics platform that provides powerful insights about your website traffic without compromising user privacy.
This repository provides everything you need to deploy Betterlytics on your own infrastructure using Docker.

## Quick Start

### 1. Configure

Run the interactive setup script to generate a `.env` file:

```bash
chmod +x setup.sh
./setup.sh
```

Or copy `.env.example` to `.env` and fill in the values manually.

### 2. Deploy

```bash
docker compose up -d --wait
```

### 3. Create the first account

Open your instance URL in a browser and create your account.

## Documentation

Requirements, deployment modes, the configuration reference, upgrading and troubleshooting are all covered in the [Self-Hosting Guide](https://betterlytics.io/docs/installation/self-hosting).
