#!/bin/sh

# 主逻辑
core_xray=false
core_sing=false
core_hysteria2=false

# 设置日志等级，默认为info
log_level=${LogLevel:-info}

# 检查必须的环境变量
check_required_env() {
    missing_vars=""
    
    # 调试输出环境变量值
    echo "调试信息："
    echo "ApiHost: $ApiHost"
    echo "ApiKey: $ApiKey"
    echo "NodeID: $NodeID"
    echo "NodeType: $NodeType"
    echo "CoreType: $CoreType"
    
    if [ -z "$ApiHost" ]; then
        missing_vars="$missing_vars ApiHost"
    fi
    if [ -z "$ApiKey" ]; then
        missing_vars="$missing_vars ApiKey"
    fi
    if [ -z "$NodeID" ]; then
        missing_vars="$missing_vars NodeID"
    fi
    if [ -z "$NodeType" ]; then
        missing_vars="$missing_vars NodeType"
    fi
    if [ -z "$CoreType" ]; then
        missing_vars="$missing_vars CoreType"
    fi

    if [ -n "$missing_vars" ]; then
        echo "错误：缺少必要的环境变量：$missing_vars"
        exit 1
    fi

    # 检查CoreType是否有效
    case "$CoreType" in
        "xray"|"sing"|"hysteria2") 
            echo "CoreType = $CoreType 验证通过"
            ;;
        *)
            echo "错误：无效的核心类型：$CoreType"
            echo "支持的核心类型：xray, sing, hysteria2"
            exit 1
            ;;
    esac
}

# 检查系统是否有 IPv6 地址
check_ipv6_support() {
    if ip -6 addr | grep -q "inet6"; then
        echo "1"  # 支持 IPv6
    else
        echo "0"  # 不支持 IPv6
    fi
}

# 根据核心类型选择支持的协议
case "$CoreType" in
    "xray")
        core="xray"
        core_xray=true
        case "$NodeType" in
            "vless"|"vmess"|"shadowsocks"|"trojan") ;;
            *)
                echo "错误：xray核心不支持该协议：$NodeType"
                echo "xray核心支持的协议：vless, vmess, shadowsocks, trojan"
                exit 1
                ;;
        esac
        ;;
    "sing")
        core="sing"
        core_sing=true
        case "$NodeType" in
            "vless"|"vmess"|"shadowsocks"|"trojan"|"hysteria"|"hysteria2"|"tuic"|"anytls") ;;
            *)
                echo "错误：sing-box核心不支持该协议：$NodeType"
                echo "sing-box核心支持的协议：vless, vmess, shadowsocks, trojan, hysteria, hysteria2, tuic, anytls"
                exit 1
                ;;
        esac
        ;;
    "hysteria2")
        core="hysteria2"
        core_hysteria2=true
        if [ "$NodeType" != "hysteria2" ]; then
            echo "错误：hysteria2核心仅支持hysteria2协议"
            exit 1
        fi
        ;;
    *)
        echo "错误：未知的核心类型：$CoreType"
        echo "支持的核心类型：xray, sing, hysteria2"
        exit 1
        ;;
esac

# 设置证书模式
certmode=${CertMode:-none}
certdomain=${CertDomain:-qisuyun.xyz}

# 生成核心配置
generate_core_config() {
    cores_config=""
    if [ "$core_xray" = true ]; then
        cores_config=$(cat <<EOF
{
    "Type": "xray",
    "Log": {
        "Level": "$log_level",
        "ErrorPath": "/etc/V2bX/v2bx.log"
    },
    "OutboundConfigPath": "/etc/V2bX/custom_outbound.json",
    "RouteConfigPath": "/etc/V2bX/route.json"
}
EOF
        )
        if [ "$core_sing" = true ] || [ "$core_hysteria2" = true ]; then
            cores_config="$cores_config,"
        fi
    fi
    if [ "$core_sing" = true ]; then
        cores_config="$cores_config"$(cat <<EOF
{
    "Type": "sing",
    "Log": {
        "Level": "$log_level",
        "Timestamp": true
    },
    "NTP": {
        "Enable": true,
        "Server": "time.apple.com",
        "ServerPort": 0
    },
    "Experimental": {
        "ClashApi": {
            "ExternalController": "127.0.0.1:9090",
            "ExternalUI": "",
            "Secret": "",
            "DefaultMode": "rule",
            "StoreSelected": true,
            "StoreFakeIP": true
        }
    },
    "OriginalPath": "/etc/V2bX/sing_origin.json"
}
EOF
        )
        if [ "$core_hysteria2" = true ]; then
            cores_config="$cores_config,"
        fi
    fi
    if [ "$core_hysteria2" = true ]; then
        cores_config="$cores_config"$(cat <<EOF
{
    "Type": "hysteria2",
    "Log": {
        "Level": "$log_level"
    },
    "Hysteria2ConfigPath": "/etc/V2bX/hy2config.yaml",
    "Obfs": {
        "Type": "salamander",
        "Salamander": {
            "Password": "$(head -c 16 /dev/urandom | xxd -p)"
        }
    },
    "IgnoreClientBandwidth": false,
    "Masquerade": {
        "Type": "proxy",
        "Proxy": {
            "URL": "https://www.google.com",
            "RewriteHost": true
        }
    },
    "UdpIdleTimeout": 60,
    "Network": [
        "udp","tcp"
    ]
}
EOF
        )
    fi
    cores_config="[$cores_config]"
    
    # 打印生成的核心配置
    echo "生成的核心配置内容："
    echo "$cores_config"
}

# 生成节点配置并写入最终配置文件
generate_node_config() {
    ipv6_support=$(check_ipv6_support)
    listen_ip="0.0.0.0"
    if [ "$ipv6_support" -eq 1 ]; then
        listen_ip="::"
    fi

    node_config=$(cat <<EOF
{
    "Core": "$core",
    "ApiHost": "$ApiHost",
    "ApiKey": "$ApiKey",
    "NodeID": $NodeID,
    "NodeType": "$NodeType",
    "Timeout": 30,
    "ListenIP": "$listen_ip",
    "SendIP": "0.0.0.0",
    "DeviceOnlineMinTraffic": 1000,
    "EnableProxyProtocol": false,
    "EnableUot": true,
    "EnableTFO": true,
    "DNSType": "UseIPv4",
    "CertConfig": {
        "CertMode": "$certmode",
        "RejectUnknownSni": false,
        "CertDomain": "$certdomain",
        "CertFile": "/etc/V2bX/fullchain.cer",
        "KeyFile": "/etc/V2bX/cert.key",
        "Email": "v2bx@github.com",
        "Provider": "cloudflare",
        "DNSEnv": {
            "CF_API_EMAIL": "$CF_API_EMAIL",
            "CF_API_KEY": "$CF_API_KEY"
        }
    }
}
EOF
    )
    # 打印生成的节点配置
    echo "生成的节点配置如下："
    echo "$node_config"

    # 直接生成最终配置文件
    final_config=$(cat <<EOF
{
    "Log": {
        "Level": "$log_level",
        "Output": ""
    },
    "Cores": $cores_config,
    "Nodes": [$node_config]
}
EOF
    )

    # 写入配置文件
    echo "$final_config" > /etc/V2bX/config.json
}

# 执行流程
echo "开始检查环境变量..."
check_required_env
echo "环境变量检查完成"

echo "开始生成核心配置..."
generate_core_config
echo "核心配置生成完成"

echo "开始生成节点配置..."
generate_node_config
echo "节点配置生成完成"

echo "V2bX 配置文件已生成，开始启动服务"

while true; do
    /usr/local/bin/V2bX server --config /etc/V2bX/config.json
    sleep 10
done