# 可选 ghcr.io/wyx2685/v2bx:dev_new
FROM ghcr.io/rebecca554owen/v2bx:dev_new
WORKDIR /app
COPY entrypoint.sh /app/entrypoint.sh
RUN apk --update --no-cache add ca-certificates curl \
    && curl -L "https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geoip.dat" -o /etc/V2bX/geoip.dat \
    && curl -L "https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geosite.dat" -o /etc/V2bX/geosite.dat \
    && chmod +x /app/entrypoint.sh
ENTRYPOINT ["/app/entrypoint.sh"]
