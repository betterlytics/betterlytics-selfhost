#!/bin/sh
set -e

# -----------------------------------------------
# Betterlytics Self-Hosted Setup Script
# -----------------------------------------------

ENV_FILE=".env"

# --- Helpers ---

generate_secret() {
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$1"
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

validate_email() {
    case "$1" in
        *@*.*)
            ;;
        *)
            echo "  Error: Invalid email address."
            return 1
            ;;
    esac
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
            printf "  > %s  —  %s\r\n" "$_ml" "$_md"
        else
            printf "    %s  —  %s\r\n" "$_ml" "$_md"
        fi
        _menu_i=$((_menu_i + 1))
    done

    while true; do
        # Read a single character
        _key=$(dd bs=1 count=1 2>/dev/null)

        if [ "$_key" = "$(printf '\003')" ]; then
            # Ctrl+C — restore terminal and exit
            stty "$_menu_old_stty"
            printf "\r\n"
            exit 130
        elif [ "$_key" = "$(printf '\033')" ]; then
            # Escape sequence — read next two chars
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
                printf "  > %s  —  %s\033[K\r\n" "$_ml" "$_md"
            else
                printf "    %s  —  %s\033[K\r\n" "$_ml" "$_md"
            fi
            _menu_i=$((_menu_i + 1))
        done
    done

    # Restore terminal
    stty "$_menu_old_stty"

    MENU_RESULT=$_menu_sel
}

# --- Pre-flight check ---

if [ -f "$ENV_FILE" ]; then
    echo ""
    echo "  A .env file already exists."
    echo "  (Use ▲/▼ arrow keys, then press Enter)"
    echo ""

    menu_select \
        "Cancel"    "Keep the current .env and exit" \
        "Overwrite" "Replace the existing configuration"

    if [ "$MENU_RESULT" -eq 0 ]; then
        echo ""
        echo "  Aborted."
        exit 0
    fi
fi

# =============================================
#  Welcome
# =============================================

echo ""
echo "==========================================="
echo "  Betterlytics  —  Self-Hosted Setup"
echo "==========================================="
echo ""

# =============================================
#  Step 1: Deployment Mode
# =============================================

echo "  Choose a deployment mode:"
echo "  (Use ▲/▼ arrow keys, then press Enter)"
echo ""

menu_select \
    "Standalone" "Automatic HTTPS via Let's Encrypt" \
    "Basic"      "HTTP only — for local use or behind a reverse proxy"

case "$MENU_RESULT" in
    0) DEPLOY_MODE="standalone" ;;
    1) DEPLOY_MODE="basic" ;;
esac

# =============================================
#  Step 2: Domain & Network
# =============================================

echo ""
echo "-------------------------------------------"
echo "  Domain & Network"
echo "-------------------------------------------"
echo ""

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

else
    HTTP_SCHEME="http"
    HTTPS_PORT=443
    BIND_ADDRESS="127.0.0.1"

    while true; do
        printf "  Domain name (default: localhost): "
        read -r DOMAIN
        if [ -z "$DOMAIN" ]; then
            DOMAIN="localhost"
            break
        fi
        validate_domain "$DOMAIN" && break
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
fi

# =============================================
#  Step 3: Admin Account
# =============================================

echo ""
echo "-------------------------------------------"
echo "  Admin Account"
echo "-------------------------------------------"
echo ""

while true; do
    printf "  Email: "
    read -r ADMIN_EMAIL
    validate_not_empty "$ADMIN_EMAIL" "Admin email" && validate_email "$ADMIN_EMAIL" && break
done

while true; do
    printf "  Password: "
    stty -echo
    read -r ADMIN_PASSWORD
    stty echo
    echo ""
    validate_not_empty "$ADMIN_PASSWORD" "Admin password" && break
done

# =============================================
#  Generate & Write Configuration
# =============================================

SECRET_BASE=$(generate_secret 64)

cat > "$ENV_FILE" <<EOF
# ===========================================
# Betterlytics Self-Hosted Configuration
# Generated by setup.sh
# ===========================================

# --- Admin Account ---
ADMIN_EMAIL="${ADMIN_EMAIL}"
ADMIN_PASSWORD="${ADMIN_PASSWORD}"

# --- General ---
DEFAULT_LANGUAGE="en"
ENABLE_UPTIME_MONITORING="false"

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

# Build the access URL
if [ "$DEPLOY_MODE" = "standalone" ]; then
    ACCESS_URL="https://${DOMAIN}"
elif [ "$DOMAIN" = "localhost" ] || echo "$DOMAIN" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
    if [ "$HTTP_PORT" = "80" ]; then
        ACCESS_URL="http://${DOMAIN}"
    else
        ACCESS_URL="http://${DOMAIN}:${HTTP_PORT}"
    fi
else
    ACCESS_URL="https://${DOMAIN}"
fi

echo ""
echo "==========================================="
echo "  Setup Complete"
echo "==========================================="
echo ""
echo "  Mode:       $([ "$DEPLOY_MODE" = "standalone" ] && echo "Standalone (automatic HTTPS)" || echo "Basic (HTTP)")"
echo "  Domain:     ${DOMAIN}"
echo "  Admin:      ${ADMIN_EMAIL}"
echo "  URL:        ${ACCESS_URL}"
echo ""
echo "-------------------------------------------"
echo "  Next steps"
echo "-------------------------------------------"
echo ""
echo "  1. Start Betterlytics:"
echo ""
echo "     docker compose up -d"
echo ""
echo "  2. Open ${ACCESS_URL} in your browser"
echo "     and log in with your admin credentials."
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
echo ""
echo "  See .env.example for all available options."
echo ""
