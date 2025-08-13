# Betterlytics - Self-Hosted

Betterlytics is a modern, privacy-first analytics platform that provides powerful insights about your website traffic without compromising user privacy.  
This repository provides everything you need to deploy Betterlytics on your own infrastructure using Docker.

## Quick Start

1. **Configure Environment Variables**  
   Update the `.env` file with your own settings (database credentials, API keys, etc.).

2. **Set Up Reverse Proxy**  
   Configure your preferred reverse proxy (e.g., Nginx, Traefik) to route incoming traffic to **port 5862**.

3. **Run Betterlytics**  
   From the project root, run:
   ```bash
   docker compose up -d
   ```

## Documentation

For detailed instructions, advanced configuration, and troubleshooting, see:  
📚 [Self-Hosting Guide](https://betterlytics.io/docs/installation/self-hosting)

## Requirements

- Docker & Docker Compose installed
- A configured reverse proxy
- An environment file (`.env`) with your settings
