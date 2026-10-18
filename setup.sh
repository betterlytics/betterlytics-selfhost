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

# Basic mode always yields https://DOMAIN as PUBLIC_URL; auth rejects any other origin.
validate_not_ip() {
    if printf '%s\n' "$1" | grep -qE '^[0-9]{1,3}(\.[0-9]{1,3}){3}(:[0-9]+)?$|^\[|:.*:'; then
        echo "  Error: Basic mode needs a domain name (e.g. analytics.example.com) that your"
        echo "         reverse proxy serves over HTTPS. Logins fail when Betterlytics is opened"
        echo "         by IP address or over plain HTTP. For that setup, see"
        echo "         \"Plain HTTP or IP Access\" in the Self-Hosting Guide:"
        echo "         https://betterlytics.io/docs/installation/self-hosting"
        return 1
    fi
}

# Mirrors the container's PUBLIC_URL rules. $1 = host[:port], $2 = default port of the scheme.
validate_host_port() {
    case "$1" in
        */*|*\?*|*\#*|*@*)
            echo "  Error: Enter only the hostname, optionally followed by :port."
            return 1
            ;;
    esac
    case "$1" in
        *:*)
            _port="${1##*:}"
            case "$_port" in
                ''|*[!0-9]*|0*|??????*)
                    echo "  Error: The port must be a number between 1 and 65535."
                    return 1
                    ;;
            esac
            if [ "$_port" = "$2" ]; then
                echo "  Error: Leave out :$2, it is the default port."
                return 1
            fi
            ;;
    esac
}

# Standalone gets a certificate for exactly this name.
validate_tls_host() {
    case "$1" in
        */*|*\?*|*\#*|*@*)
            echo "  Error: Enter only the hostname."
            return 1
            ;;
        *:*)
            echo "  Error: Standalone mode needs a hostname without a port."
            return 1
            ;;
        localhost|*.localhost)
            echo "  Error: Standalone mode needs a public hostname, not localhost."
            return 1
            ;;
    esac
    if printf '%s\n' "$1" | grep -qE '^[0-9]{1,3}(\.[0-9]{1,3}){3}$'; then
        echo "  Error: Standalone mode needs a hostname, not an IP address."
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

if [ "$DEPLOY_MODE" = "standalone" ]; then
    TLS="auto"
    HTTP_PORT=80
    BIND_ADDRESS="0.0.0.0"

    while true; do
        printf "  Domain name (e.g. analytics.example.com): "
        read -r DOMAIN
        validate_not_empty "$DOMAIN" "Domain" && validate_domain "$DOMAIN" && validate_tls_host "$DOMAIN" && break
    done
    PUBLIC_URL="https://${DOMAIN}"

elif [ "$DEPLOY_MODE" = "basic" ]; then
    TLS="off"
    BIND_ADDRESS="127.0.0.1"

    echo "  Use the hostname your reverse proxy serves over HTTPS."
    echo "  Add :port if the proxy serves HTTPS on a port other than 443."
    echo ""
    while true; do
        printf "  Domain name (e.g. analytics.example.com): "
        read -r DOMAIN
        validate_not_empty "$DOMAIN" "Domain" && validate_domain "$DOMAIN" && validate_not_ip "$DOMAIN" && validate_host_port "$DOMAIN" 443 && break
    done
    PUBLIC_URL="https://${DOMAIN}"

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
    TLS="off"
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

    # The container rejects an explicit default port in PUBLIC_URL.
    if [ "$HTTP_PORT" = "80" ]; then
        PUBLIC_URL="http://localhost"
    else
        PUBLIC_URL="http://localhost:${HTTP_PORT}"
    fi
fi

# =============================================
#  Generate & Write Configuration
# =============================================

SECRET_BASE=$(generate_secret 64)
if [ "${#SECRET_BASE}" -ne 64 ]; then
    echo "  Error: could not generate a random secret. Nothing was written."
    exit 1
fi

# --- Write docker-compose.override.yml ---
# Written before .env: if this fails, no .env exists and setup can be run again.

OVERRIDE_FILE="docker-compose.override.yml"
if [ "$DEPLOY_MODE" = "standalone" ]; then
    # BL_HTTPS_PUBLISHED tells the TLS=auto start-up check (run by init too) that 443 is mapped.
    cat > "$OVERRIDE_FILE" <<EOF
services:
  betterlytics-selfhost:
    ports:
      - "${BIND_ADDRESS}:443:443"
    environment:
      - BL_HTTPS_PUBLISHED=true
  betterlytics-init:
    environment:
      - BL_HTTPS_PUBLISHED=true
EOF
else
    rm -f "$OVERRIDE_FILE"
fi

# .env holds SECRET_BASE: owner-only from the first byte, chmod as a backstop.
(
umask 077
cat > "$ENV_FILE" <<EOF
# ===========================================
# Betterlytics Self-Hosted Configuration
# Generated by setup.sh
# ===========================================

# --- Geolocation ---
ENABLE_GEOLOCATION="false"
MAXMIND_ACCOUNT_ID="xxxxx"
MAXMIND_LICENSE_KEY="xxxxx"

# --- Address ---
PUBLIC_URL="${PUBLIC_URL}"
TLS="${TLS}"

# --- Network (advanced) ---
HTTP_PORT="${HTTP_PORT}"
BIND_ADDRESS="${BIND_ADDRESS}"

# --- Secret Base ---
SECRET_BASE="${SECRET_BASE}"

EOF
if [ "$DEPLOY_MODE" = "local" ]; then
    cat >> "$ENV_FILE" <<EOF
# --- Telemetry ---
# Off for "Try locally" installs. Set to true to send the daily instance report.
TELEMETRY_ENABLED="false"

EOF
fi
)
chmod 600 "$ENV_FILE"

# =============================================
#  Summary
# =============================================

ACCESS_URL="${PUBLIC_URL}"

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
echo "  Domain:     ${PUBLIC_URL#*://}"
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
echo "  Telemetry"
echo "-------------------------------------------"
echo ""
if [ "$DEPLOY_MODE" = "local" ]; then
    echo "  Off for this local install"
    echo "  (TELEMETRY_ENABLED=\"false\" in .env)."
    echo "  Nothing is sent. Details:"
else
    echo "  Starting 24 hours after the first start,"
    echo "  Betterlytics sends a random instance ID"
    echo "  and its version to betterlytics.io once"
    echo "  a day, so we can count installs. To turn"
    echo "  it off, add TELEMETRY_ENABLED=false to"
    echo "  .env before starting. Details:"
fi
echo ""
echo "  https://betterlytics.io/docs/installation/self-hosting#telemetry"
echo ""
echo "-------------------------------------------"
echo "  Optional configuration"
echo "-------------------------------------------"
echo ""
echo "  Geolocation, email notifications and more"
echo "  can be set up at any time. See the"
echo "  Self-Hosting Guide:"
echo ""
echo "  https://betterlytics.io/docs/installation/self-hosting"
echo ""
