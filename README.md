# V2bX
A V2board node server based on Xray-Core.

一个基于Xray的V2board节点服务端，支持V2ay,Trojan,Shadowsocks协议

Find the source code here: [InazumaV/V2bX](https://github.com/InazumaV/V2bX)

如对脚本不放心，可使用此沙箱先测一遍再使用：https://killercoda.com/playgrounds/scenario/ubuntu

# 详细使用教程

[教程](https://v2bx.v-50.me/)

# 一键安装

```
wget -N https://raw.githubusercontent.com/wyx2685/V2bX-script/master/install.sh && bash install.sh
```
# docker 启动命令

```
docker run -d --name v2bx --network host --restart always \
  -e CoreType=${CoreType:-xray} \
  -e ApiHost=your_api_host \
  -e ApiKey=your_api_key \
  -e NodeID=1 \
  -e NodeType=${NodeType:-shadowsocks} \
  ghcr.io/rebecca554owen/v2bx:latest
```
