#!/bin/sh
set -e

# -----------------------------------------------
# Betterlytics Self-Hosted Setup Script
# -----------------------------------------------

ENV_FILE=".env"

# --- Helpers ---

generate_secret() {
    # LC_ALL=C: under a UTF-8 locale, BSD tr (macOS) can stop on invalid byte sequences and return a short or empty string
    LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$1"
}

# Validators return 0 on success, 1 on failure (and print the error message).

validate_not_empty() {
    if [ -z "$1" ]; then
        echo "  Error: $2 cannot be empty."
        return 1
    fi
}

validate_domain() {
    case "$1" in
        http://*|https://*)
            echo "  Error: Domain should not include the protocol (http:// or https://)."
            return 1
            ;;
    esac
    case "$1" in
        */)
            echo "  Error: Domain should not have a trailing slash."
            return 1
            ;;
    esac
}

# Basic mode always yields https://DOMAIN (base/.env.base PUBLIC_BASE_URL); auth rejects any other origin.
validate_not_ip() {
    if printf '%s\n' "$1" | grep -qE '^[0-9]{1,3}(\.[0-9]{1,3}){3}(:[0-9]+)?$|^\[|:.*:'; then
        echo "  Error: Basic mode needs a domain name (e.g. analytics.example.com) that your"
        echo "         reverse proxy serves over HTTPS. Logins fail when Betterlytics is opened"
        echo "         by IP address or over plain HTTP. For that setup, see"
        echo "         \"Plain HTTP or IP access\" in the README."
        return 1
    fi
}

validate_port() {
    case "$1" in
        ''|*[!0-9]*)
            echo "  Error: Port must be a number."
            return 1
            ;;
    esac
    if [ "$1" -lt 1 ] || [ "$1" -gt 65535 ]; then
        echo "  Error: Port must be between 1 and 65535."
        return 1
    fi
}

print_banner() {
    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
        _b=$(printf '\033[38;2;32;115;188m'); _r=$(printf '\033[0m')
    else
        _b=''; _r=''
    fi
    cat <<EOF
  ██████╗ ███████╗████████╗████████╗███████╗██████╗
  ██╔══██╗██╔════╝╚══██╔══╝╚══██╔══╝██╔════╝██╔══██╗
  ██████╔╝█████╗     ██║      ██║   █████╗  ██████╔╝
  ██╔══██╗██╔══╝     ██║      ██║   ██╔══╝  ██╔══██╗
  ██████╔╝███████╗   ██║      ██║   ███████╗██║  ██║
  ╚═════╝ ╚══════╝   ╚═╝      ╚═╝   ╚══════╝╚═╝  ╚═╝
  ${_b}██╗  ██╗   ██╗████████╗██╗ ██████╗███████╗${_r}
  ${_b}██║  ╚██╗ ██╔╝╚══██╔══╝██║██╔════╝██╔════╝${_r}
  ${_b}██║   ╚████╔╝    ██║   ██║██║     ███████╗${_r}
  ${_b}██║    ╚██╔╝     ██║   ██║██║     ╚════██║${_r}
  ${_b}███████╗██║      ██║   ██║╚██████╗███████║${_r}
  ${_b}╚══════╝╚═╝      ╚═╝   ╚═╝ ╚═════╝╚══════╝${_r}
EOF
}

# --- Arrow-key menu selector ---
# Usage: menu_select "Option A" "Description A" "Option B" "Description B" ...
# Returns the 0-based index of the selected option in MENU_RESULT.

menu_select() {
    # Parse pairs of (label, description) into arrays
    _menu_count=0
    _menu_idx=1
    while [ "$_menu_idx" -le "$#" ]; do
        eval "_menu_label_${_menu_count}=\"\$(eval echo \"\\\$${_menu_idx}\")\""
        _menu_idx=$((_menu_idx + 1))
        eval "_menu_desc_${_menu_count}=\"\$(eval echo \"\\\$${_menu_idx}\")\""
        _menu_idx=$((_menu_idx + 1))
        _menu_count=$((_menu_count + 1))
    done

    _menu_sel=0

    # Save terminal settings and enable raw mode
    _menu_old_stty=$(stty -g)
    stty raw -echo

    # Draw initial menu
    _menu_i=0
    while [ "$_menu_i" -lt "$_menu_count" ]; do
        eval "_ml=\"\$_menu_label_${_menu_i}\""
        eval "_md=\"\$_menu_desc_${_menu_i}\""
        if [ "$_menu_i" -eq "$_menu_sel" ]; then
            printf "  > %s  -  %s\r\n" "$_ml" "$_md"
        else
            printf "    %s  -  %s\r\n" "$_ml" "$_md"
        fi
        _menu_i=$((_menu_i + 1))
    done

    while true; do
        # Read a single character
        _key=$(dd bs=1 count=1 2>/dev/null)

        if [ "$_key" = "$(printf '\003')" ]; then
            # Ctrl+C - restore terminal and exit
            stty "$_menu_old_stty"
            printf "\r\n"
            exit 130
        elif [ "$_key" = "$(printf '\033')" ]; then
            # Escape sequence - read next two chars
            _k2=$(dd bs=1 count=1 2>/dev/null)
            _k3=$(dd bs=1 count=1 2>/dev/null)
            if [ "$_k2" = "[" ]; then
                case "$_k3" in
                    A) # Up arrow
                        if [ "$_menu_sel" -gt 0 ]; then
                            _menu_sel=$((_menu_sel - 1))
                        fi
                        ;;
                    B) # Down arrow
                        if [ "$_menu_sel" -lt $((_menu_count - 1)) ]; then
                            _menu_sel=$((_menu_sel + 1))
                        fi
                        ;;
                esac
            fi
        elif [ "$_key" = "$(printf '\r')" ] || [ "$_key" = "" ]; then
            # Enter key
            break
        elif [ "$_key" = "k" ] || [ "$_key" = "K" ]; then
            # k = up (vim-style)
            if [ "$_menu_sel" -gt 0 ]; then
                _menu_sel=$((_menu_sel - 1))
            fi
        elif [ "$_key" = "j" ] || [ "$_key" = "J" ]; then
            # j = down (vim-style)
            if [ "$_menu_sel" -lt $((_menu_count - 1)) ]; then
                _menu_sel=$((_menu_sel + 1))
            fi
        fi

        # Move cursor up to redraw
        _menu_i=0
        while [ "$_menu_i" -lt "$_menu_count" ]; do
            printf '\033[A'
            _menu_i=$((_menu_i + 1))
        done

        # Redraw menu
        _menu_i=0
        while [ "$_menu_i" -lt "$_menu_count" ]; do
            eval "_ml=\"\$_menu_label_${_menu_i}\""
            eval "_md=\"\$_menu_desc_${_menu_i}\""
            if [ "$_menu_i" -eq "$_menu_sel" ]; then
                printf "  > %s  -  %s\033[K\r\n" "$_ml" "$_md"
            else
                printf "    %s  -  %s\033[K\r\n" "$_ml" "$_md"
            fi
            _menu_i=$((_menu_i + 1))
        done
    done

    # Restore terminal
    stty "$_menu_old_stty"

    MENU_RESULT=$_menu_sel
}

# --- Pre-flight check ---

if [ -e "$ENV_FILE" ]; then
    echo ""
    echo "  Setup is for first-time installation only."
    echo "  Existing configuration found; nothing was changed."
    echo "  Replacing this configuration can break your existing installation."
    echo ""
    echo "  To upgrade, follow the Self-Hosting Guide:"
    echo "  https://betterlytics.io/docs/installation/self-hosting"
    echo ""
    exit 1
fi

# =============================================
#  Welcome
# =============================================

echo ""
print_banner
echo ""
echo "  Self-Hosted Setup"
echo ""

# =============================================
#  Step 1: Deployment Mode
# =============================================

echo "  Choose a deployment mode: (Use ▲/▼ to select, Enter to confirm)"
echo ""

menu_select \
    "Standalone"  "Automatic HTTPS via Let's Encrypt" \
    "Basic"       "HTTP only for use behind a reverse proxy" \
    "Try locally" "Quick local setup on localhost"

case "$MENU_RESULT" in
    0) DEPLOY_MODE="standalone" ;;
    1) DEPLOY_MODE="basic" ;;
    2) DEPLOY_MODE="local" ;;
esac

# =============================================
#  Step 2: Domain & Network
# =============================================

echo ""
echo "-------------------------------------------"
echo "  Domain & Network"
echo "-------------------------------------------"
echo ""

FORCE_HTTP_SCHEME=""   # never inherit one from the operator's shell

if [ "$DEPLOY_MODE" = "standalone" ]; then
    HTTP_SCHEME="https"
    HTTP_PORT=80
    HTTPS_PORT=443
    BIND_ADDRESS="0.0.0.0"

    while true; do
        printf "  Domain name (e.g. analytics.example.com): "
        read -r DOMAIN
        validate_not_empty "$DOMAIN" "Domain" && validate_domain "$DOMAIN" && break
    done

elif [ "$DEPLOY_MODE" = "basic" ]; then
    HTTP_SCHEME="http"
    HTTPS_PORT=443
    BIND_ADDRESS="127.0.0.1"

    echo "  Use the hostname your reverse proxy serves over HTTPS."
    echo "  Add :port if the proxy serves HTTPS on a port other than 443."
    echo ""
    while true; do
        printf "  Domain name (e.g. analytics.example.com): "
        read -r DOMAIN
        validate_not_empty "$DOMAIN" "Domain" && validate_domain "$DOMAIN" && validate_not_ip "$DOMAIN" && break
    done

    while true; do
        printf "  HTTP port (default: 5566): "
        read -r PORT_INPUT
        if [ -z "$PORT_INPUT" ]; then
            HTTP_PORT=5566
            break
        fi
        validate_port "$PORT_INPUT" && HTTP_PORT="$PORT_INPUT" && break
    done

else
    # local mode
    HTTP_SCHEME="http"
    HTTPS_PORT=443
    BIND_ADDRESS="127.0.0.1"

    while true; do
        printf "  HTTP port (default: 5566): "
        read -r PORT_INPUT
        if [ -z "$PORT_INPUT" ]; then
            HTTP_PORT=5566
            break
        fi
        validate_port "$PORT_INPUT" && HTTP_PORT="$PORT_INPUT" && break
    done

    DOMAIN="localhost:${HTTP_PORT}"
    FORCE_HTTP_SCHEME="http"
fi

# =============================================
#  Generate & Write Configuration
# =============================================

SECRET_BASE=$(generate_secret 64)
if [ "${#SECRET_BASE}" -ne 64 ]; then
    echo "  Error: could not generate a random secret. Nothing was written."
    exit 1
fi

cat > "$ENV_FILE" <<EOF
# ===========================================
# Betterlytics Self-Hosted Configuration
# Generated by setup.sh
# ===========================================

# --- Geolocation ---
ENABLE_GEOLOCATION="false"
MAXMIND_ACCOUNT_ID="xxxxx"
MAXMIND_LICENSE_KEY="xxxxx"

# --- Domain ---
DOMAIN="${DOMAIN}"

# --- Proxy / HTTPS ---
HTTP_SCHEME="${HTTP_SCHEME}"
HTTP_PORT="${HTTP_PORT}"
HTTPS_PORT="${HTTPS_PORT}"
BIND_ADDRESS="${BIND_ADDRESS}"

# --- Secret Base ---
SECRET_BASE="${SECRET_BASE}"

EOF

if [ -n "$FORCE_HTTP_SCHEME" ]; then
    echo "FORCE_HTTP_SCHEME=${FORCE_HTTP_SCHEME}" >> "$ENV_FILE"
    echo "" >> "$ENV_FILE"
fi

# --- Write docker-compose.override.yml ---

OVERRIDE_FILE="docker-compose.override.yml"
if [ "$DEPLOY_MODE" = "standalone" ]; then
    cat > "$OVERRIDE_FILE" <<EOF
services:
  betterlytics-selfhost:
    ports:
      - "${BIND_ADDRESS}:${HTTPS_PORT}:443"
EOF
else
    rm -f "$OVERRIDE_FILE"
fi

# =============================================
#  Summary
# =============================================

# Same expression as PUBLIC_BASE_URL in base/.env.base, so the printed URL is the one auth accepts.
ACCESS_URL="${FORCE_HTTP_SCHEME:-https}://${DOMAIN}"

echo ""
echo "==========================================="
echo "  Setup Complete"
echo "==========================================="
echo ""
if [ "$DEPLOY_MODE" = "standalone" ]; then
    _mode_label="Standalone (automatic HTTPS)"
elif [ "$DEPLOY_MODE" = "basic" ]; then
    _mode_label="Basic (HTTP)"
else
    _mode_label="Try locally (HTTP on localhost)"
fi
echo "  Mode:       ${_mode_label}"
echo "  Domain:     ${DOMAIN}"
echo "  URL:        ${ACCESS_URL}"
if [ "$DEPLOY_MODE" = "basic" ]; then
    echo "  Proxy to:   http://127.0.0.1:${HTTP_PORT}"
fi
echo ""
echo "-------------------------------------------"
echo "  Next steps"
echo "-------------------------------------------"
echo ""
echo "  1. Start Betterlytics:"
echo ""
echo "     docker compose up -d --wait"
echo ""
echo "  2. Open ${ACCESS_URL} in your browser"
echo "     and create your account."
echo "     The first account created becomes"
echo "     the admin."
echo ""
echo "-------------------------------------------"
echo "  Optional configuration"
echo "-------------------------------------------"
echo ""
echo "  Geolocation (IP to country/city):"
echo "    Requires a free MaxMind account."
echo "    Set these in your .env file:"
echo "      ENABLE_GEOLOCATION=true"
echo "      MAXMIND_ACCOUNT_ID=your_id"
echo "      MAXMIND_LICENSE_KEY=your_key"
echo ""
echo "  Email notifications:"
echo "    Set ENABLE_EMAILS=true and configure"
echo "    SMTP or MailerSend in your .env file."
echo "    SMTP_FROM is required for both, as"
echo "    \"Name <address>\" or a bare address."
echo ""
echo "  Session replay (enabled by default):"
echo "    Recordings are stored in ClickHouse."
echo "    To disable, add SESSION_REPLAYS_ENABLED=false"
echo "    to your .env file."
echo "    To use your own S3-compatible storage instead,"
echo "    see the S3_* options in .env.example."
echo ""
echo "  See .env.example for all available options."
echo ""
