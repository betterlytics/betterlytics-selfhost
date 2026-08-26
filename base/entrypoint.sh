#!/bin/bash
set -e

. /secrets-env.sh

if [ "$HTTP_SCHEME" = "https" ] && [ -n "$SSL_DOMAIN" ]; then
    mkdir -p /var/www/certbot
    if [ ! -f "/etc/letsencrypt/live/$SSL_DOMAIN/fullchain.pem" ]; then
        echo "Obtaining SSL certificate for $SSL_DOMAIN..."
        cp /etc/nginx/templates/nginx.conf /etc/nginx/conf.d/default.conf
        nginx
        if [ -n "$SSL_EMAIL" ]; then
            CERTBOT_EMAIL_FLAG="--email $SSL_EMAIL"
        else
            CERTBOT_EMAIL_FLAG="--register-unsafely-without-email"
        fi
        if ! certbot certonly --webroot --non-interactive --agree-tos \
            $CERTBOT_EMAIL_FLAG \
            -d "$SSL_DOMAIN" \
            -w /var/www/certbot; then
            nginx -s stop
            echo "Failed to obtain certificate"
            exit 0
        fi
        nginx -s stop
    fi

    echo "Configuring nginx with SSL..."
    certbot renew
    
    export SSL_DOMAIN
    envsubst '${SSL_DOMAIN}' < /etc/nginx/templates/nginx-ssl.conf > /etc/nginx/conf.d/default.conf
else
    echo "Configuring nginx without SSL..."
    cp /etc/nginx/templates/nginx.conf /etc/nginx/conf.d/default.conf
fi

echo "Starting services..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/betterlytics.conf
