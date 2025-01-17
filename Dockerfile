# 使用官方 V2bX 镜像作为基础镜像，设置默认tag为latest
ARG TAG=latest
FROM ghcr.io/wyx2685/v2bx:${TAG}

# 设置工作目录
WORKDIR /app

# 复制入口脚本到容器
COPY entrypoint.sh /app/entrypoint.sh

# 复制示例配置文件到容器
COPY /example/ /etc/V2bX/

# 安装必要的证书并设置脚本可执行权限
RUN apk --update --no-cache add ca-certificates curl \
    && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && mkdir -p /etc/V2bX/ \
    && curl -L "https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geoip.dat" -o /etc/V2bX/geoip.dat \
    && curl -L "https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geosite.dat" -o /etc/V2bX/geosite.dat \
    && chmod +x /app/entrypoint.sh

# 设置容器启动时执行的入口脚本
ENTRYPOINT ["/app/entrypoint.sh"]
