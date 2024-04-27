#!/bin/bash
# Description: 
# 自用脚本,仅测试 Debian / Ubuntu 平台
V2bX_path="/etc/V2bX"
V2bX_config=${V2bX_path}/docker-compose.yml

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
export PATH=$PATH:/usr/local/bin

pre_check() {
    if [ -e /etc/os-release ]; then
        if grep -qi "alpine" /etc/os-release; then
            os_alpine='1'
        fi
    fi
    
    if [ "${os_alpine}" != "1" ] && ! command -v systemctl >/dev/null 2>&1; then
        echo "不支持此系统：未找到 systemctl 命令"
        exit 1
    fi

    if [[ ${EUID} -ne 0 ]]; then
        echo -e "错误: 必须使用root用户运行此脚本!n"
        exit 1
    fi
    
    local ip_info
    ip_info=$(curl -m 10 -s https://ipapi.co/json)

    if [[ $? -ne 0 ]]; then
        echo "警告: 无法从 ipapi.co 获取IP信息。您需要手动指定是否使用中国镜像。"
        # 回退机制：手动输入
        read -p "您是否在中国？如果是请输入 'Y',否则输入 'N': [Y/n] " input
        input=${input:-Y} # 默认为 'Y'
    else
        if echo "${ip_info}" | grep -q 'China'; then
            echo "根据 ipapi.co 提供的信息，当前 IP 可能在中国。"
            input='Y'
        else
            input='N'
        fi
    fi

    case ${input} in
        [yY][eE][sS]|[yY])
            echo "使用中国镜像。"
            CN=true
            ;;
        [nN][oO]|[nN])
            echo "不使用中国镜像。"
            CN=false
            ;;
        *)
            echo "无效输入...默认不使用中国镜像。"
            CN=false
            ;;
    esac

    if [[ "${CN}" = false ]]; then
        Get_Docker_URL="get.docker.com"
        Get_Docker_Argu=" "
    else
        Get_Docker_URL="get.docker.com"  # 中国镜像 URL
        Get_Docker_Argu=" -s docker --mirror Aliyun"   # 中国镜像参数
    fi
}

before_show_menu() {
    # 显示提示信息并等待用户按下回车键
    echo -e "n${yellow}* 按回车返回主菜单 *${plain}"
    read -r _temp
    
    # 调用主菜单显示函数
    show_menu
}

install_base() {
    # 打印开始安装的消息
    echo "开始安装基础软件包..."

    # 更新软件源
    echo "更新软件包数据源..."
    apt-get update -y

    # 安装基础软件包，可以根据需要添加或删除软件包
    echo "正在安装软件包: sudo vim, curl, wget"
    apt-get install -y sudo vim curl wget

    # 检查软件包是否安装成功
    local packages=(sudo vim curl wget)
    for pkg in "${packages[@]}"; do
        if command -v "$pkg" >/dev/null 2>&1; then
            echo "$pkg 已成功安装."
        else
            echo "警告: 安装 $pkg 失败，继续安装其他软件包..."
        fi
    done

    # 打印完成消息
    echo "基础软件包安装完成。"
}

install_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "正在安装 Docker"
        if ! bash <(curl -sL "https://${Get_Docker_URL}") "${Get_Docker_Argu}"; then
            echo -e "下载脚本失败，请检查本机能否连接 ${Get_Docker_URL}${plain}"
            return 1
        fi
        sudo systemctl enable docker.service
        sudo systemctl start docker.service
        echo -e "${green}Docker${plain} 安装成功"
    else
        echo -e "${yellow}Docker 已安装${plain}"
    fi
}

install_V2bX() {
    pre_check
    install_base
    install_docker
    echo -e "> 安装V2bX"
    if [ ! -d ${V2bX_config} ]; then
        mkdir -p ${V2bX_path}
    else
        echo "您可能已经安装过V2bX,重复安装会覆盖数据,请注意。"
        read -e -r -p "是否退出安装? [Y/n] " input
        case ${input} in
        [yY][eE][sS] | [yY])
            echo "退出安装"
            exit 0
            ;;
        [nN][oO] | [nN])
            echo "继续安装"
            ;;
        *)
            echo "退出安装"
            exit 0
            ;;
        esac
    fi
    chmod 755 -R ${V2bX_path}
    modify_V2bX_config 0
    before_show_menu
}

modify_V2bX_config() {
    # 先检查配置文件是否存在
    if [ -f "${V2bX_config}" ]; then
        # 存在，则使用vim编辑
        echo "配置文件已存在，正在打开编辑..."
        vim ${V2bX_config}
        echo -e "配置 ${green}修改成功，请稍等重启生效${plain}"
    else
        # 不存在，则进行创建流程    
    echo -e "开始设置V2bX参数"
    echo -e "请选择节点核心类型："
    options=("xray" "singbox","hysteria2")
    select Core_type in "${options[@]}"; do
        case $Core_type in
            "xray")
                echo "你选择了 xray"
                break
                ;;
            "singbox")
                echo "你选择了 singbox"
                break
                ;;
            "hysteria2")
                echo "你选择了 hysteria2"
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done

    while true; do
        read -rp "请输入节点Node ID：" NodeID
        # 判断NodeID是否为正整数
        if [[ "$NodeID" =~ ^[0-9]+$ ]]; then
            break  # 输入正确，退出循环
        else
            echo "错误：请输入正确的数字作为Node ID。"
        fi
    done
    if [ "$Core_type" = hysteria2 ] ; then
        NodeType="hysteria2"
    else
        echo -e "请选择节点传输协议："
        echo -e "1. Shadowsocks"
        echo -e "2. Vless"
        echo -e "3. Vmess"
        if [ "$Core_type" == singbox ]; then
            echo -e "4. Hysteria"
            echo -e "5. Hysteria2"
        fi
        if [ "$Core_type" == hysteria2 ]; then
            echo -e "5. Hysteria2"
        fi
        echo -e "6. Trojan" 
        read -rp "请输入：" NodeType
        case "$NodeType" in
            1 ) NodeType="shadowsocks" ;;
            2 ) NodeType="vless" ;;
            3 ) NodeType="vmess" ;;
            4 ) NodeType="hysteria" ;;
            5 ) NodeType="hysteria2" ;;
            6 ) NodeType="trojan" ;;
            * ) NodeType="shadowsocks" ;;
        esac
    fi
    if [ $NodeType == "vless" ]; then
        read -rp "请选择是否为reality节点？(y/n)" isreality
    fi
    CertMode="none"
    CertDomain="icloud.com"
    if [ "$isreality" != "y" ] && [ "$isreality" != "Y" ]; then
        read -rp "请选择是否进行TLS配置？(y/n)" istls
        if [ "$istls" == "y" ] || [ "$istls" == "Y" ]; then
            echo -e "请选择证书申请模式："
            echo -e "1. http模式自动申请，节点域名已正确解析"
            echo -e "2. dns模式自动申请，需填入正确域名服务商API参数"
            echo -e "3. self模式，自签证书或提供已有证书文件"
            read -rp "请输入：" CertMode
            case "$CertMode" in
                1 ) CertMode="http" ;;
                2 ) CertMode="dns" ;;
                3 ) CertMode="self" ;;
            esac
            read -rp "请输入节点证书域名(example.com)]：" CertDomain
            if [ $CertMode != "http" ]; then
                echo -e "请手动修改配置文件后重启V2bX！"
            fi
        fi
    fi
    read -rp "请输入机场网址：" ApiHost
    read -rp "请输入面板对接API Key：" ApiKey

    cat >${V2bX_config} <<EOF
services:
  v2bx:
    image: ghcr.io/rebecca554owen/v2bx:latest
    container_name: v2bx
    network_mode: host # host 模式方便监听ipv4/ipv6。
    restart: always
    volumes:
        - /etc/V2bX/:/etc/V2bX/ # 挂载目录用于解决证书申请。
    environment:
        - Core=${Core}
        - ApiHost=${ApiHost}
        - ApiKey=${ApiKey}
        - NodeID=${NodeID}
        - NodeType=${NodeType} # Node type: V2ray, Shadowsocks，Trojan
        # - CertMode=http # 可选 none, file, http, tls, dns.
        # - CertDomain=xboard.com
        # - Provider=cloudflare
        # - CLOUDFLARE_EMAIL=
        # - CLOUDFLARE_API_KEY=  # 这里务必使用全局API key
EOF
        echo -e "配置文件创建成功。"
    fi
    restart_V2bX_update  # 用来重启V2bX并应用更新
    before_show_menu      # 用来返回主菜单
}

restart_V2bX_update() {
    echo -e "> 重启并更新V2bX"
    if [ -d "${V2bX_path}" ]; then
        cd "${V2bX_path}" || { echo "错误：无法进入V2bX目录 ${V2bX_path}"; return 1; }

        # 检查是否安装了 docker-compose 命令
        if command -v docker-compose >/dev/null 2>&1; then
            docker-compose pull && docker-compose down && docker-compose up -d
            echo -e "${green}V2bX 重启成功并应用了更新。${plain}"
        # 检查是否安装了 docker 命令，同时支持 compose 子命令
        elif command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
            docker compose pull && docker compose down && docker compose up -d
            echo -e "${green}V2bX 重启成功并应用了更新。${plain}"
        else
            echo -e "${red}错误：未找到 docker-compose 或 docker 命令。${plain}"
            return 1
        fi
    else
        echo -e "${red}错误：V2bX 配置路径 ${V2bX_path} 不存在。${plain}"
        return 1
    fi
    docker image prune -f -a
    # 调用返回主菜单函数
    before_show_menu
}

start_V2bX() {
    echo -e "> 启动V2bX"
    cd "${V2bX_path}" || exit
    if command -v docker-compose >/dev/null 2>&1; then
        docker-compose up -d
    elif command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        docker compose up -d
    else
        echo "未找到 Docker 或 Docker Compose 命令。"
        return 1
    fi
    before_show_menu
}

stop_V2bX() {
    echo -e "> 停止V2bX"
    cd "${V2bX_path}" || exit
    if command -v docker-compose >/dev/null 2>&1; then
        docker-compose down
    elif command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        docker compose down
    else
        echo "未找到 Docker 或 Docker Compose 命令。"
        return 1
    fi
    before_show_menu
}

show_V2bX_log() {
    echo -e "> 获取 V2bX 日志"
    cd "${V2bX_path}" || exit
    if command -v docker-compose >/dev/null 2>&1; then
        docker-compose logs -f
    elif command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        docker compose logs -f
    else
        echo "未找到 Docker 或 Docker Compose 命令。"
        return 1
    fi
    before_show_menu
}

uninstall_V2bX() {
    echo -e "> 卸载V2bX"
    if command -v docker-compose >/dev/null 2>&1; then
        cd "${V2bX_path}" && docker-compose down
    elif command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        cd "${V2bX_path}" && docker compose down
    else
        echo "Docker 或 Docker Compose 未安装。"
        return 1
    fi
    if [[ -d "${V2bX_path}" ]]; then
        rm -rf "${V2bX_path}"
    else
        echo "V2bX 安装目录不存在。"
    fi
    docker rmi -f ghcr.io/rebecca554owen/V2bX >/dev/null 2>&1 || echo "Docker 镜像可能已被删除。"
    before_show_menu
}

show_menu() {
    echo -e "
    ${green}自用V2bX脚本${plain} ${red}${plain}
    ————————————————
    ${green}1.${plain} 安装V2bX
    ${green}2.${plain} 修改V2bX配置
    ${green}3.${plain} 启动V2bX
    ${green}4.${plain} 停止V2bX
    ${green}5.${plain} 更新V2bX
    ${green}6.${plain} 查看V2bX日志
    ${green}7.${plain} 卸载V2bX
    ————————————————
    ${green}0.${plain}  退出脚本
    "
    echo && read -r -ep "请输入选择" num
    case ${num} in
    0)
        exit 0
        ;;
    1)
        install_V2bX
        ;;
    2)
        modify_V2bX_config
        ;;
    3)
        start_V2bX
        ;;
    4)
        stop_V2bX
        ;;
    5)
        restart_V2bX_update
        ;;
    6)
        show_V2bX_log
        ;;
    7)
        uninstall_V2bX
        ;;
    *)
        echo -e "你没有选任何一个选项"
        ;;
    esac
}

show_menu
