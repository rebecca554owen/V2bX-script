# 可选 ghcr.io/wyx2685/v2bx:dev_new
FROM ghcr.io/rebecca554owen/v2bx:dev_new
WORKDIR /app
COPY entrypoint.sh /app/entrypoint.sh
RUN apk --update --no-cache add ca-certificates \
    && chmod +x /app/entrypoint.sh
ENTRYPOINT ["/app/entrypoint.sh"]
