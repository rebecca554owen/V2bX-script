#!/bin/sh

if [ -z "$NodeID" ]; then
  exit 1
fi

Level=${Level:-none}
Core_type=${Core_type:-singbox}

DnsConfigPath=${DnsConfigPath:-}
OriginalPath=${OriginalPath:-}
RouteConfigPath=${RouteConfigPath:-}
InboundConfigPath=${InboundConfigPath:-}
OutboundConfigPath=${OutboundConfigPath:-}

ApiHost=${ApiHost:-http://127.0.0.1:7001}
ApiKey=${ApiKey:-xboardisbest}
NodeID=${NodeID:-1}
NodeType=${NodeType:-Shadowsocks}
DomainStrategy=${DomainStrategy:-prefer_ipv4}

CertMode=${CertMode:-none}
CertDomain=${CertDomain:-xboard.com}
Provider=${Provider:-cloudflare}
CLOUDFLARE_EMAIL=${CLOUDFLARE_EMAIL:-}
CLOUDFLARE_API_KEY=${CLOUDFLARE_API_KEY:-}

cat > /etc/V2bX/config.json <<EOF
{
  "Log": {
    "Level": "${Level}",
    "Output": ""
  },
  "Cores": [
    {
      "Type": "${Core_type}",
      "Log": {
        "Level": "${Level}",
        "Timestamp": true
      },
      "DnsConfigPath": "${DnsConfigPath}",
      "OriginalPath": "${OriginalPath}",
      "RouteConfigPath": "${RouteConfigPath}",
      "InboundConfigPath": "${InboundConfigPath}",
      "OutboundConfigPath": "${OutboundConfigPath}",
      "NTP": {
        "Enable": true,
        "Server": "time.apple.com",
        "ServerPort": 0
      }
    }
  ],
  "Nodes": 
  [
    {
      "Core": "${Core_type}",
      "ApiHost": "${ApiHost}",
      "ApiKey": "${ApiKey}",
      "NodeID": ${NodeID},
      "NodeType": "${NodeType}",
      "Timeout": 30,
      "ListenIP": "0.0.0.0",
      "SendIP": "0.0.0.0",
      "EnableProxyProtocol": false,
      "EnableDNS": true,
      "DomainStrategy": "${DomainStrategy}",
      "LimitConfig": {
        "EnableRealtime": false,
        "SpeedLimit": 0,
        "IPLimit": 0,
        "ConnLimit": 0,
        "EnableDynamicSpeedLimit": false,
        "DynamicSpeedLimitConfig": {
          "Periodic": 60,
          "Traffic": 1000,
          "SpeedLimit": 100,
          "ExpireTime": 60
          }
        },
        "CertConfig": {
        "CertMode": "${CertMode}",
        "RejectUnknownSni": false,
        "CertDomain": "${CertDomain}",
        "CertFile": "/etc/V2bX/cert/${CertDomain}.pem",
        "KeyFile": "/etc/V2bX/cert/${CertDomain}.key",
        "Email": "admin@qq.com",
        "Provider": "${Provider}",
        "DNSEnv": {
          "CLOUDFLARE_EMAIL": "${CLOUDFLARE_EMAIL}",
          "CLOUDFLARE_API_KEY": "${CLOUDFLARE_API_KEY}"
        }
      }
    }
  ]
}
EOF

while true; do V2bX --config /etc/V2bX/config.json; sleep 5; done
