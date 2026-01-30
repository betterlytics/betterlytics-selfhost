FROM caddy:2-alpine
COPY Caddyfile.https /etc/caddy/Caddyfile.https
COPY Caddyfile.http /etc/caddy/Caddyfile.http
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
