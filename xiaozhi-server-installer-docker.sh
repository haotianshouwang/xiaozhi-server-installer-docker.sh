#!/bin/bash
set -uo pipefail
trap exit_confirm SIGINT

# ========================= 基础配置 =========================
# 小智服务器一键部署脚本：自动安装Docker、配置ASR/LLM/VLLM/TTS、启动服务
# 修复版本：解决语法错误、优化代码结构、提升下载稳定性
# 作者@昊天兽王 | 修复版本优化

AUTHOR="昊天兽王" 
SCRIPT_DESC="小智服务器一键部署脚本：自动安装Docker、配置ASR/LLM/VLLM/TTS、启动服务"
Version="1.0.2-fixed"

# 配置文件链接（修复重复链接问题）
CONFIG_FILE_URL="https://gh-proxy.com/https://raw.githubusercontent.com/haotianshouwang/xiaozhi-server-installer-docker.sh/refs/heads/main/config.yaml"
CONFIG_FILE_URL_BACKUP="https://gh-proxy.com/https://raw.githubusercontent.com/xinnan-tech/xiaozhi-esp32-server/refs/heads/main/xiaozhi-server/config.yaml"
CONFIG_FILE_URL_FALLBACK="https://mirror.ghproxy.com/https://raw.githubusercontent.com/xinnan-tech/xiaozhi-esp32-server/refs/heads/main/xiaozhi-server/config.yaml"
DOCKER_COMPOSE_URL="https://gh-proxy.com/https://raw.githubusercontent.com/xinnan-tech/xiaozhi-esp32-server/refs/heads/main/main/xiaozhi-server/docker-compose.yml"

MAIN_DIR="$HOME/xiaozhi-server"
CONTAINER_NAME="xiaozhi-esp32-server"
CONFIG_FILE="$MAIN_DIR/config.yaml"
OVERRIDE_CONFIG_FILE="$MAIN_DIR/data/.config.yaml"
LOCAL_ASR_MODEL_URL="https://modelscope.cn/models/iic/SenseVoiceSmall/resolve/master/model.pt"
RETRY_MAX=3
RETRY_DELAY=3

# 颜色定义
RED="\033[31m" GREEN="\033[32m" YELLOW="\033[33m" BLUE="\033[34m" PURPLE="\033[35m" CYAN="\033[36m" RESET="\033[0m" BOLD="\033[1m"

# 全局变量
CHATGLM_API_KEY=""
IS_MEMORY_SUFFICIENT=false
CPU_MODEL="" CPU_CORES="" MEM_TOTAL="" DISK_AVAIL=""
NET_INTERFACE="" NET_SPEED="" INTERNAL_IP="" EXTERNAL_IP="" OS_VERSION=""
CURRENT_DEPLOY_TYPE="" CONFIG_DOWNLOAD_NEEDED="true" USE_EXISTING_CONFIG=false SKIP_DETAILED_CONFIG=false

# ========================= 工具函数 =========================
check_root_permission() {
    echo -e "\n${CYAN}🔐 检查root权限...${RESET}"
    if [ "$EUID" -eq 0 ]; then
        echo -e "${GREEN}✅ 当前以root权限运行${RESET}"
        return 0
    elif sudo -n true 2>/dev/null; then
        echo -e "${GREEN}✅ 检测到sudo权限，可执行必要的管理操作${RESET}"
        return 0
    else
        echo -e "${RED}❌ 当前用户权限不足${RESET}"
        echo -e "${YELLOW}💡 小智服务器部署需要root权限或sudo权限${RESET}"
        echo -e "${YELLOW}方法1：sudo bash $0${RESET}"
        echo -e "${YELLOW}方法2：sudo -i && bash $0${RESET}"
        echo -e "${RED}⚠️  权限不足，无法继续部署！${RESET}"
        exit 1
    fi
}

detect_package_manager() {
    # 统一的包管理器检测逻辑
    if command -v apt-get &> /dev/null; then echo "apt"
    elif command -v yum &> /dev/null; then echo "yum"
    elif command -v dnf &> /dev/null; then echo "dnf"
    elif command -v pacman &> /dev/null; then echo "pacman"
    elif command -v zypper &> /dev/null; then echo "zypper"
    elif command -v apk &> /dev/null; then echo "apk"
    else echo "unknown"; fi
}

install_dependencies() {
    local pkg_manager=$(detect_package_manager)
    local deps=("curl" "jq" "sed" "awk")
    
    echo -e "${CYAN}🔍 检查必要工具...${RESET}"
    local missing=()
    for dep in "${deps[@]}"; do
        ! command -v "$dep" &> /dev/null && missing+=("$dep")
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠️ 安装缺少的工具: ${missing[*]}${RESET}"
        case $pkg_manager in
            apt) sudo apt-get update && sudo apt-get install -y "${missing[@]}" ;;
            yum) sudo yum install -y "${missing[@]}" ;;
            dnf) sudo dnf install -y "${missing[@]}" ;;
            pacman) sudo pacman -S --noconfirm "${missing[@]}" ;;
            zypper) sudo zypper install -y "${missing[@]}" ;;
            apk) sudo apk add "${missing[@]}" ;;
            *) echo -e "${RED}❌ 未识别的包管理器，请手动安装: ${missing[*]}${RESET}"; exit 1 ;;
        esac
        echo -e "${GREEN}✅ 工具安装完成${RESET}"
    else
        echo -e "${GREEN}✅ 所有工具已安装${RESET}"
    fi
}

install_with_package_manager() {
    local pkg_manager=$(detect_package_manager)
    # 统一的包管理器安装函数
    case $pkg_manager in
        apt)
            sudo apt-get update && sudo apt-get install -y "$@" || return 1 ;;
        yum)
            sudo yum install -y "$@" || return 1 ;;
        dnf)
            sudo dnf install -y "$@" || return 1 ;;
        pacman)
            sudo pacman -S --noconfirm "$@" || return 1 ;;
        zypper)
            sudo zypper install -y "$@" || return 1 ;;
        apk)
            sudo apk add "$@" || return 1 ;;
        *)
            echo -e "${RED}❌ 未识别的包管理器${RESET}"; return 1 ;;
    esac
    return 0
}

exit_confirm() {
    echo -e "\n${YELLOW}⚠️ 确认退出？(y/n)${RESET}"
    read -r -n 1 choice
    echo
    [[ "$choice" == "y" || "$choice" == "Y" ]] && { echo -e "${PURPLE}👋 感谢使用，脚本已退出${RESET}"; exit 0; }
    echo -e "${GREEN}✅ 继续执行脚本...${RESET}"
}

retry_exec() {
    local cmd="$1" desc="$2" count=0
    echo -e "${CYAN}🔄 正在执行：$desc${RESET}"
    while true; do
        if eval "$cmd"; then
            echo -e "${GREEN}✅ $desc 成功${RESET}"
            return 0
        else
            count=$((count+1))
            if (( count < RETRY_MAX )); then
                echo -e "${YELLOW}❌ $desc 失败，$RETRY_DELAY秒后第$((count+1))次重试...${RESET}"
                sleep $RETRY_DELAY
            else
                echo -e "${RED}❌ $desc 已失败$RETRY_MAX次，无法继续${RESET}"
                exit 1
            fi
        fi
    done
}

show_start_ui() {
    clear
    echo -e "${PURPLE}==================================================${RESET}"
    echo -e "${CYAN}                  🎉 小智服务器部署脚本 🎉${RESET}"
    echo -e "${PURPLE}==================================================${RESET}"
    echo -e "${BLUE}作者：$AUTHOR${RESET}"
    echo -e "${BLUE}功能：$SCRIPT_DESC${RESET}"
    echo -e "${BLUE}版本：V$Version"
    echo -e "${PURPLE}==================================================${RESET}"
    HITOKOTO=$(curl -s https://v1.hitokoto.cn?c=a | jq -r '.hitokoto') || HITOKOTO="欢迎使用小智服务器部署脚本！"
    echo -e "${YELLOW}📜 一言：$HITOKOTO${RESET}"
    echo -e "${PURPLE}==================================================${RESET}"
    echo
}

check_server_config() {
    # 获取IP地址
    INTERNAL_IP=$(ip -4 addr show | grep -E 'inet .*(eth0|ens|wlan)' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d'/' -f1 | head -n1)
    [ -z "$INTERNAL_IP" ] && INTERNAL_IP=$(hostname -I | awk '{print $1}')
    [ -z "$INTERNAL_IP" ] && INTERNAL_IP="127.0.0.1"
    EXTERNAL_IP=$(curl -s --max-time 5 https://api.ip.sb/ip || curl -s --max-time 5 https://ifconfig.me || curl -s --max-time 5 https://ipinfo.io/ip || echo "$INTERNAL_IP")

    # 获取硬件信息
    MEM_TOTAL=$(free -g | awk '/Mem:/ {print $2}')
    [ -z "$MEM_TOTAL" ] || [ "$MEM_TOTAL" = "0" ] && MEM_TOTAL=$(free -m | awk '/Mem:/ {print int($2/1024)}')
    CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//')
    CPU_CORES=$(grep -c '^processor' /proc/cpuinfo)
    DISK_AVAIL=$(df -h / | awk '/\// {print $4}')
    NET_INTERFACE=$(ip -br link | grep -v 'LOOPBACK' | grep -v 'DOWN' | awk '{print $1}' | head -n1)
    
    # GPU信息检测（优化逻辑）
    GPU_INFO="未检测到GPU" GPU_MEMORY="" GPU_COUNT=0
    if command -v nvidia-smi &> /dev/null; then
        local gpu_data=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits 2>/dev/null | head -1)
        if [ -n "$gpu_data" ]; then
            GPU_MODEL=$(echo "$gpu_data" | cut -d',' -f1 | sed 's/^ *//;s/ *$//')
            GPU_MEMORY=$(echo "$gpu_data" | cut -d',' -f2 | sed 's/^ *//;s/ *$//')
            GPU_COUNT=$(nvidia-smi --list-gpus | grep -c "GPU" || echo "1")
            GPU_INFO="$GPU_MODEL (显存:${GPU_MEMORY}MB)"
        fi
    elif command -v lspci &> /dev/null; then
        local amd_gpu=$(lspci | grep -i "VGA\|3D controller" | grep -i "AMD\|ATI" | head -1)
        local intel_gpu=$(lspci | grep -i "VGA\|3D controller" | grep -i "Intel" | head -1)
        if [ -n "$amd_gpu" ]; then
            GPU_INFO=$(echo "$amd_gpu" | sed 's/.*VGA.*: //; s/.*3D controller.*: //')
            GPU_COUNT=$(lspci | grep -i "VGA\|3D controller" | grep -c "AMD\|ATI")
        elif [ -n "$intel_gpu" ]; then
            GPU_INFO=$(echo "$intel_gpu" | sed 's/.*VGA.*: //; s/.*3D controller.*: //')
            GPU_COUNT=$(lspci | grep -i "VGA\|3D controller" | grep -c "Intel")
        fi
    fi
    
    # 系统版本检测（统一逻辑）
    if [ -f /etc/os-release ]; then . /etc/os-release; OS_VERSION="$PRETTY_NAME"
    elif command -v lsb_release &> /dev/null; then OS_VERSION=$(lsb_release -d | cut -f2)
    elif [ -f /etc/issue ]; then OS_VERSION=$(head -n1 /etc/issue | sed 's/\\n//g; s/\\l//g')
    else OS_VERSION="未知版本"; fi
    
    # 网络信息
    if [ -n "$NET_INTERFACE" ]; then
        NET_SPEED=$(ethtool "$NET_INTERFACE" 2>/dev/null | grep 'Speed:' | cut -d: -f2 | sed 's/^ *//')
        [ -z "$NET_SPEED" ] && NET_SPEED="未知"
    else
        NET_INTERFACE="未检测到有效网卡"
        NET_SPEED="未知"
    fi
}

show_server_config() {
    echo -e "${PURPLE}==================================================${RESET}"
    echo -e "${CYAN}💻 服务器配置详情${RESET}"
    echo -e "${PURPLE}==================================================${RESET}"
    echo -e "  - ${BOLD}系统版本${RESET}：$OS_VERSION"
    echo -e "  - ${BOLD}CPU型号${RESET}：$CPU_MODEL"
    echo -e "  - ${BOLD}CPU核心数${RESET}：$CPU_CORES 核"
    echo -e "  - ${BOLD}总内存${RESET}：${MEM_TOTAL} GB"
    echo -e "  - ${BOLD}GPU信息${RESET}：$GPU_INFO"
    [ "$GPU_COUNT" -gt 1 ] && echo -e "  - ${BOLD}GPU数量${RESET}：$GPU_COUNT 个"
    [ -n "$GPU_MEMORY" ] && [ "$GPU_MEMORY" != "" ] && echo -e "  - ${BOLD}GPU显存${RESET}：${GPU_MEMORY} MB"
    echo -e "  - ${BOLD}根目录可用空间${RESET}：$DISK_AVAIL"
    echo -e "  - ${BOLD}网卡${RESET}：$NET_INTERFACE（速率：$NET_SPEED）"
    echo -e "  - ${BOLD}内网IP${RESET}：$INTERNAL_IP"
    echo -e "  - ${BOLD}公网IP${RESET}：$EXTERNAL_IP"
    echo -e "${PURPLE}==================================================${RESET}"
    echo

    if [ "$MEM_TOTAL" -ge 4 ]; then
        echo -e "${GREEN}✅ 内存检查通过（${MEM_TOTAL} GB ≥ 4 GB），可以选择本地ASR模型${RESET}"
        IS_MEMORY_SUFFICIENT=true
    else
        echo -e "${RED}❌ 内存检查失败（${MEM_TOTAL} GB < 4 GB）${RESET}"
        echo -e "${RED}⚠️ 本地ASR模型需要≥4GB内存，当前不足！${RESET}"
        echo -e "${RED}⚠️ 若强行使用可能导致服务器卡死，请选择在线ASR模型${RESET}"
        IS_MEMORY_SUFFICIENT=false
    fi
    echo
}

choose_docker_mirror() {
    echo -e "${GREEN}📦 选择Docker镜像源（加速下载）：${RESET}"
    echo "1) 阿里云 2) 腾讯云 3) 华为云 4) DaoCloud 5) 网易云"
    echo "6) 清华源 7) 中科大 8) 中科院 9) 百度云 10) 京东云"
    echo "11) 淘宝源 12) 官方源 13) 腾讯云国际 14) Azure中国 15) 360镜像源"
    echo "16) 阿里云GAE 17) 自定义 18) 官方源(不推荐)"
    read -r -p "请输入序号（默认1）：" mirror_choice
    mirror_choice=${mirror_choice:-1}

    local mirror_url
    case $mirror_choice in
        1) mirror_url="https://registry.cn-hangzhou.aliyuncs.com" ;;
        2) mirror_url="https://mirror.ccs.tencentyun.com" ;;
        3) mirror_url="https://swr.cn-north-1.myhuaweicloud.com" ;;
        4) mirror_url="https://f1361db2.m.daocloud.io" ;;
        5) mirror_url="https://hub-mirror.c.163.com" ;;
        6) mirror_url="https://mirrors.tuna.tsinghua.edu.cn/docker-registry" ;;
        7) mirror_url="https://docker.mirrors.ustc.edu.cn" ;;
        8) mirror_url="https://docker.mirrors.ustc.edu.cn" ;;
        9) mirror_url="https://mirror.baidubce.com" ;;
        10) mirror_url="https://mirror.jdcloud.com" ;;
        11) mirror_url="https://mirrors.aliyun.com/docker-registry" ;;
        12) mirror_url="https://registry-1.docker.io" ;;
        13) mirror_url="https://mirror.tencentcr.com" ;;
        14) mirror_url="https://docker.mirrors.azure.cn" ;;
        15) mirror_url="https://docker.mirrors.360.cn" ;;
        16) mirror_url="https://registry.cn-hangzhou.aliyuncs.com" ;;
        17)
            echo -e "${CYAN}💡 输入自定义镜像源地址：${RESET}"
            read -r mirror_url
            [ -z "$mirror_url" ] && mirror_url="https://registry.cn-hangzhou.aliyuncs.com"
            ;;
        18) mirror_url="https://registry-1.docker.io" ;;
        *) mirror_url="https://registry.cn-hangzhou.aliyuncs.com" ;;
    esac

    sudo mkdir -p /etc/docker
    sudo tee /etc/docker/daemon.json >/dev/null <<EOF
{"registry-mirrors": ["$mirror_url"]}
EOF
    sudo systemctl daemon-reload && sudo systemctl restart docker
    echo -e "${GREEN}✅ 已配置Docker镜像源：$mirror_url${RESET}"
}

check_and_install_docker() {
    echo -e "\n${BLUE}🔍 检测Docker安装状态...${RESET}"
    if command -v docker &> /dev/null && docker --version &> /dev/null; then
        echo -e "${GREEN}✅ Docker 已安装${RESET}"
        return 0
    fi
    
    echo -e "${YELLOW}❌ Docker 未安装${RESET}"
    echo -e "\n${CYAN}📦 需要安装Docker以运行小智服务器容器${RESET}"
    echo -e "${YELLOW}⚠️ Docker安装将包括：Docker Engine、Docker Compose、系统服务配置、用户权限配置${RESET}"
    read -r -p "🔧 是否安装Docker？(y/n，默认y): " docker_install_choice
    docker_install_choice=${docker_install_choice:-y}
    
    if [[ "$docker_install_choice" != "y" && "$docker_install_choice" != "Y" ]]; then
        echo -e "${YELLOW}⚠️ 用户取消Docker安装${RESET}"
        echo -e "${CYAN}💡 手动安装命令：${RESET}"
        echo -e "${GREEN}curl -fsSL https://get.docker.com | sudo bash${RESET}"
        echo -e "${GREEN}sudo usermod -aG docker \$USER${RESET}"
        echo -e "${GREEN}sudo systemctl enable --now docker${RESET}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ 开始Docker安装...${RESET}"
    
    # 安装Docker依赖
    local pkg_manager=$(detect_package_manager)
    echo -e "${BLUE}🔧 包管理器：$pkg_manager${RESET}"
    case $pkg_manager in
        apt)
            retry_exec "sudo apt-get update && sudo apt-get install -y ca-certificates curl gnupg lsb-release" "安装Docker依赖" ;;
        yum|dnf)
            if command -v yum &> /dev/null; then
                retry_exec "sudo yum install -y ca-certificates curl gnupg lsb-release" "安装Docker依赖"
            else
                retry_exec "sudo dnf install -y ca-certificates curl gnupg lsb-release" "安装Docker依赖"
            fi ;;
        pacman)
            retry_exec "sudo pacman -S --noconfirm ca-certificates curl gnupg lsb-release" "安装Docker依赖" ;;
        zypper)
            retry_exec "sudo zypper install -y ca-certificates curl gnupg lsb-release" "安装Docker依赖" ;;
        apk)
            retry_exec "sudo apk add ca-certificates curl gnupg lsb-release" "安装Docker依赖" ;;
        *)
            retry_exec "sudo apt-get update && sudo apt-get install -y ca-certificates curl gnupg lsb-release || sudo yum install -y ca-certificates curl gnupg lsb-release || sudo dnf install -y ca-certificates curl gnupg lsb-release || sudo pacman -S --noconfirm ca-certificates curl gnupg lsb-release || sudo zypper install -y ca-certificates curl gnupg lsb-release || sudo apk add ca-certificates curl gnupg lsb-release" "安装Docker依赖" ;;
    esac
    
    # 多镜像源Docker安装
    local docker_install_success=false mirror_count=0
    declare -a mirrors=(
        "阿里云镜像|https://get.docker.com|sudo bash -s docker --mirror Aliyun"
        "华为云镜像|https://get.docker.com|sudo bash -s docker --mirror HuaweiCloud"
        "Docker官方|https://get.docker.com|sudo bash -s docker"
        "清华源|备用方法1|install_docker_tsinghua"
        "阿里云源|备用方法2|install_docker_aliyun"
    )
    
    echo -e "${BLUE}🔄 多镜像源Docker安装...${RESET}"
    for mirror_info in "${mirrors[@]}"; do
        mirror_count=$((mirror_count + 1))
        IFS='|' read -r mirror_name mirror_url mirror_cmd <<< "$mirror_info"
        echo -e "\n${CYAN}🎯 第$mirror_count个镜像源：$mirror_name${RESET}"
        
        if [[ "$mirror_cmd" == "install_docker_tsinghua" ]]; then
            install_docker_tsinghua && { docker_install_success=true; break; }
        elif [[ "$mirror_cmd" == "install_docker_aliyun" ]]; then
            install_docker_aliyun && { docker_install_success=true; break; }
        else
            if eval "curl -fsSL $mirror_url | $mirror_cmd"; then
                echo -e "${GREEN}✅ $mirror_name Docker安装成功${RESET}"
                docker_install_success=true; break
            else
                echo -e "${YELLOW}❌ $mirror_name Docker安装失败，尝试下一个...${RESET}"
                [ $mirror_count -lt 3 ] && { echo -e "${YELLOW}⏳ 等待3秒...${RESET}"; sleep 3; }
            fi
        fi
    done
    
    if [ "$docker_install_success" = false ]; then
        echo -e "${YELLOW}⚠️ 所有镜像源失败，尝试通用安装方式...${RESET}"
        retry_exec "curl -fsSL https://get.docker.com | sudo bash -s docker" "通用Docker安装方式" && docker_install_success=true
    fi
    
    if [ "$docker_install_success" = false ]; then
        echo -e "${RED}❌ Docker安装完全失败${RESET}"
        echo -e "${YELLOW}请检查网络连接或手动安装Docker${RESET}"
        echo -e "${CYAN}手动安装：curl -fsSL https://get.docker.com | sudo bash${RESET}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Docker安装成功，开始配置...${RESET}"
    sudo usermod -aG docker $USER
    
    if sudo systemctl start docker && sudo systemctl enable docker > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Docker服务启动成功${RESET}"
    else
        echo -e "${YELLOW}⚠️ Docker服务启动可能有问题${RESET}"
    fi
    
    echo -e "${GREEN}✅ Docker 安装完成${RESET}"
    echo -e "${YELLOW}⚠️ 权限将在下次登录时生效，或使用 'newgrp docker' 命令激活${RESET}"
    
    # 配置镜像源
    echo -e "${CYAN}💡 是否配置Docker镜像源加速下载？(y/n，默认y):${RESET}"
    read -r configure_mirror
    configure_mirror=${configure_mirror:-y}
    [[ "$configure_mirror" == "y" || "$configure_mirror" == "Y" ]] && choose_docker_mirror

    # 检查Docker Compose
    if ! docker compose version &> /dev/null; then
        echo -e "${YELLOW}❌ Docker Compose 未安装，开始安装...${RESET}"
        retry_exec "sudo curl -SL \"https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose" "安装Docker Compose"
    fi
}

install_docker_tsinghua() {
    echo -e "${BLUE}🔄 清华源安装脚本${RESET}"
    if curl -fsSL https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu/gpg 2>/dev/null | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg; then
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null 2>&1
        
        local pkg_manager=$(detect_package_manager)
        case $pkg_manager in
            apt)
                if sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1; then
                    echo -e "${GREEN}✅ 清华源Docker安装成功${RESET}"; return 0
                fi ;;
            yum|dnf)
                if command -v yum &> /dev/null; then
                    if sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin > /dev/null 2>&1; then
                        echo -e "${GREEN}✅ 清华源Docker安装成功${RESET}"; return 0
                    fi
                else
                    if sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin > /dev/null 2>&1; then
                        echo -e "${GREEN}✅ 清华源Docker安装成功${RESET}"; return 0
                    fi
                fi ;;
        esac
    fi
    echo -e "${RED}❌ 清华源Docker安装失败${RESET}"
    return 1
}

install_docker_aliyun() {
    echo -e "${BLUE}🔄 阿里云源安装脚本${RESET}"
    if curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg 2>/dev/null | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg; then
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null 2>&1
        
        local pkg_manager=$(detect_package_manager)
        case $pkg_manager in
            apt)
                if sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1; then
                    echo -e "${GREEN}✅ 阿里云源Docker安装成功${RESET}"; return 0
                fi ;;
            yum|dnf)
                if command -v yum &> /dev/null; then
                    if sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin > /dev/null 2>&1; then
                        echo -e "${GREEN}✅ 阿里云源Docker安装成功${RESET}"; return 0
                    fi
                else
                    if sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin > /dev/null 2>&1; then
                        echo -e "${GREEN}✅ 阿里云源Docker安装成功${RESET}"; return 0
                    fi
                fi ;;
        esac
    fi
    echo -e "${RED}❌ 阿里云源Docker安装失败${RESET}"
    return 1
}

check_docker_installed() {
    if ! command -v docker &> /dev/null || ! docker --version &> /dev/null; then
        echo -e "${RED}❌ Docker未安装或安装异常，脚本无法继续${RESET}"
        echo -e "${YELLOW}请重新运行脚本进行Docker安装，或手动安装Docker后重试${RESET}"
        exit 1
    fi
    return 0
}

clean_container() {
    check_docker_installed
    echo -e "\n${BLUE}🔍 检测容器 $CONTAINER_NAME...${RESET}"
    if docker ps -a --filter "name=^/${CONTAINER_NAME}$" --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
        echo -e "${YELLOW}⚠️ 容器 $CONTAINER_NAME 已存在，正在删除...${RESET}"
        retry_exec "docker rm -f $CONTAINER_NAME" "删除容器 $CONTAINER_NAME"
    else
        echo -e "${GREEN}✅ 容器 $CONTAINER_NAME 不存在${RESET}"
    fi
}

create_dirs() {
    echo -e "\n${BLUE}📂 创建目录结构...${RESET}"
    local dirs=("$MAIN_DIR/data" "$MAIN_DIR/models/SenseVoiceSmall" "$MAIN_DIR/models/vosk" "$MAIN_DIR/models/sherpa-onnx" "$MAIN_DIR/music")
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            retry_exec "mkdir -p $dir" "创建目录 $dir"
        else
            echo -e "${GREEN}✅ 目录 $dir 已存在${RESET}"
        fi
    done
}

download_config_with_fallback() {
    local output_file="$1"
    local download_success=false
    local mirror_count=0
    
    # 定义配置文件下载链接列表
    declare -a config_urls=(
        "主链接1|$CONFIG_FILE_URL"
        "主链接2|$CONFIG_FILE_URL_BACKUP"
        "备用链接|$CONFIG_FILE_URL_FALLBACK"
    )
    
    echo -e "${CYAN}🔄 开始多链接配置文件下载...${RESET}"
    
    for url_info in "${config_urls[@]}"; do
        mirror_count=$((mirror_count + 1))
        IFS='|' read -r link_name config_url <<< "$url_info"
        
        echo -e "\n${CYAN}🎯 尝试第$mirror_count个链接：$link_name${RESET}"
        echo -e "${YELLOW}📎 链接：$config_url${RESET}"
        
        if curl -fSL --connect-timeout 10 --max-time 30 "$config_url" -o "$output_file" 2>/dev/null; then
            if [ -f "$output_file" ] && grep -q "server:" "$output_file" 2>/dev/null; then
                echo -e "${GREEN}✅ $link_name 下载成功${RESET}"
                download_success=true
                break
            else
                echo -e "${YELLOW}⚠️ $link_name 下载文件无效，尝试下一个${RESET}"
                rm -f "$output_file"
            fi
        else
            echo -e "${RED}❌ $link_name 下载失败${RESET}"
        fi
        
        if [ $mirror_count -lt ${#config_urls[@]} ]; then
            echo -e "${YELLOW}⏳ 等待3秒后尝试下一个链接...${RESET}"
            sleep 3
        fi
    done
    
    if [ "$download_success" = true ]; then
        echo -e "${GREEN}✅ 配置文件下载成功：$output_file${RESET}"
        return 0
    else
        echo -e "${RED}❌ 所有配置文件链接都失败了${RESET}"
        echo -e "${YELLOW}📖 可用链接：${RESET}"
        echo -e "   - $CONFIG_FILE_URL"
        echo -e "   - $CONFIG_FILE_URL_BACKUP"
        echo -e "   - $CONFIG_FILE_URL_FALLBACK"
        return 1
    fi
}

download_files() {
    local should_download="${1:-true}"
    
    if [ "$should_download" = "true" ]; then
        echo -e "\n${BLUE}📥 下载配置文件...${RESET}"
        mkdir -p "$MAIN_DIR/data"
        download_config_with_fallback "$OVERRIDE_CONFIG_FILE"
        retry_exec "curl -fSL $DOCKER_COMPOSE_URL -o $MAIN_DIR/docker-compose.yml" "下载 docker-compose.yml"
    else
        echo -e "\n${GREEN}✅ 跳过下载文件，使用现有配置文件${RESET}"
    fi
}

check_if_already_configured() {
    if [ -f "$OVERRIDE_CONFIG_FILE" ] && grep -q "selected_module:" "$OVERRIDE_CONFIG_FILE" 2>/dev/null; then
        return 0  # 已配置
    fi
    return 1  # 未配置
}

setup_config_file() {
    echo -e "\n${CYAN}📁 配置小智服务器配置文件...${RESET}"
    
    mkdir -p "$MAIN_DIR/data"
    echo -e "${GREEN}✅ 已创建 data 目录: $MAIN_DIR/data${RESET}"
    
    if [ -f "$OVERRIDE_CONFIG_FILE" ]; then
        echo -e "${YELLOW}📋 发现现有配置文件${RESET}"
        echo "配置文件: $OVERRIDE_CONFIG_FILE"
        echo "请选择处理方式："
        echo "1) 使用现有配置文件 2) 重新下载新配置文件"
        read -p "请输入选择 (1-2，默认1): " config_choice
        config_choice=${config_choice:-1}
        
        case $config_choice in
            1)
                echo -e "\n${GREEN}✅ 使用现有配置文件${RESET}"
                
                if check_if_already_configured; then
                    echo -e "\n${CYAN}ℹ️ 检测到配置文件已完整配置过${RESET}"
                    echo "1) 保留现有配置直接使用"
                    echo "2) 重新进行详细配置"
                    echo "3) 保留配置文件但重新配置"
                    read -p "请输入选择 (1-3，默认1): " detailed_choice
                    detailed_choice=${detailed_choice:-1}
                    
                    case $detailed_choice in
                        1)
                            echo -e "\n${GREEN}✅ 保留现有配置${RESET}"
                            CONFIG_DOWNLOAD_NEEDED="false"
                            USE_EXISTING_CONFIG=true
                            SKIP_DETAILED_CONFIG=true
                            return ;;
                        2)
                            echo -e "\n${YELLOW}⚠️ 重新详细配置${RESET}"
                            CONFIG_DOWNLOAD_NEEDED="false"
                            USE_EXISTING_CONFIG=true
                            SKIP_DETAILED_CONFIG=false ;;
                        3)
                            echo -e "\n${BLUE}📥 保留配置但重新配置${RESET}"
                            CONFIG_DOWNLOAD_NEEDED="false"
                            USE_EXISTING_CONFIG=true
                            SKIP_DETAILED_CONFIG=false ;;
                        *)
                            echo -e "\n${GREEN}✅ 保留现有配置${RESET}"
                            CONFIG_DOWNLOAD_NEEDED="false"
                            USE_EXISTING_CONFIG=true
                            SKIP_DETAILED_CONFIG=true
                            return ;;
                    esac
                else
                    echo -e "\n${GREEN}✅ 使用现有配置但需完善${RESET}"
                    CONFIG_DOWNLOAD_NEEDED="false"
                    USE_EXISTING_CONFIG=true
                    SKIP_DETAILED_CONFIG=false
                fi ;;
            2)
                echo -e "\n${BLUE}📥 重新下载配置文件...${RESET}"
                if download_config_with_fallback "$OVERRIDE_CONFIG_FILE"; then
                    CONFIG_DOWNLOAD_NEEDED="true"
                    USE_EXISTING_CONFIG=false
                    SKIP_DETAILED_CONFIG=false
                else
                    echo -e "${RED}❌ 配置文件下载失败${RESET}"
                    exit 1
                fi ;;
            *)
                echo -e "\n${GREEN}✅ 使用现有配置${RESET}"
                CONFIG_DOWNLOAD_NEEDED="false" ;;
        esac
    else
        echo -e "${BLUE}📥 未发现配置文件，下载模板...${RESET}"
        if download_config_with_fallback "$OVERRIDE_CONFIG_FILE"; then
            echo -e "${GREEN}✅ 已下载配置文件: $OVERRIDE_CONFIG_FILE${RESET}"
            CONFIG_DOWNLOAD_NEEDED="true"
        else
            echo -e "${RED}❌ 配置文件下载失败${RESET}"
            exit 1
        fi
    fi
    
    echo ""
    echo -e "${CYAN}📊 配置文件状态:${RESET}"
    echo "文件: $OVERRIDE_CONFIG_FILE"
    echo "大小: $(du -h $OVERRIDE_CONFIG_FILE 2>/dev/null | cut -f1 || echo '未知')"
    echo "时间: $(stat -c %y $OVERRIDE_CONFIG_FILE 2>/dev/null | cut -d'.' -f1 || echo '未知')"
    
    echo ""
    echo -e "${YELLOW}💡 配置修改将应用到 $OVERRIDE_CONFIG_FILE${RESET}"
    echo "建议编辑内容:"
    echo "- LLM配置 (ChatGLM等API密钥)"
    echo "- ASR配置 (阿里云等语音识别服务)"
    echo "- TTS配置 (EdgeTTS等语音合成服务)"
}

# ========================= ASR 配置（15个服务商） =========================
config_asr() {
    local asr_return_to_prev=false
    
    while [ "$asr_return_to_prev" = false ]; do
        echo -e "\n${GREEN}【1/5】配置 ASR (语音识别) 服务${RESET}"
        echo "请选择ASR服务商（共15个）："
        echo " 0) ${YELLOW} 返回上一步 ${RESET}"
        
        if [ "$IS_MEMORY_SUFFICIENT" = true ]; then
            echo " 1) ${GREEN}FunASR (本地)${RESET}"
            echo -e "    ${CYAN}✅ 内存充足 (${MEM_TOTAL}GB ≥ 4GB) - 可选择${RESET}"
            echo " 2) FunASRServer (独立部署)"
            echo " 3) ${GREEN}SherpaASR (本地，多语言)${RESET}"
            echo -e "    ${CYAN}✅ 内存充足 - 可选择${RESET}"
            echo " 4) ${GREEN}SherpaParaformerASR (本地，中文专用)${RESET}"
            echo -e "    ${CYAN}✅ 内存充足 - 可选择${RESET}"
            echo " 5) DoubaoASR (火山引擎，按次收费)"
            echo " 6) DoubaoStreamASR (火山引擎，按时收费)"
            echo " 7) TencentASR (腾讯云)"
            echo " 8) AliyunASR (阿里云，批量处理)"
            echo " 9) AliyunStreamASR (阿里云，实时流式) [推荐]"
            echo "10) BaiduASR (百度智能云)"
            echo "11) OpenaiASR (OpenAI)"
            echo "12) GroqASR (Groq)"
            echo "13) ${GREEN}VoskASR (本地，完全离线)${RESET}"
            echo -e "    ${CYAN}✅ 内存充足 - 可选择${RESET}"
        else
            echo -e " 1) ${RED}FunASR (本地)${RESET} ${RED}❌ 内存不足 (${MEM_TOTAL}GB < 4GB)${RESET}"
            echo " 2) FunASRServer (独立部署)"
            echo -e " 3) ${RED}SherpaASR (本地，多语言)${RESET} ${RED}❌ 内存不足${RESET}"
            echo -e " 4) ${RED}SherpaParaformerASR (本地，中文专用)${RESET} ${RED}❌ 内存不足${RESET}"
            echo " 5) DoubaoASR (火山引擎，按次收费)"
            echo " 6) DoubaoStreamASR (火山引擎，按时收费)"
            echo " 7) TencentASR (腾讯云)"
            echo " 8) AliyunASR (阿里云，批量处理)"
            echo " 9) AliyunStreamASR (阿里云，实时流式) [推荐]"
            echo "10) BaiduASR (百度智能云)"
            echo "11) OpenaiASR (OpenAI)"
            echo "12) GroqASR (Groq)"
            echo -e "13) ${GREEN}VoskASR (本地，完全离线)${RESET} ${GREEN}✅ 内存占用较小 (建议≥2GB)${RESET}"
        fi
        echo " 14) Qwen3ASRFlash (通义千问)"
        echo " 15) XunfeiStreamASR (讯飞，流式)"
        
        read -r -p "请输入序号 (默认推荐 9，输入0返回上一步): " asr_choice
        asr_choice=${asr_choice:-9}
        
        # 处理返回上一步
        if [ "$asr_choice" = "0" ]; then
            asr_return_to_prev=true
            return
        fi

        local asr_provider_key
        case $asr_choice in
            1)
                asr_provider_key="FunASR"
                if [ "$IS_MEMORY_SUFFICIENT" = false ]; then
                    echo -e "\n${RED}❌ 内存不足，无法选择FunASR本地模型，请重新选择其他ASR服务商${RESET}"
                    echo -e "${YELLOW}💡 按回车键重新选择...${RESET}"
                    read -r
                    continue
                fi
                echo -e "\n${GREEN}✅ 已选择本地模型 FunASR。${RESET}"
                echo -e "${CYAN}ℹ️ 系统将自动配置 model_dir 为 models/SenseVoiceSmall。${RESET}"
                echo -e "\n${CYAN}📥 正在下载 SenseVoiceSmall ASR 模型... 这可能需要几分钟。${RESET}"
                retry_exec "curl -fSL $LOCAL_ASR_MODEL_URL -o $MAIN_DIR/models/SenseVoiceSmall/model.pt" "下载 ASR 模型"
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s|^    model_dir: .*|    model_dir: \"models/SenseVoiceSmall\"|" "$OVERRIDE_CONFIG_FILE"
                ;;
            2)
                asr_provider_key="FunASRServer"
                echo -e "\n${YELLOW}⚠️ 您选择了 FunASRServer。${RESET}"
                echo -e "${CYAN}🔗 需要自行部署 FunASR Server 服务${RESET}"
                read -r -p "请输入 FunASR Server 地址 (默认 http://localhost:10095): " server_url
                server_url=${server_url:-"http://localhost:10095"}
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    host: .*/    host: $server_url/" "$OVERRIDE_CONFIG_FILE"
                ;;
            3)
                asr_provider_key="SherpaASR"
                if [ "$IS_MEMORY_SUFFICIENT" = false ]; then
                    echo -e "\n${RED}❌ 内存不足，无法选择SherpaASR本地模型${RESET}"
                    read -r
                    continue
                fi
                echo -e "\n${GREEN}✅ 已选择本地模型 SherpaASR。${RESET}"
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$OVERRIDE_CONFIG_FILE"
                ;;
            4)
                asr_provider_key="SherpaParaformerASR"
                if [ "$IS_MEMORY_SUFFICIENT" = false ]; then
                    echo -e "\n${RED}❌ 内存不足，无法选择SherpaParaformerASR本地模型${RESET}"
                    read -r
                    continue
                fi
                echo -e "\n${GREEN}✅ 已选择本地模型 SherpaParaformerASR。${RESET}"
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$OVERRIDE_CONFIG_FILE"
                ;;
            5)
                asr_provider_key="DoubaoASR"
                echo -e "\n${YELLOW}⚠️ 您选择了火山引擎 DoubaoASR。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://www.volcengine.com/products/voice-interaction${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                read -r -p "请输入 Secret Key: " secret_key
                secret_key="${secret_key:-}"
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$OVERRIDE_CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
                fi
                if [ -n "$secret_key" ]; then
                    sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    secret_key: .*/    secret_key: \"$secret_key\"/" "$OVERRIDE_CONFIG_FILE"
                fi
                ;;
            6)
                asr_provider_key="DoubaoStreamASR"
                echo -e "\n${YELLOW}⚠️ 您选择了火山引擎 DoubaoStreamASR。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://www.volcengine.com/products/voice-interaction${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                read -r -p "请输入 Secret Key: " secret_key
                secret_key="${secret_key:-}"
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$OVERRIDE_CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
                fi
                if [ -n "$secret_key" ]; then
                    sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    secret_key: .*/    secret_key: \"$secret_key\"/" "$OVERRIDE_CONFIG_FILE"
                fi
                ;;
            7)
                asr_provider_key="TencentASR"
                echo -e "\n${YELLOW}⚠️ 您选择了腾讯云 ASR。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://console.cloud.tencent.com/asr${RESET}"
                read -r -p "请输入 Secret ID: " secret_id
                read -r -p "请输入 Secret Key: " secret_key
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    secret_id: .*/    secret_id: $secret_id/" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    secret_key: .*/    secret_key: $secret_key/" "$OVERRIDE_CONFIG_FILE"
                ;;
            8)
                asr_provider_key="AliyunASR"
                echo -e "\n${YELLOW}⚠️ 您选择了阿里云 ASR。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://nls-portal.console.aliyun.com/${RESET}"
                read -r -p "请输入 Appkey: " appkey
                read -r -p "请输入 Access Key ID: " access_key_id
                read -r -p "请输入 Access Key Secret: " access_key_secret
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    appkey: .*/    appkey: $appkey/" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    access_key_id: .*/    access_key_id: $access_key_id/" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    access_key_secret: .*/    access_key_secret: $access_key_secret/" "$OVERRIDE_CONFIG_FILE"
                ;;
            9)
                asr_provider_key="AliyunStreamASR"
                echo -e "\n${YELLOW}⚠️ 您选择了阿里云流式 ASR。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://nls-portal.console.aliyun.com/${RESET}"
                read -r -p "请输入 Appkey: " appkey
                read -r -p "请输入 Access Key ID: " access_key_id
                read -r -p "请输入 Access Key Secret: " access_key_secret
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    appkey: .*/    appkey: $appkey/" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    access_key_id: .*/    access_key_id: $access_key_id/" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    access_key_secret: .*/    access_key_secret: $access_key_secret/" "$OVERRIDE_CONFIG_FILE"
                ;;
            10)
                asr_provider_key="BaiduASR"
                echo -e "\n${YELLOW}⚠️ 您选择了百度智能云 ASR。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://console.bce.baidu.com/ai/?fromai=1#/ai/speech/overview/index${RESET}"
                read -r -p "请输入 API Key: " api_key
                read -r -p "请输入 Secret Key: " secret_key
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: $api_key/" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    secret_key: .*/    secret_key: $secret_key/" "$OVERRIDE_CONFIG_FILE"
                ;;
            11)
                asr_provider_key="OpenaiASR"
                echo -e "\n${YELLOW}⚠️ 您选择了 OpenAI ASR。${RESET}"
                echo -e "${CYAN}🔑 密钥获取地址：https://platform.openai.com/settings/organization/api-keys${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                read -r -p "请输入 代理地址 (选填): " http_proxy
                http_proxy="${http_proxy:-}"
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$OVERRIDE_CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
                fi
                [ -n "$http_proxy" ] && sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    http_proxy: .*/    http_proxy: \"$http_proxy\"/" "$OVERRIDE_CONFIG_FILE"
                ;;
            12)
                asr_provider_key="GroqASR"
                echo -e "\n${YELLOW}⚠️ 您选择了 Groq ASR。${RESET}"
                echo -e "${CYAN}🔑 密钥获取地址：https://console.groq.com/keys${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$OVERRIDE_CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
                fi
                ;;
            13)
                asr_provider_key="VoskASR"
                echo -e "\n${GREEN}✅ 已选择本地模型 VoskASR。${RESET}"
                echo -e "${CYAN}ℹ️ VoskASR 是完全离线的语音识别模型，不依赖网络连接。${RESET}"
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$OVERRIDE_CONFIG_FILE"
                ;;
            14)
                asr_provider_key="Qwen3ASRFlash"
                echo -e "\n${YELLOW}⚠️ 您选择了通义千问 Qwen3ASRFlash。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://dashscope.console.aliyun.com/apiKey${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$OVERRIDE_CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
                fi
                ;;
            15)
                asr_provider_key="XunfeiStreamASR"
                echo -e "\n${YELLOW}⚠️ 您选择了讯飞流式 ASR。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://www.xfyun.cn/services/asr${RESET}"
                read -r -p "请输入 APP ID: " app_id
                app_id="${app_id:-}"
                read -r -p "请输入 API Secret: " api_secret
                api_secret="${api_secret:-}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$OVERRIDE_CONFIG_FILE"
                if [ -n "$app_id" ]; then
                    sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    app_id: .*/    app_id: \"$app_id\"/" "$OVERRIDE_CONFIG_FILE"
                fi
                if [ -n "$api_secret" ]; then
                    sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    api_secret: .*/    api_secret: \"$api_secret\"/" "$OVERRIDE_CONFIG_FILE"
                fi
                if [ -n "$api_key" ]; then
                    sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
                fi
                ;;
            *)
                asr_provider_key="AliyunStreamASR"
                echo -e "\n${YELLOW}⚠️ 输入无效，默认选择阿里云流式 ASR。${RESET}"
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$OVERRIDE_CONFIG_FILE"
                ;;
        esac
        
        # 完成选择后退出循环
        asr_return_to_prev=true
    done
}

# ========================= LLM 配置（8个服务商） =========================
config_llm() {
    local llm_return_to_prev=false
    
    while [ "$llm_return_to_prev" = false ]; do
        echo -e "\n\n${GREEN}【2/5】配置 LLM (大语言模型) 服务${RESET}"
        echo "请选择LLM服务商（共8个）："
        echo " 0) ${YELLOW} 返回上一步 ${RESET}"
        echo " 1) ChatGLMLLM (智谱清言) [推荐]"
        echo " 2) QwenLLM (通义千问)"
        echo " 3) KimiLLM (月之暗面)"
        echo " 4) SparkLLM (讯飞星火)"
        echo " 5) WenxinLLM (百度文心一言)"
        echo " 6) DoubaoLLM (火山引擎豆包)"
        echo " 7) OpenaiLLM (OpenAI)"
        echo " 8) GroqLLM (Groq)"
        
        read -r -p "请输入序号 (默认推荐 1，输入0返回上一步): " llm_choice
        llm_choice=${llm_choice:-1}
        
        # 处理返回上一步
        if [ "$llm_choice" = "0" ]; then
            config_asr
            continue
        fi

        local llm_provider_key
        case $llm_choice in
            1)
                llm_provider_key="ChatGLMLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了智谱清言 ChatGLMLLM。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://open.bigmodel.cn/usercenter/apikeys${RESET}"
                read -r -p "请输入 API Key: " api_key
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
                ;;
            2)
                llm_provider_key="QwenLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了通义千问 QwenLLM。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://dashscope.console.aliyun.com/apiKey${RESET}"
                read -r -p "请输入 API Key: " api_key
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
                ;;
            3)
                llm_provider_key="KimiLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了月之暗面 KimiLLM。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://platform.moonshot.cn/console/api-keys${RESET}"
                read -r -p "请输入 API Key: " api_key
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
                ;;
            4)
                llm_provider_key="SparkLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了讯飞星火 SparkLLM。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://www.xfyun.cn/services/aigc/${RESET}"
                read -r -p "请输入 APP ID: " app_id
                read -r -p "请输入 API Secret: " api_secret
                read -r -p "请输入 API Key: " api_key
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    app_id: .*/    app_id: \"$app_id\"/" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_secret: .*/    api_secret: \"$api_secret\"/" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
                ;;
            5)
                llm_provider_key="WenxinLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了百度文心一言 WenxinLLM。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://console.bce.baidu.com/ai/?fromai=1#/ai/wenxinworkshop/app/apilist${RESET}"
                read -r -p "请输入 API Key: " api_key
                read -r -p "请输入 Secret Key: " secret_key
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: $api_key/" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    secret_key: .*/    secret_key: $secret_key/" "$OVERRIDE_CONFIG_FILE"
                ;;
            6)
                llm_provider_key="DoubaoLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了火山引擎豆包 DoubaoLLM。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://www.volcengine.com/products/doubao${RESET}"
                read -r -p "请输入 API Key: " api_key
                read -r -p "请输入 Secret Key: " secret_key
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    secret_key: .*/    secret_key: \"$secret_key\"/" "$OVERRIDE_CONFIG_FILE"
                ;;
            7)
                llm_provider_key="OpenaiLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了 OpenAI LLM。${RESET}"
                echo -e "${CYAN}🔑 密钥获取地址：https://platform.openai.com/settings/organization/api-keys${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                read -r -p "请输入 代理地址 (选填): " http_proxy
                http_proxy="${http_proxy:-}"
                echo -e "${CYAN}🎭 模型选择：${RESET}"
                echo "  可选模型：gpt-3.5-turbo (默认), gpt-4, gpt-4-turbo"
                read -r -p "请输入模型 (默认使用 gpt-3.5-turbo): " model
                model=${model:-"gpt-3.5-turbo"}
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$OVERRIDE_CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
                fi
                sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    model: .*/    model: $model/" "$OVERRIDE_CONFIG_FILE"
                [ -n "$http_proxy" ] && sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    http_proxy: .*/    http_proxy: \"$http_proxy\"/" "$OVERRIDE_CONFIG_FILE"
                ;;
            8)
                llm_provider_key="GroqLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了 Groq LLM。${RESET}"
                echo -e "${CYAN}🔑 密钥获取地址：https://console.groq.com/keys${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                echo -e "${CYAN}🎭 模型选择：${RESET}"
                echo "  可选模型：llama2-70b-4096 (默认), mixtral-8x7b-32768, gemma-7b-it"
                read -r -p "请输入模型 (默认使用 llama2-70b-4096): " model
                model=${model:-"llama2-70b-4096"}
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$OVERRIDE_CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
                fi
                sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    model: .*/    model: $model/" "$OVERRIDE_CONFIG_FILE"
                ;;
            *)
                llm_provider_key="ChatGLMLLM"
                echo -e "\n${YELLOW}⚠️ 输入无效，默认选择智谱清言 ChatGLMLLM。${RESET}"
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$OVERRIDE_CONFIG_FILE"
                ;;
        esac
        
        # 完成选择后退出循环
        llm_return_to_prev=true
    done
}

# ========================= VLLM 配置（8个服务商） =========================
config_vllm() {
    local vllm_return_to_prev=false
    
    while [ "$vllm_return_to_prev" = false ]; do
        echo -e "\n\n${GREEN}【3/5】配置 VLLM (本地大语言模型) 服务${RESET}"
        echo "请选择VLLM服务商（共8个）："
        echo " 0) ${YELLOW} 返回上一步 ${RESET}"
        echo " 1) ChatGLMVLLM (智谱清言) [推荐]"
        echo " 2) QwenVLLM (通义千问)"
        echo " 3) KimiVLLM (月之暗面)"
        echo " 4) SparkVLLM (讯飞星火)"
        echo " 5) WenxinVLLM (百度文心一言)"
        echo " 6) DoubaoVLLM (火山引擎豆包)"
        echo " 7) OpenaiVLLM (OpenAI)"
        echo " 8) GroqVLLM (Groq)"
        
        read -r -p "请输入序号 (默认推荐 1，输入0返回上一步): " vllm_choice
        vllm_choice=${vllm_choice:-1}
        
        # 处理返回上一步
        if [ "$vllm_choice" = "0" ]; then
            config_llm
            continue
        fi

        local vllm_provider_key
        case $vllm_choice in
            1)
                vllm_provider_key="ChatGLMVLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了智谱清言 ChatGLMVLLM。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://open.bigmodel.cn/usercenter/apikeys${RESET}"
                read -r -p "请输入 API Key: " api_key
                
                sed -i "/^  VLLM: /c\  VLLM: $vllm_provider_key" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $vllm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
                ;;
            2)
                vllm_provider_key="QwenVLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了通义千问 QwenVLLM。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://dashscope.console.aliyun.com/apiKey${RESET}"
                read -r -p "请输入 API Key: " api_key
                
                sed -i "/^  VLLM: /c\  VLLM: $vllm_provider_key" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $vllm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
                ;;
            3)
                vllm_provider_key="KimiVLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了月之暗面 KimiVLLM。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://platform.moonshot.cn/console/api-keys${RESET}"
                read -r -p "请输入 API Key: " api_key
                
                sed -i "/^  VLLM: /c\  VLLM: $vllm_provider_key" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $vllm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
                ;;
            4)
                vllm_provider_key="SparkVLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了讯飞星火 SparkVLLM。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://www.xfyun.cn/services/aigc/${RESET}"
                read -r -p "请输入 APP ID: " app_id
                read -r -p "请输入 API Secret: " api_secret
                read -r -p "请输入 API Key: " api_key
                
                sed -i "/^  VLLM: /c\  VLLM: $vllm_provider_key" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $vllm_provider_key:/,/^  [A-Za-z]/ s/^    app_id: .*/    app_id: \"$app_id\"/" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $vllm_provider_key:/,/^  [A-Za-z]/ s/^    api_secret: .*/    api_secret: \"$api_secret\"/" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $vllm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
                ;;
            5)
                vllm_provider_key="WenxinVLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了百度文心一言 WenxinVLLM。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://console.bce.baidu.com/ai/?fromai=1#/ai/wenxinworkshop/app/apilist${RESET}"
                read -r -p "请输入 API Key: " api_key
                read -r -p "请输入 Secret Key: " secret_key
                
                sed -i "/^  VLLM: /c\  VLLM: $vllm_provider_key" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $vllm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: $api_key/" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $vllm_provider_key:/,/^  [A-Za-z]/ s/^    secret_key: .*/    secret_key: $secret_key/" "$OVERRIDE_CONFIG_FILE"
                ;;
            6)
                vllm_provider_key="DoubaoVLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了火山引擎豆包 DoubaoVLLM。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://www.volcengine.com/products/doubao${RESET}"
                read -r -p "请输入 API Key: " api_key
                read -r -p "请输入 Secret Key: " secret_key
                
                sed -i "/^  VLLM: /c\  VLLM: $vllm_provider_key" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $vllm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $vllm_provider_key:/,/^  [A-Za-z]/ s/^    secret_key: .*/    secret_key: \"$secret_key\"/" "$OVERRIDE_CONFIG_FILE"
                ;;
            7)
                vllm_provider_key="OpenaiVLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了 OpenAI VLLM。${RESET}"
                echo -e "${CYAN}🔑 密钥获取地址：https://platform.openai.com/settings/organization/api-keys${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                read -r -p "请输入 代理地址 (选填): " http_proxy
                http_proxy="${http_proxy:-}"
                echo -e "${CYAN}🎭 模型选择：${RESET}"
                echo "  可选模型：gpt-3.5-turbo (默认), gpt-4, gpt-4-turbo"
                read -r -p "请输入模型 (默认使用 gpt-3.5-turbo): " model
                model=${model:-"gpt-3.5-turbo"}
                
                sed -i "/^  VLLM: /c\  VLLM: $vllm_provider_key" "$OVERRIDE_CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $vllm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
                fi
                sed -i "/^  $vllm_provider_key:/,/^  [A-Za-z]/ s/^    model: .*/    model: $model/" "$OVERRIDE_CONFIG_FILE"
                [ -n "$http_proxy" ] && sed -i "/^  $vllm_provider_key:/,/^  [A-Za-z]/ s/^    http_proxy: .*/    http_proxy: \"$http_proxy\"/" "$OVERRIDE_CONFIG_FILE"
                ;;
            8)
                vllm_provider_key="GroqVLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了 Groq VLLM。${RESET}"
                echo -e "${CYAN}🔑 密钥获取地址：https://console.groq.com/keys${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                echo -e "${CYAN}🎭 模型选择：${RESET}"
                echo "  可选模型：llama2-70b-4096 (默认), mixtral-8x7b-32768, gemma-7b-it"
                read -r -p "请输入模型 (默认使用 llama2-70b-4096): " model
                model=${model:-"llama2-70b-4096"}
                
                sed -i "/^  VLLM: /c\  VLLM: $vllm_provider_key" "$OVERRIDE_CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $vllm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
                fi
                sed -i "/^  $vllm_provider_key:/,/^  [A-Za-z]/ s/^    model: .*/    model: $model/" "$OVERRIDE_CONFIG_FILE"
                ;;
            *)
                vllm_provider_key="ChatGLMVLLM"
                echo -e "\n${YELLOW}⚠️ 输入无效，默认选择智谱清言 ChatGLMVLLM。${RESET}"
                sed -i "/^  VLLM: /c\  VLLM: $vllm_provider_key" "$OVERRIDE_CONFIG_FILE"
                ;;
        esac
        
        # 完成选择后退出循环
        vllm_return_to_prev=true
    done
}

# ========================= TTS 配置（23个服务商） =========================
config_tts() {
    local tts_return_to_prev=false
    
    while [ "$tts_return_to_prev" = false ]; do
        echo -e "\n\n${GREEN}【4/5】配置 TTS (语音合成) 服务${RESET}"
        echo "请选择TTS服务商（共23个）："
        echo " 0) ${YELLOW} 返回上一步 ${RESET}"
        echo " 1) EdgeTTS (微软) [推荐]"
        echo " 2) DoubaoTTS (火山引擎豆包)"
        echo " 3) DoubaoStreamTTS (火山引擎豆包流式)"
        echo " 4) AliyunTTS (阿里云)"
        echo " 5) AliyunStreamTTS (阿里云流式)"
        echo " 6) TencentTTS (腾讯云)"
        echo " 7) TTS302AI (302AI)"
        echo " 8) GizwitsTTS (机智云)"
        echo " 9) ACGNTTS (ACGN)"
        echo "10) OpenAITTS (OpenAI)"
        echo "11) CustomTTS (自定义)"
        echo "12) LinkeraiTTS (LinkerAI)"
        echo "13) PaddleSpeechTTS (百度飞桨)"
        echo "14) IndexStreamTTS (Index-TTS)"
        echo "15) AliBLTTS (阿里云百炼)"
        echo "16) XunFeiTTS (讯飞)"
        
        read -r -p "请输入序号 (默认推荐 1，输入0返回上一步): " tts_choice
        tts_choice=${tts_choice:-1}
        
        # 处理返回上一步
        if [ "$tts_choice" = "0" ]; then
            config_vllm
            continue
        fi

        local tts_provider_key
        case $tts_choice in
            1)
                tts_provider_key="EdgeTTS"
                echo -e "\n${GREEN}✅ 已选择微软 EdgeTTS。${RESET}"
                echo -e "${CYAN}ℹ️ EdgeTTS 是微软的免费语音合成服务，无需配置API密钥。${RESET}"
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
                ;;
            2)
                tts_provider_key="DoubaoTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了火山引擎豆包 TTS。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://www.volcengine.com/products/doubao${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                read -r -p "请输入 Secret Key: " secret_key
                secret_key="${secret_key:-}"
                read -r -p "请输入音色 (默认使用 female-yujie): " voice
                voice=${voice:-"female-yujie"}
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
                fi
                if [ -n "$secret_key" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    secret_key: .*/    secret_key: \"$secret_key\"/" "$OVERRIDE_CONFIG_FILE"
                fi
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    voice: .*/    voice: $voice/" "$OVERRIDE_CONFIG_FILE"
                ;;
            3)
                tts_provider_key="DoubaoStreamTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了火山引擎豆包流式 TTS。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://www.volcengine.com/products/doubao${RESET}"
                read -r -p "请输入 group_id: " group_id
                read -r -p "请输入 api_key: " api_key
                api_key="${api_key:-}"
                read -r -p "请输入 Secret Key: " secret_key
                secret_key="${secret_key:-}"
                read -r -p "请输入音色 (默认使用 female-yujie): " voice
                voice=${voice:-"female-yujie"}
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
                if [ -n "$group_id" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    group_id: .*/    group_id: \"$group_id\"/" "$OVERRIDE_CONFIG_FILE"
                fi
                if [ -n "$api_key" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
                fi
                if [ -n "$secret_key" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    secret_key: .*/    secret_key: \"$secret_key\"/" "$OVERRIDE_CONFIG_FILE"
                fi
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    voice: .*/    voice: $voice/" "$OVERRIDE_CONFIG_FILE"
                ;;
            11)
                tts_provider_key="AliyunTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了阿里云 TTS。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://nls-portal.console.aliyun.com/${RESET}"
                read -r -p "请输入 Appkey: " appkey
                read -r -p "请输入 Access Key ID: " access_key_id
                read -r -p "请输入 Access Key Secret: " access_key_secret
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    appkey: .*/    appkey: $appkey/" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    access_key_id: .*/    access_key_id: $access_key_id/" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    access_key_secret: .*/    access_key_secret: $access_key_secret/" "$OVERRIDE_CONFIG_FILE"
                ;;
            12)
                tts_provider_key="AliyunStreamTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了阿里云流式 TTS。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://nls-portal.console.aliyun.com/${RESET}"
                read -r -p "请输入 Appkey: " appkey
                read -r -p "请输入 Access Key ID: " access_key_id
                read -r -p "请输入 Access Key Secret: " access_key_secret
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    appkey: .*/    appkey: $appkey/" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    access_key_id: .*/    access_key_id: $access_key_id/" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    access_key_secret: .*/    access_key_secret: $access_key_secret/" "$OVERRIDE_CONFIG_FILE"
                ;;
            6)
                tts_provider_key="TencentTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了腾讯云 TTS。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://console.cloud.tencent.com/tts${RESET}"
                read -r -p "请输入 Secret ID: " secret_id
                read -r -p "请输入 Secret Key: " secret_key
                echo -e "${CYAN}🎤 音色模型选择：${RESET}"
                echo "  标准音色：100012 (男声青年-标准), 100018 (女声青年-标准)"
                echo "  精品音色：101004 (男声青年), 101008 (男声中青年), 101014 (男声中老年)"
                echo "           101010 (女声青年), 101016 (女声中年), 101020 (女声中老年)"
                echo "  默认音色：101014 (男声中老年)"
                read -r -p "请输入音色ID (默认使用 101014): " voice
                voice=${voice:-"101014"}
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    secret_id: .*/    secret_id: $secret_id/" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    secret_key: .*/    secret_key: $secret_key/" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    voice: .*/    voice: $voice/" "$OVERRIDE_CONFIG_FILE"
                ;;
            7)
                tts_provider_key="TTS302AI"
                echo -e "\n${YELLOW}⚠️ 您选择了 302AI TTS。${RESET}"
                echo -e "${CYAN}🔑 密钥获取地址：https://www.302ai.com/${RESET}"
                read -r -p "请输入 Access Token: " access_token
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    access_token: .*/    access_token: $access_token/" "$OVERRIDE_CONFIG_FILE"
                ;;
            8)
                tts_provider_key="GizwitsTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了机智云 TTS。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://www.gizwits.com/${RESET}"
                read -r -p "请输入 Access Token: " access_token
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    access_token: .*/    access_token: $access_token/" "$OVERRIDE_CONFIG_FILE"
                ;;
            9)
                tts_provider_key="ACGNTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了 ACGN TTS。${RESET}"
                echo -e "${CYAN}ℹ️ 需自行部署 ACGN TTS 服务${RESET}"
                echo -e "${CYAN}🔗 支持HTTP和HTTPS双协议配置${RESET}"
                read -r -p "请输入HTTP服务地址 (默认 http://localhost:8080): " http_url
                http_url=${http_url:-"http://localhost:8080"}
                read -r -p "请输入HTTPS服务地址 (默认 https://localhost:8081): " https_url
                https_url=${https_url:-"https://localhost:8081"}
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s|^    base_url: .*|    base_url: $http_url|" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s|^    https_url: .*|    https_url: $https_url|" "$OVERRIDE_CONFIG_FILE"
                ;;
            10)
                tts_provider_key="OpenAITTS"
                echo -e "\n${YELLOW}⚠️ 您选择了 OpenAI TTS。${RESET}"
                echo -e "${CYAN}🔑 密钥获取地址：https://platform.openai.com/settings/organization/api-keys${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                read -r -p "请输入 代理地址 (选填): " http_proxy
                http_proxy="${http_proxy:-}"
                echo -e "${CYAN}🎤 音色模型选择：${RESET}"
                echo "  可选音色：alloy (默认), echo, fable, onyx, nova, shimmer"
                read -r -p "请输入音色 (默认使用 alloy): " voice
                voice=${voice:-"alloy"}
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
                fi
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    voice: .*/    voice: $voice/" "$OVERRIDE_CONFIG_FILE"
                [ -n "$http_proxy" ] && sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    http_proxy: .*/    http_proxy: \"$http_proxy\"/" "$OVERRIDE_CONFIG_FILE"
                ;;
            11)
                tts_provider_key="CustomTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了自定义 TTS。${RESET}"
                echo -e "${CYAN}🔗 支持HTTP和HTTPS双协议配置${RESET}"
                read -r -p "请输入类型 (edge/doubao/aliyun 等): " type
                read -r -p "请输入HTTP服务地址: " http_url
                read -r -p "请输入HTTPS服务地址: " https_url
                read -r -p "请输入 API Key (选填): " api_key
                read -r -p "请输入 音色 (选填): " voice
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    type: .*/    type: $type/" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s|^    base_url: .*|    base_url: $http_url|" "$OVERRIDE_CONFIG_FILE"
                [ -n "$https_url" ] && sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s|^    https_url: .*|    https_url: $https_url|" "$OVERRIDE_CONFIG_FILE"
                [ -n "$api_key" ] && sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: $api_key/" "$OVERRIDE_CONFIG_FILE"
                [ -n "$voice" ] && sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    voice: .*/    voice: $voice/" "$OVERRIDE_CONFIG_FILE"
                ;;
            12)
                tts_provider_key="LinkeraiTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了 LinkerAI TTS。${RESET}"
                echo -e "${CYAN}🔑 密钥获取地址：https://www.linkerai.com/${RESET}"
                read -r -p "请输入 Access Token: " access_token
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    access_token: .*/    access_token: $access_token/" "$OVERRIDE_CONFIG_FILE"
                ;;
            13)
                tts_provider_key="PaddleSpeechTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了百度飞桨 PaddleSpeech TTS。${RESET}"
                echo -e "${CYAN}ℹ️ 需自行部署 PaddleSpeech 服务${RESET}"
                echo -e "${CYAN}🔗 支持HTTP和HTTPS双协议配置${RESET}"
                read -r -p "请输入HTTP服务地址 (默认 http://localhost:8001): " http_url
                http_url=${http_url:-"http://localhost:8001"}
                read -r -p "请输入HTTPS服务地址 (默认 https://localhost:8002): " https_url
                https_url=${https_url:-"https://localhost:8002"}
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s|^    base_url: .*|    base_url: $http_url|" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s|^    https_url: .*|    https_url: $https_url|" "$OVERRIDE_CONFIG_FILE"
                ;;
            14)
                tts_provider_key="IndexStreamTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了 Index-TTS-vLLM。${RESET}"
                echo -e "${CYAN}ℹ️ 需自行部署 Index-TTS-vLLM 服务${RESET}"
                echo -e "${CYAN}🔗 支持HTTP和HTTPS双协议配置${RESET}"
                read -r -p "请输入HTTP服务地址 (默认 http://localhost:7860): " http_url
                http_url=${http_url:-"http://localhost:7860"}
                read -r -p "请输入HTTPS服务地址 (默认 https://localhost:7861): " https_url
                https_url=${https_url:-"https://localhost:7861"}
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s|^    base_url: .*|    base_url: $http_url|" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s|^    https_url: .*|    https_url: $https_url|" "$OVERRIDE_CONFIG_FILE"
                ;;
            15)
                tts_provider_key="AliBLTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了阿里云百炼 TTS。${RESET}"
                echo -e "${CYAN}🔑 密钥获取地址：https://bailian.console.aliyun.com/#/api-key${RESET}"
                read -r -p "请输入 API Key: " api_key
                echo -e "${CYAN}🎤 音色模型选择：${RESET}"
                echo "  可选音色：female-yujie, female-chengshu, female-shaonv, male-qingshu"
                echo "  默认音色：female-yujie"
                read -r -p "请输入音色 (默认使用 female-yujie): " voice
                voice=${voice:-"female-yujie"}
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: $api_key/" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    voice: .*/    voice: $voice/" "$OVERRIDE_CONFIG_FILE"
                ;;
            16)
                tts_provider_key="XunFeiTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了讯飞 TTS。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://www.xfyun.cn/services/tts${RESET}"
                read -r -p "请输入 APP ID: " app_id
                app_id="${app_id:-}"
                read -r -p "请输入 API Secret: " api_secret
                api_secret="${api_secret:-}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                echo -e "${CYAN}🎤 音色模型选择：${RESET}"
                echo "  可选音色：xiaoyi (小艺-女声),xiaocheng (小智-男声),xiaomo (小萌-女声)"
                echo "           yijun (一君-男声),xiaoyiyanse (小艺-女声-音色),xiaomeng (小萌-女声-音色)"
                echo "  默认音色：xiaoyi (小艺-女声)"
                read -r -p "请输入音色 (默认使用 xiaoyi): " voice
                voice=${voice:-"xiaoyi"}
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    voice: .*/    voice: $voice/" "$OVERRIDE_CONFIG_FILE"
                if [ -n "$app_id" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    app_id: .*/    app_id: \"$app_id\"/" "$OVERRIDE_CONFIG_FILE"
                fi
                if [ -n "$api_secret" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    api_secret: .*/    api_secret: \"$api_secret\"/" "$OVERRIDE_CONFIG_FILE"
                fi
                if [ -n "$api_key" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
                fi
                ;;
            *)
                tts_provider_key="EdgeTTS"
                echo -e "\n${YELLOW}⚠️ 输入无效，默认选择微软 EdgeTTS。${RESET}"
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
                ;;
        esac
        
        # 完成选择后退出循环
        tts_return_to_prev=true
    done
}

# ========================= Memory 配置（3个服务商） =========================
config_memory() {
    local return_to_main=false
    
    while [ "$return_to_main" = false ]; do
        echo -e "\n\n${GREEN}【5/5】配置 Memory (记忆) 服务${RESET}"
        echo "请选择Memory模式（共3个）："
        echo " 0) ${YELLOW} 返回上一步 ${RESET}"
        echo " 1) 不开启记忆 (nomem) [推荐]"
        echo " 2) 本地短记忆 (mem_local_short) - 隐私优先"
        echo " 3) Mem0AI (mem0ai) - 支持超长记忆 (每月免费1000次)"
        
        read -r -p "请输入序号 (默认推荐 1，输入0返回上一步): " memory_choice
        memory_choice=${memory_choice:-1}
        
        # 处理返回上一步
        if [ "$memory_choice" = "0" ]; then
            config_tts
            continue
        fi

        local memory_provider_key
        case $memory_choice in
            1)
                memory_provider_key="nomem"
                echo -e "\n${GREEN}✅ 已选择不开启记忆功能。${RESET}"
                sed -i "/^  Memory: /c\  Memory: $memory_provider_key" "$OVERRIDE_CONFIG_FILE"
                ;;
            2)
                memory_provider_key="mem_local_short"
                echo -e "\n${YELLOW}⚠️ 您选择了本地短记忆。${RESET}"
                sed -i "/^  Memory: /c\  Memory: $memory_provider_key" "$OVERRIDE_CONFIG_FILE"
                ;;
            3)
                memory_provider_key="mem0ai"
                echo -e "\n${YELLOW}⚠️ 您选择了 Mem0AI。${RESET}"
                echo -e "${CYAN}🔑 密钥获取地址：https://app.mem0.ai/dashboard/api-keys${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                
                sed -i "/^  Memory: /c\  Memory: $memory_provider_key" "$OVERRIDE_CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $memory_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
                fi
                ;;
            *)
                memory_provider_key="nomem"
                echo -e "\n${YELLOW}⚠️ 输入无效，默认选择不开启记忆功能。${RESET}"
                sed -i "/^  Memory: /c\  Memory: $memory_provider_key" "$OVERRIDE_CONFIG_FILE"
                ;;
        esac
        
        # 完成选择后退出循环
        return_to_main=true
    done
}

config_server() {
    echo -e "\n\n${GREEN}【6/6】配置服务器地址 (自动生成)${RESET}"

    echo -e "${CYAN}ℹ️ 检测到您的服务器地址：${RESET}"
    echo -e "  - 内网IP：$INTERNAL_IP"
    echo -e "  - 公网IP：$EXTERNAL_IP"

    echo -e "\n${YELLOW}⚠️ 请选择部署场景：${RESET}"
    echo "1) 内网环境部署（仅内网访问，用内网IP）"
    echo "2) 公网环境部署（外网访问，用公网IP，需提前配置端口映射）"
    read -r -p "请输入序号 (默认1): " deploy_choice
    deploy_choice=${deploy_choice:-1}

    local ws_ip vision_ip deploy_type_color deploy_type_icon deploy_description ota_url
    
    case $deploy_choice in
        1)
            ws_ip="$INTERNAL_IP" vision_ip="$INTERNAL_IP"
            deploy_type_color="${GREEN}" deploy_type_icon="✅" deploy_description="内网环境部署"
            ota_url="http://$INTERNAL_IP:8003/xiaozhi/ota/"
            CURRENT_DEPLOY_TYPE="internal"
            echo -e "${GREEN}✅ 已选择内网环境部署${RESET}" ;;
        2)
            ws_ip="$EXTERNAL_IP" vision_ip="$EXTERNAL_IP"
            deploy_type_color="${YELLOW}" deploy_type_icon="⚠️" deploy_description="公网环境部署"
            ota_url="http://$EXTERNAL_IP:8003/xiaozhi/ota/"
            CURRENT_DEPLOY_TYPE="public"
            echo -e "${GREEN}✅ 已选择公网环境部署${RESET}"
            echo -e "${YELLOW}⚠️ 请确保路由器已配置端口映射（8000端口用于WebSocket，8003端口用于OTA/视觉接口）${RESET}" ;;
        *)
            ws_ip="$INTERNAL_IP" vision_ip="$INTERNAL_IP"
            deploy_type_color="${RED}" deploy_type_icon="❌" deploy_description="默认内网环境部署"
            ota_url="http://$INTERNAL_IP:8003/xiaozhi/ota/"
            CURRENT_DEPLOY_TYPE="internal"
            echo -e "${YELLOW}⚠️ 输入无效，默认选择内网环境部署${RESET}" ;;
    esac

    local ws_url="ws://$ws_ip:8000/xiaozhi/v1/"
    local vision_url="http://$vision_ip:8003/mcp/vision/explain"

    sed -i "s|^[[:space:]]*websocket:[[:space:]]*.*$|  websocket: \"$ws_url\"|" "$OVERRIDE_CONFIG_FILE"
    sed -i "s|^[[:space:]]*vision_explain:[[:space:]]*.*$|  vision_explain: \"$vision_url\"|" "$OVERRIDE_CONFIG_FILE"

    echo -e "\n${GREEN}✅ 服务器地址配置完成：${RESET}"
    echo -e "  - WebSocket地址：$ws_url"
    echo -e "  - 视觉分析接口地址：$vision_url"
    
    echo -e "\n${deploy_type_color}${deploy_type_icon} ${deploy_description} 配置完成${RESET}"
    echo -e "${deploy_type_color}📋 您的OTA地址：${BOLD}${ota_url}${RESET}"
    echo -e "${deploy_type_color}💡 请在填写OTA地址时使用上述完整地址${RESET}"
}

# ========================= 核心服务配置入口 =========================
config_keys() {
    local return_to_main=false
    
    # 如果选择了跳过详细配置，直接返回
    if [ "${SKIP_DETAILED_CONFIG:-false}" = true ]; then
        echo -e "\n${GREEN}✅ 检测到用户选择保留现有配置，跳过详细配置步骤${RESET}"
        echo -e "${CYAN}ℹ️ 将使用现有配置文件: $OVERRIDE_CONFIG_FILE${RESET}"
        export KEY_CONFIG_MODE="existing"
        return
    fi
    
    while [ "$return_to_main" = false ]; do
        echo -e "\n${PURPLE}==================================================${RESET}"
        echo -e "${CYAN}🔧 开始进行核心服务配置  🔧${RESET}"
        echo -e "${PURPLE}==================================================${RESET}"

        echo -e "\n${YELLOW}⚠️ 注意：若您计划使用本地ASR模型（如FunASR），请确保服务器内存≥4G。${RESET}"
        
        echo "1) 现在通过脚本配置密钥和服务商"
        echo "2) 稍后手动填写所有配置（脚本将预设在线服务商以避免启动报错）"
        echo "0) 退出配置（将使用默认配置）"
        read -r -p "请选择（默认1）：" key_choice
        key_choice=${key_choice:-1}
        
        # 处理退出配置
        if [ "$key_choice" = "0" ]; then
            echo -e "\n${YELLOW}⚠️ 确认退出详细配置流程？${RESET}"
            echo -e "${CYAN}ℹ️ 退出后将使用以下默认配置：${RESET}"
            echo -e "${CYAN}  - ASR: AliyunStreamASR (阿里云流式)${RESET}"
            echo -e "${CYAN}  - LLM: ChatGLMLLM (智谱清言)${RESET}"
            echo -e "${CYAN}  - VLLM: ChatGLMVLLM (智谱清言)${RESET}"
            echo -e "${CYAN}  - TTS: EdgeTTS (微软)${RESET}"
            echo -e "${CYAN}  - Memory: nomem (无记忆)${RESET}"
            echo -e "${CYAN}ℹ️ 默认配置路径：$OVERRIDE_CONFIG_FILE${RESET}"
            
            # 进入第三级菜单
            echo -e "\n${YELLOW}⚠️ 确认退出并使用默认配置？${RESET}"
            echo -e "${RED}⚠️ 注意：如果服务器配置不足（内存<4GB），使用本地ASR模型可能会卡死。${RESET}"
            
            # 根据内存状况显示docker选项
            if [ "$IS_MEMORY_SUFFICIENT" = true ]; then
                echo "1) 不执行docker安装 退出"
                echo "2) 执行docker 退出"
            else
                echo "1) 不执行docker安装 退出"
                echo -e "2) ${RED}执行docker 退出${RESET} ${RED}❌ 不推荐${RESET}"
            fi
            echo "0) 返回上级菜单"
            echo ""
            
            read -r -p "请选择：" final_choice
            
            # 处理最终选择
            if [ "$final_choice" = "0" ]; then
                continue  # 返回上级菜单
            elif [ "$final_choice" = "1" ]; then
                echo -e "\n${GREEN}✅ 已使用默认配置，不执行docker安装，脚本结束。${RESET}"
                # 设置默认配置
                sed -i "s/selected_module:.*/selected_module:\n  VAD: SileroVAD\n  ASR: AliyunStreamASR\n  LLM: ChatGLMLLM\n  VLLM: ChatGLMVLLM\n  TTS: EdgeTTS\n  Memory: nomem\n  Intent: function_call/" "$OVERRIDE_CONFIG_FILE"
                
                local ws_url="ws://$INTERNAL_IP:8000/xiaozhi/v1/"
                local vision_url="http://$INTERNAL_IP:8003/mcp/vision/explain"
                sed -i "s|^[[:space:]]*websocket:[[:space:]]*.*$|  websocket: \"$ws_url\"|" "$OVERRIDE_CONFIG_FILE"
                sed -i "s|^[[:space:]]*vision_explain:[[:space:]]*.*$|  vision_explain: \"$vision_url\"|" "$OVERRIDE_CONFIG_FILE"
                
                # 脚本结束，不执行docker
                exit 0
            elif [ "$final_choice" = "2" ]; then
                echo -e "\n${GREEN}✅ 已使用默认配置，执行docker安装，脚本将继续执行...${RESET}"
                # 设置默认配置
                sed -i "s/selected_module:.*/selected_module:\n  VAD: SileroVAD\n  ASR: AliyunStreamASR\n  LLM: ChatGLMLLM\n  VLLM: ChatGLMVLLM\n  TTS: EdgeTTS\n  Memory: nomem\n  Intent: function_call/" "$OVERRIDE_CONFIG_FILE"
                
                local ws_url="ws://$INTERNAL_IP:8000/xiaozhi/v1/"
                local vision_url="http://$INTERNAL_IP:8003/mcp/vision/explain"
                sed -i "s|^[[:space:]]*websocket:[[:space:]]*.*$|  websocket: \"$ws_url\"|" "$OVERRIDE_CONFIG_FILE"
                sed -i "s|^[[:space:]]*vision_explain:[[:space:]]*.*$|  vision_explain: \"$vision_url\"|" "$OVERRIDE_CONFIG_FILE"
                
                CURRENT_DEPLOY_TYPE="internal"
                export KEY_CONFIG_MODE="manual"
                return_to_main=true
                continue
            fi
        elif [ "$key_choice" = "2" ]; then
            echo -e "\n${YELLOW}⚠️ 已选择稍后手动填写。${RESET}"
            echo -e "${CYAN}ℹ️ 为防止服务启动失败，脚本将自动将服务商预设为 \"AliyunStreamASR\" 和 \"ChatGLMLLM\"。${RESET}"
            echo -e "${CYAN}ℹ️ 您可以稍后在配置文件中修改为您喜欢的服务商。配置文件路径：$OVERRIDE_CONFIG_FILE${RESET}"
            sed -i "s/selected_module:.*/selected_module:\n  VAD: SileroVAD\n  ASR: AliyunStreamASR\n  LLM: ChatGLMLLM\n  VLLM: ChatGLMVLLM\n  TTS: EdgeTTS\n  Memory: nomem\n  Intent: function_call/" "$OVERRIDE_CONFIG_FILE"
            
            local ws_url="ws://$INTERNAL_IP:8000/xiaozhi/v1/"
            local vision_url="http://$INTERNAL_IP:8003/mcp/vision/explain"
            sed -i "s|^[[:space:]]*websocket:[[:space:]]*.*$|  websocket: \"$ws_url\"|" "$OVERRIDE_CONFIG_FILE"
            sed -i "s|^[[:space:]]*vision_explain:[[:space:]]*.*$|  vision_explain: \"$vision_url\"|" "$OVERRIDE_CONFIG_FILE"
            
            CURRENT_DEPLOY_TYPE="internal"
            export KEY_CONFIG_MODE="manual"
            return_to_main=true
            continue
        fi

        if [[ "$key_choice" == "1" ]]; then
            echo -e "\n${GREEN}✅ 开始进行详细配置...${RESET}"
            config_asr
            config_llm
            config_vllm
            config_tts
            config_memory
            config_server

            echo -e "\n${PURPLE}==================================================${RESET}"
            echo -e "${GREEN}🎉 核心服务配置完成！${RESET}"
            echo -e "${CYAN}ℹ️ 详细配置文件已保存至: $OVERRIDE_CONFIG_FILE${RESET}"
            echo -e "${PURPLE}==================================================${RESET}"
            export KEY_CONFIG_MODE="auto"
            
            return_to_main=true
            continue
        fi
    done
}

# ========================= 服务启动 =========================
start_service() {
    check_docker_installed
    echo -e "\n${BLUE}🚀 开始启动服务...${RESET}"
    cd "$MAIN_DIR" || { echo -e "${RED}❌ 进入目录 $MAIN_DIR 失败${RESET}"; exit 1; }
    retry_exec "docker compose up -d" "启动Docker服务"
    
    echo -e "${CYAN}🔍 正在检查服务状态...${RESET}"
    sleep 5

    if docker ps --filter "name=^/${CONTAINER_NAME}$" --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
        echo -e "\n${GREEN}🎉 小智服务器启动成功！${RESET}"
        [[ "${KEY_CONFIG_MODE:-manual}" == "manual" ]] && {
            echo -e "${YELLOW}⚠️ 您选择了手动配置，请尽快编辑配置文件：$OVERRIDE_CONFIG_FILE${RESET}"
            echo -e "${YELLOW}⚠️ 配置完成后，请重启服务：docker restart $CONTAINER_NAME${RESET}"
        }
        echo -e "\n${CYAN}📄 最后10行服务日志：${RESET}"
        docker logs --tail 10 "$CONTAINER_NAME"
    else
        echo -e "${RED}❌ 服务启动异常，请查看完整日志了解详情:${RESET}"
        echo -e "${RED}   docker logs $CONTAINER_NAME${RESET}"
        exit 1
    fi
}

# ========================= 连接信息展示 =========================
show_connection_info() {
    # 等待Docker服务完全启动
    echo -e "\n${YELLOW}⏳ Docker服务启动中，等待10秒确保服务完全启动...${RESET}"
    echo -e "${YELLOW}🔄 倒计时：${RESET}"
    for i in {10..1}; do
        echo -ne "\r${YELLOW}   倒计时: ${i} 秒${RESET}"
        sleep 1
    done
    echo -e "\n${GREEN}✅ 等待完成，开始进行端口检查${RESET}"
    
    echo -e "\n${PURPLE}==================================================${RESET}"
    echo -e "${CYAN}📡 服务器连接地址信息${RESET}"
    echo -e "${PURPLE}==================================================${RESET}"
    echo -e "内网地址：$INTERNAL_IP"
    echo -e "公网地址：$EXTERNAL_IP"
    echo -e "${PURPLE}--------------------------------------------------${RESET}"
    
    # 先显示所有可用地址
    echo -e "${GREEN}OTA接口（内网）：${BOLD}http://$INTERNAL_IP:8003/xiaozhi/ota/${RESET}"
    echo -e "${GREEN}OTA接口（公网）：${BOLD}http://$EXTERNAL_IP:8003/xiaozhi/ota/${RESET}"
    echo -e "${GREEN}Websocket接口：${BOLD}ws://$INTERNAL_IP:8000/xiaozhi/v1/${RESET}"
    echo -e "${GREEN}Websocket接口：${BOLD}ws://$EXTERNAL_IP:8000/xiaozhi/v1/${RESET}"
    echo -e "${PURPLE}--------------------------------------------------${RESET}"
    
    # 显示当前部署类型和推荐地址
    if [ "$CURRENT_DEPLOY_TYPE" = "internal" ]; then
        echo -e "${GREEN}OTA接口（当前部署类型 - 内网环境）：${BOLD}http://$INTERNAL_IP:8003/xiaozhi/ota/${RESET}"
        echo -e "${YELLOW}💡 您的当前部署类型为内网环境，请使用上述OTA地址进行设备配置${RESET}"
        echo -e "${YELLOW}💡 如果需要从公网访问，请确保路由器已配置端口映射（8000, 8003）${RESET}"
    elif [ "$CURRENT_DEPLOY_TYPE" = "public" ]; then
        echo -e "${YELLOW}OTA接口（当前部署类型 - 公网环境）：${BOLD}http://$EXTERNAL_IP:8003/xiaozhi/ota/${RESET}"
        echo -e "${YELLOW}💡 您的当前部署类型为公网环境，请使用上述OTA地址进行设备配置${RESET}"
        echo -e "${YELLOW}💡 确保路由器已配置端口映射（8000, 8003）${RESET}"
    else
        echo -e "${YELLOW}💡 请根据您的部署方式选择相应的OTA地址${RESET}"
    fi
    
    echo -e "${PURPLE}==================================================${RESET}"
    
    # 根据部署类型进行端口检查
    if [ "$CURRENT_DEPLOY_TYPE" = "public" ]; then
        echo -e "\n${YELLOW}📋 现在进行公网端口连通性检查...${RESET}"
        check_network_ports "$EXTERNAL_IP" "公网"
    elif [ "$CURRENT_DEPLOY_TYPE" = "internal" ]; then
        echo -e "\n${YELLOW}📋 现在进行内网端口连通性检查...${RESET}"
        check_network_ports "$INTERNAL_IP" "内网"
    else
        echo -e "\n${YELLOW}📋 进行全面的端口连通性检查...${RESET}"
        echo -e "${CYAN}🌐 检查内网连通性:${RESET}"
        check_network_ports "$INTERNAL_IP" "内网"
        echo -e "\n${CYAN}🌐 检查公网连通性:${RESET}"
        check_network_ports "$EXTERNAL_IP" "公网"
    fi
    
    # 添加端口检查方法详细说明
    echo -e "\n${CYAN}🔧 端口检查方法详细说明${RESET}"
    echo -e "${PURPLE}=======================================================${RESET}"
    echo -e "${YELLOW}📊 端口检查技术原理：${RESET}"
    echo -e "${CYAN}  公网端口查询方法：${RESET}"
    echo -e "    • OTA端口(8003): 使用 ${BOLD}curl -s -o /dev/null -w '%{http_code}' --connect-timeout 3 http://IP:8003/xiaozhi/ota/${RESET}"
    echo -e "    • WebSocket端口(8000): 使用 ${BOLD}timeout 5 nc -z IP 8000${RESET}"
    echo -e "    • HTTP状态码: 200=成功连接, 404=服务存在但路径错误, 000=连接失败"
    
    echo -e "\n${CYAN}  内网端口查询方法：${RESET}"
    echo -e "    • OTA端口(8003): 使用 ${BOLD}curl -s -o /dev/null -w '%{http_code}' --connect-timeout 3 http://内网IP:8003/xiaozhi/ota/${RESET}"
    echo -e "    • WebSocket端口(8000): 使用 ${BOLD}timeout 5 nc -z 内网IP 8000${RESET}"
    echo -e "    • nc(netcat): 检查TCP端口是否开放，无HTTP响应但能验证端口连通性"
    
    echo -e "\n${YELLOW}💡 手动检查命令示例：${RESET}"
    echo -e "${CYAN}  检查OTA接口：${RESET} curl http://$INTERNAL_IP:8003/xiaozhi/ota/"
    echo -e "${CYAN}  检查WebSocket：${RESET} timeout 3 nc -z $INTERNAL_IP 8000"
    echo -e "${CYAN}  检查服务状态：${RESET} docker ps --filter name=$CONTAINER_NAME"
    echo -e "${CYAN}  查看服务日志：${RESET} docker logs $CONTAINER_NAME --tail 20"
    
    echo -e "\n${YELLOW}🔍 连接诊断流程：${RESET}"
    echo -e "    1. ${CYAN}HTTP连接测试：${RESET}curl 检查OTA端口返回状态码和内容"
    echo -e "    2. ${CYAN}TCP连接测试：${RESET}nc 检查WebSocket端口是否开放"
    echo -e "    3. ${CYAN}内容验证：${RESET}如果HTTP 200/404，获取OTA页面内容确认服务正常"
    echo -e "    4. ${CYAN}网络诊断：${RESET}根据连接失败类型提供对应的故障排除建议"
    
    echo -e "\n${PURPLE}=======================================================${RESET}"
}

# ========================= 通用端口检查函数 =========================
check_network_ports() {
    local target_ip="$1"
    local deploy_type="$2"
    local ota_port=8003
    local ws_port=8000
    local ota_url="http://$target_ip:$ota_port/xiaozhi/ota/"
    
    echo -e "\n${CYAN}🔍 开始检查${deploy_type}端口连通性...${RESET}"
    echo -e "${YELLOW}🌐 检查目标IP: $target_ip${RESET}"
    echo -e "${CYAN}──────────────────────────────────────────────────${RESET}"
    
    # 检查OTA端口 (8003)
    echo -e "${CYAN}📡 检查OTA端口 $ota_port...${RESET}"
    if timeout 5 curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "$ota_url" > /tmp/ota_status 2>/dev/null; then
        local ota_status=$(cat /tmp/ota_status)
        if [ "$ota_status" = "200" ] || [ "$ota_status" = "404" ]; then
            echo -e "${GREEN}✅ OTA端口 $ota_port 连接正常${RESET}"
            
            # 获取OTA内容
            echo -e "${CYAN}📋 获取OTA内容（使用curl命令访问）...${RESET}"
            echo -e "${YELLOW}🔗 访问地址: $ota_url${RESET}"
            
            if timeout 15 curl -s "$ota_url" > /tmp/ota_content 2>/dev/null; then
                local ota_content=$(cat /tmp/ota_content)
                if [ -n "$ota_content" ] && [ "$ota_content" != "Connection refused" ]; then
                    echo -e "${GREEN}📄 OTA服务器响应内容：${RESET}"
                    echo -e "${CYAN}──────────────────────────────────────────────────${RESET}"
                    echo "$ota_content" | head -30 | sed 's/^/    /'  # 显示前30行，每行前面加缩进
                    if [ $(echo "$ota_content" | wc -l) -gt 30 ]; then
                        echo -e "${CYAN}    ... (内容过长，已截取前30行)${RESET}"
                    fi
                    echo -e "${CYAN}──────────────────────────────────────────────────${RESET}"
                    
                    echo -e "${GREEN}✅ OTA服务正常运行，配置正确${RESET}"
                    echo -e "${CYAN}💡 请使用上述OTA地址进行设备配置${RESET}"
                    echo -e "${CYAN}💡 curl命令示例：curl $ota_url${RESET}"
                else
                    echo -e "${YELLOW}⚠️ OTA服务已启动但返回空内容或拒绝连接${RESET}"
                fi
            else
                echo -e "${YELLOW}⚠️ 无法获取OTA内容（连接超时或服务器未响应）${RESET}"
                echo -e "${YELLOW}💡 建议手动测试：curl $ota_url${RESET}"
            fi
        else
            echo -e "${YELLOW}⚠️ OTA端口连接异常 (HTTP状态码: $ota_status)${RESET}"
        fi
    else
        echo -e "${RED}❌ OTA端口 $ota_port 无法访问${RESET}"
    fi
    
    echo
    
    # 检查WebSocket端口 (8000)
    echo -e "${CYAN}🔌 检查WebSocket端口 $ws_port...${RESET}"
    
    # 使用nc检查端口是否开放
    if timeout 5 nc -z "$target_ip" "$ws_port" 2>/dev/null; then
        echo -e "${GREEN}✅ WebSocket端口 $ws_port 连接正常${RESET}"
    else
        echo -e "${RED}❌ WebSocket端口 $ws_port 无法访问${RESET}"
    fi
    
    echo -e "${CYAN}──────────────────────────────────────────────────${RESET}"
    
    # 总结端口状态
    local ports_ok=true
    if ! timeout 5 curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "$ota_url" > /tmp/ota_check 2>/dev/null; then
        ports_ok=false
    fi
    if ! timeout 5 nc -z "$target_ip" "$ws_port" 2>/dev/null; then
        ports_ok=false
    fi
    
    if [ "$ports_ok" = true ]; then
        echo -e "${GREEN}✅ ${deploy_type}端口检查完成 - 所有端口连接正常${RESET}"
    else
        echo -e "${RED}❌ ${deploy_type}端口检查发现问题${RESET}"
        if [ "$deploy_type" = "公网" ]; then
            echo -e "${YELLOW}🔧 请检查以下配置：${RESET}"
            echo -e "  ${YELLOW}• 云服务器：${RESET}在云服务器控制台安全组中放行端口 $ws_port 和 $ota_port"
            echo -e "  ${YELLOW}• 家庭网络：${RESET}在路由器中配置端口映射或DMZ设置"
            echo -e "  ${YELLOW}• 防火墙：${RESET}确保云防火墙或硬件防火墙未阻止这些端口"
            echo -e "  ${YELLOW}• 服务状态：${RESET}确认Docker容器和服务正在运行"
        else
            echo -e "${YELLOW}🔧 请检查以下配置：${RESET}"
            echo -e "  ${YELLOW}• Docker服务：${RESET}确认Docker容器正在运行"
            echo -e "  ${YELLOW}• 防火墙：${RESET}确认系统防火墙未阻止端口访问"
            echo -e "  ${YELLOW}• 网络配置：${RESET}确认内网IP配置正确"
        fi
        echo -e "${CYAN}💡 配置完成后，可重新运行脚本来验证端口连通性${RESET}"
    fi
    
    # 清理临时文件
    rm -f /tmp/ota_status /tmp/ota_content /tmp/ota_check
}

# ========================= 主执行流程 =================
check_system() {
    echo -e "\n${CYAN}🔍 正在检测系统环境...${RESET}"
    local os_kernel=$(uname -s)
    local os_info=$(uname -a)
    local unsupported_msg=""
    local is_supported=false
    
    case "$os_kernel" in
        Linux*)
            if [[ -f /termux/setup-storage || "$os_info" =~ termux ]]; then
                unsupported_msg="Termux (Android)"
            else
                is_supported=true
            fi
            ;;
        Darwin*)
            unsupported_msg="macOS" ;;
        CYGWIN*|MINGW*|MSYS*)
            unsupported_msg="Windows" ;;
        *)
            unsupported_msg="未知系统 ($os_kernel)" ;;
    esac
    
    if [ "$is_supported" = false ]; then
        echo -e "${RED}==================================================${RESET}"
        echo -e "${RED}⚠️ 警告：本脚本不适用于 $unsupported_msg 系统${RESET}"
        echo -e "${RED}⚠️ 当前系统信息：$os_info${RESET}"
        echo -e "${RED}⚠️ 强制执行可能导致未知错误，请谨慎操作！${RESET}"
        echo -e "${RED}==================================================${RESET}"
        
        read -r -p "❓ 是否强制执行？(Y/N，默认N): " choice
        choice=${choice:-N}
        
        if [[ "$choice" != "Y" && "$choice" != "y" ]]; then
            echo -e "${GREEN}👋 已取消执行，脚本退出${RESET}"
            exit 0
        fi
    fi
    
    echo -e "${GREEN}✅ 系统检测通过，继续执行脚本...${RESET}"
}

# ========================= 防火墙检查 =================
check_firewall() {
    echo -e "\n${CYAN}🔍 检查防火墙设置...${RESET}"
    
    # 检查 ufw 状态
    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            echo -e "${YELLOW}⚠️ 检测到 UFW 防火墙已启用${RESET}"
            echo -e "${CYAN}💡 建议开放以下端口：${RESET}"
            echo -e "  - sudo ufw allow 8000  # WebSocket 服务"
            echo -e "  - sudo ufw allow 8003  # OTA/视觉接口服务"
            read -r -p "是否现在开放这些端口？(y/n，默认n): " open_ports
            open_ports=${open_ports:-n}
            if [[ "$open_ports" == "y" || "$open_ports" == "Y" ]]; then
                sudo ufw allow 8000 && sudo ufw allow 8003
                echo -e "${GREEN}✅ 端口已开放${RESET}"
            else
                echo -e "${CYAN}ℹ️ 端口未开放，请根据需要手动配置${RESET}"
            fi
        fi
    fi
    
    # 检查 firewalld 状态
    if command -v firewall-cmd &> /dev/null; then
        if systemctl is-active --quiet firewalld; then
            echo -e "${YELLOW}⚠️ 检测到 Firewalld 防火墙已启用${RESET}"
            echo -e "${CYAN}💡 建议开放以下端口：${RESET}"
            echo -e "  - sudo firewall-cmd --permanent --add-port=8000/tcp"
            echo -e "  - sudo firewall-cmd --permanent --add-port=8003/tcp"
            echo -e "  - sudo firewall-cmd --reload"
            echo -e "${CYAN}ℹ️ 请根据上述命令手动配置防火墙${RESET}"
        fi
    fi
    
    echo -e "${GREEN}✅ 防火墙检查完成${RESET}"
}

# ========================= 主执行函数 =========================
main() {
    check_root_permission
    check_system
    install_dependencies
    check_server_config 
    show_start_ui        
    show_server_config 

    read -r -p "🔧 是否开始部署小智服务器？(y/n，默认y)：" install_choice
    install_choice=${install_choice:-y}
    [[ "$install_choice" != "y" && "$install_choice" != "Y" ]] && {
      echo -e "${PURPLE}👋 已取消部署，脚本退出${RESET}"
      exit 0
    }

    check_and_install_docker
    clean_container
    create_dirs
    setup_config_file
    download_files "$CONFIG_DOWNLOAD_NEEDED"
    config_keys
    check_firewall
    start_service
    show_connection_info

    echo -e "\n${PURPLE}==================================================${RESET}"
    echo -e "${GREEN}🎊 小智服务器部署成功！！🎊${RESET}"
    echo -e "${GREEN}🥳🥳🥳 请尽情使用吧 🥳🥳🥳${RESET}"
    echo -e "${PURPLE}==================================================${RESET}"
}

# 启动脚本执行
main "$@"
