#!/bin/bash
set -uo pipefail
trap exit_confirm SIGINT

# ========================= 基础配置 =========================
# 小智服务器一键部署脚本：修复版本
# 修复逻辑性问题，优化代码结构，提升稳定性
# 作者@昊天兽王 | 最终修复版本
AUTHOR="昊天兽王" 
SCRIPT_DESC="小智服务器一键部署脚本：自动安装Docker、配置ASR/LLM/VLLM/TTS、启动服务"
Version="1.0.3-fixed-final"

# 配置文件链接（修复重复链接问题）
CONFIG_FILE_URL="https://gh-proxy.com/https://raw.githubusercontent.com/haotianshouwang/xiaozhi-server-installer-docker.sh/refs/heads/main/config.yaml"
CONFIG_FILE_URL_BACKUP="https://gh-proxy.com/https://raw.githubusercontent.com/xinnan-tech/xiaozhi-esp32-server/refs/heads/main/xiaozhi-server/config.yaml"
CONFIG_FILE_URL_FALLBACK="https://mirror.ghproxy.com/https://raw.githubusercontent.com/xinnan-tech/xiaozhi-esp32-server/refs/heads/main/xiaozhi-server/config.yaml"
DOCKER_COMPOSE_URL="https://gh-proxy.com/https://raw.githubusercontent.com/xinnan-tech/xiaozhi-esp32-server/refs/heads/main/main/xiaozhi-server/docker-compose.yml"

MAIN_DIR="$HOME/xiaozhi-server"
CONTAINER_NAME="xiaozhi-esp32-server"
# 修复：只使用一个配置文件路径
CONFIG_FILE="$MAIN_DIR/data/.config.yaml"
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

# 服务器状态检测变量
CONTAINER_RUNNING=false
CONTAINER_EXISTS=false
SERVER_DIR_EXISTS=false
CONFIG_EXISTS=false

# ========================= 工具函数 =========================

# 安全输入函数，确保工作目录稳定
safe_read() {
    local prompt="$1"
    local var_name="$2"
    
    # 保存当前工作目录
    local pwd_backup
    pwd_backup="$(pwd)" 2>/dev/null || pwd_backup="/tmp"
    
    # 执行读取操作
    read -r -p "$prompt" "$var_name"
    
    # 恢复工作目录
    cd "$pwd_backup" 2>/dev/null || true
    
    return 0
}

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
        echo -e "${RED}⚠️ 权限不足，无法继续部署！${RESET}"
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

# ========================= 服务器状态检测函数 =========================
check_server_status() {
    echo -e "${CYAN}🔍 正在检测服务器状态...${RESET}"
    
    # 重置状态变量
    CONTAINER_RUNNING=false
    CONTAINER_EXISTS=false
    SERVER_DIR_EXISTS=false
    CONFIG_EXISTS=false
    
    # 修复：使用简化的容器检测逻辑
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        CONTAINER_EXISTS=true
        if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            CONTAINER_RUNNING=true
        fi
    fi
    
    # 检查目录和配置文件
    [ -d "$MAIN_DIR" ] && SERVER_DIR_EXISTS=true
    [ -f "$CONFIG_FILE" ] && CONFIG_EXISTS=true
    
    echo -e "${CYAN}📊 服务器状态检测结果：${RESET}"
    echo "  - Docker容器存在：$([ "$CONTAINER_EXISTS" = true ] && echo "✅ 是" || echo "❌ 否")"
    echo "  - Docker容器运行：$([ "$CONTAINER_RUNNING" = true ] && echo "✅ 是" || echo "❌ 否")"
    echo "  - 服务器目录存在：$([ "$SERVER_DIR_EXISTS" = true ] && echo "✅ 是" || echo "❌ 否")"
    echo "  - 配置文件存在：$([ "$CONFIG_EXISTS" = true ] && echo "✅ 是" || echo "❌ 否")"
    echo
}

# ========================= 主菜单函数 =========================
main_menu() {
    # 修复：确保工作目录安全，防止执行方式不同导致的问题
    check_working_directory
    
    # 修复无限循环问题：添加内部循环来处理无效输入
    while true; do
        check_server_status
    
    echo -e "${CYAN}🏠 主菜单${RESET}"
    echo -e "${PURPLE}==================================================${RESET}"
    
    if [ "$SERVER_DIR_EXISTS" = true ] && [ "$CONFIG_EXISTS" = true ]; then
        echo -e "${YELLOW}检测到已存在的小智服务器配置${RESET}"
        if [ "$CONTAINER_RUNNING" = true ]; then
            echo -e "${GREEN}🟢 服务器正在运行中${RESET}"
        elif [ "$CONTAINER_EXISTS" = true ]; then
            echo -e "${YELLOW}🟡 服务器已停止${RESET}"
        else
            echo -e "${RED}🔴 服务器未运行${RESET}"
        fi
        echo
        echo "请选择操作："
        echo "1) 重新开始部署 (删除现有并重新部署)"
        echo "2) 更新服务器 (保留配置，更新到最新版本)"
        echo "3) 仅修改配置文件 (不下载服务器文件)"
        echo "4) 测试服务器连接"
        echo "5) 测试服务器端口 (详细端口测试)"
        echo "6) 查看Docker日志"
        echo "7) 删除服务器 (完全删除所有数据)"
        echo "0) 退出脚本"
    else
        echo -e "${GREEN}欢迎使用小智服务器部署脚本${RESET}"
        echo
        echo "请选择操作："
        echo "1) 开始部署小智服务器"
        echo "0) 退出脚本"
    fi
    
    echo -e "${PURPLE}==================================================${RESET}"
    read -r -p "请输入选项: " menu_choice
    
    # 修复：处理空输入情况
    if [ -z "$menu_choice" ]; then
        echo -e "${YELLOW}⚠️ 请输入有效的选项编号${RESET}"
        sleep 1
        continue
    fi
    
    case $menu_choice in
        1)
            # 根据部署状态决定行为
            if [ "$SERVER_DIR_EXISTS" = true ] && [ "$CONFIG_EXISTS" = true ]; then
                # 服务器已部署 -> 重新部署
                redeploy_server
            else
                # 服务器未部署 -> 首次部署
                deploy_server
            fi
            break  # 修复：添加break退出循环
            ;;
        2)
            if [ "$SERVER_DIR_EXISTS" = true ] && [ "$CONFIG_EXISTS" = true ]; then
                update_server
                break  # 修复：添加break退出循环
            else
                echo -e "${RED}❌ 未检测到现有服务器，无法更新${RESET}"
                if [ "$SERVER_DIR_EXISTS" != true ] || [ "$CONFIG_EXISTS" != true ]; then
                    echo -e "${CYAN}💡 请先选择选项1进行首次部署${RESET}"
                fi
                read -r -p "按回车键继续..."
                break  # 修复：添加break退出循环
            fi
            ;;
        3)
            if [ "$SERVER_DIR_EXISTS" = true ] && [ "$CONFIG_EXISTS" = true ]; then
                config_only
                break  # 修复：添加break退出循环
            else
                echo -e "${RED}❌ 未检测到现有服务器配置${RESET}"
                if [ "$SERVER_DIR_EXISTS" != true ] || [ "$CONFIG_EXISTS" != true ]; then
                    echo -e "${CYAN}💡 请先选择选项1进行首次部署${RESET}"
                fi
                read -r -p "按回车键继续..."
                break  # 修复：添加break退出循环
            fi
            ;;
        4)
            if [ "$SERVER_DIR_EXISTS" = true ] && [ "$CONFIG_EXISTS" = true ]; then
                test_server
                break  # 修复：添加break退出循环
            else
                echo -e "${RED}❌ 未检测到现有服务器配置${RESET}"
                if [ "$SERVER_DIR_EXISTS" != true ] || [ "$CONFIG_EXISTS" != true ]; then
                    echo -e "${CYAN}💡 请先选择选项1进行首次部署${RESET}"
                fi
                read -r -p "按回车键继续..."
                break  # 修复：添加break退出循环
            fi
            ;;
        5)
            if [ "$SERVER_DIR_EXISTS" = true ] && [ "$CONFIG_EXISTS" = true ]; then
                test_ports
                break  # 修复：添加break退出循环
            else
                echo -e "${RED}❌ 未检测到现有服务器配置${RESET}"
                if [ "$SERVER_DIR_EXISTS" != true ] || [ "$CONFIG_EXISTS" != true ]; then
                    echo -e "${CYAN}💡 请先选择选项1进行首次部署${RESET}"
                fi
                read -r -p "按回车键继续..."
                break
            fi
            ;;
        6)
            docker_logs
            break  # 修复：添加break退出循环
            ;;
        7)
            if [ "$SERVER_DIR_EXISTS" = true ] || [ "$CONTAINER_EXISTS" = true ]; then
                delete_server
            else
                echo -e "${YELLOW}⚠️ 未检测到服务器数据${RESET}"
                read -r -p "按回车键继续..."
            fi
            break  # 修复：添加break退出循环
            ;;
        0)
            echo -e "${GREEN}👋 感谢使用，脚本退出${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ 无效选项，请重新选择${RESET}"
            if [ "$SERVER_DIR_EXISTS" = true ] && [ "$CONFIG_EXISTS" = true ]; then
                echo -e "${CYAN}💡 请输入1-7或0退出${RESET}"
            else
                echo -e "${CYAN}💡 请输入1或0退出${RESET}"
            fi
            sleep 2
            # 不使用return，而是继续循环让用户重新输入
            continue
            ;;
    esac
    done
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
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
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
        download_config_with_fallback "$CONFIG_FILE"
        retry_exec "curl -fSL $DOCKER_COMPOSE_URL -o $MAIN_DIR/docker-compose.yml" "下载 docker-compose.yml"
    else
        echo -e "\n${GREEN}✅ 跳过下载文件，使用现有配置文件${RESET}"
    fi
}

check_if_already_configured() {
    if [ -f "$CONFIG_FILE" ] && grep -q "selected_module:" "$CONFIG_FILE" 2>/dev/null; then
        return 0  # 已配置
    fi
    return 1  # 未配置
}

setup_config_file() {
    echo -e "\n${CYAN}📁 配置小智服务器配置文件...${RESET}"
    
    mkdir -p "$MAIN_DIR/data"
    echo -e "${GREEN}✅ 已创建 data 目录: $MAIN_DIR/data${RESET}"
    
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}📋 发现现有配置文件${RESET}"
        echo "配置文件: $CONFIG_FILE"
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
                if download_config_with_fallback "$CONFIG_FILE"; then
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
        if download_config_with_fallback "$CONFIG_FILE"; then
            echo -e "${GREEN}✅ 已下载配置文件: $CONFIG_FILE${RESET}"
            CONFIG_DOWNLOAD_NEEDED="true"
        else
            echo -e "${RED}❌ 配置文件下载失败${RESET}"
            exit 1
        fi
    fi
    
    echo ""
    echo -e "${CYAN}📊 配置文件状态:${RESET}"
    echo "文件: $CONFIG_FILE"
    echo "大小: $(du -h $CONFIG_FILE 2>/dev/null | cut -f1 || echo '未知')"
    echo "时间: $(stat -c %y $CONFIG_FILE 2>/dev/null | cut -d'.' -f1 || echo '未知')"
    
    echo ""
    echo -e "${YELLOW}💡 配置修改将应用到 $CONFIG_FILE${RESET}"
    echo "建议编辑内容:"
    echo "- LLM配置 (ChatGLM等API密钥)"
    echo "- ASR配置 (阿里云等语音识别服务)"
    echo "- TTS配置 (EdgeTTS等语音合成服务)"
}

# ========================= ASR 配置（15个服务商） =========================
config_asr() {
    while true; do
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
        
        # 修复：处理返回上一步 - 返回1表示需要返回上一步
        if [ "$asr_choice" = "0" ]; then
            return 1
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
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
                sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s|^    model_dir: .*|    model_dir: \"models/SenseVoiceSmall\"|" "$CONFIG_FILE"
                ;;
            2)
                asr_provider_key="FunASRServer"
                echo -e "\n${YELLOW}⚠️ 您选择了 FunASRServer。${RESET}"
                echo -e "${CYAN}🔗 需要自行部署 FunASR Server 服务${RESET}"
                read -r -p "请输入 FunASR Server 地址 (默认 http://localhost:10095): " server_url
                server_url=${server_url:-"http://localhost:10095"}
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
                sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    host: .*/    host: $server_url/" "$CONFIG_FILE"
                ;;
            3)
                asr_provider_key="SherpaASR"
                if [ "$IS_MEMORY_SUFFICIENT" = false ]; then
                    echo -e "\n${RED}❌ 内存不足，无法选择SherpaASR本地模型${RESET}"
                    read -r
                    continue
                fi
                echo -e "\n${GREEN}✅ 已选择本地模型 SherpaASR。${RESET}"
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
                ;;
            4)
                asr_provider_key="SherpaParaformerASR"
                if [ "$IS_MEMORY_SUFFICIENT" = false ]; then
                    echo -e "\n${RED}❌ 内存不足，无法选择SherpaParaformerASR本地模型${RESET}"
                    read -r
                    continue
                fi
                echo -e "\n${GREEN}✅ 已选择本地模型 SherpaParaformerASR。${RESET}"
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
                ;;
            5)
                asr_provider_key="DoubaoASR"
                echo -e "\n${YELLOW}⚠️ 您选择了火山引擎 DoubaoASR。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://www.volcengine.com/products/voice-interaction${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                read -r -p "请输入 Secret Key: " secret_key
                secret_key="${secret_key:-}"
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                if [ -n "$secret_key" ]; then
                    sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    secret_key: .*/    secret_key: \"$secret_key\"/" "$CONFIG_FILE"
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
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                if [ -n "$secret_key" ]; then
                    sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    secret_key: .*/    secret_key: \"$secret_key\"/" "$CONFIG_FILE"
                fi
                ;;
            7)
                asr_provider_key="TencentASR"
                echo -e "\n${YELLOW}⚠️ 您选择了腾讯云 TencentASR。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://console.cloud.tencent.com/asr${RESET}"
                read -r -p "请输入 SecretId: " secret_id
                secret_id="${secret_id:-}"
                read -r -p "请输入 SecretKey: " secret_key
                secret_key="${secret_key:-}"
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
                if [ -n "$secret_id" ]; then
                    sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    secret_id: .*/    secret_id: \"$secret_id\"/" "$CONFIG_FILE"
                fi
                if [ -n "$secret_key" ]; then
                    sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    secret_key: .*/    secret_key: \"$secret_key\"/" "$CONFIG_FILE"
                fi
                ;;
            8)
                asr_provider_key="AliyunASR"
                echo -e "\n${YELLOW}⚠️ 您选择了阿里云 AliyunASR。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://dashscope.console.aliyun.com${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                ;;
            9)
                asr_provider_key="AliyunStreamASR"
                echo -e "\n${YELLOW}⚠️ 您选择了阿里云 AliyunStreamASR。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://dashscope.console.aliyun.com${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                echo -e "\n${GREEN}✅ 已选择阿里云流式ASR。${RESET}"
                ;;
            10)
                asr_provider_key="BaiduASR"
                echo -e "\n${YELLOW}⚠️ 您选择了百度智能云 BaiduASR。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://console.bce.baidu.com/ai${RESET}"
                read -r -p "请输入 APP ID: " app_id
                app_id="${app_id:-}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                read -r -p "请输入 Secret Key: " secret_key
                secret_key="${secret_key:-}"
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
                if [ -n "$app_id" ]; then
                    sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    app_id: .*/    app_id: \"$app_id\"/" "$CONFIG_FILE"
                fi
                if [ -n "$api_key" ]; then
                    sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                if [ -n "$secret_key" ]; then
                    sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    secret_key: .*/    secret_key: \"$secret_key\"/" "$CONFIG_FILE"
                fi
                ;;
            11)
                asr_provider_key="OpenaiASR"
                echo -e "\n${YELLOW}⚠️ 您选择了OpenAI OpenaiASR。${RESET}"
                echo -e "${CYAN}🔑 API地址：https://platform.openai.com${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                ;;
            12)
                asr_provider_key="GroqASR"
                echo -e "\n${YELLOW}⚠️ 您选择了Groq GroqASR。${RESET}"
                echo -e "${CYAN}🔑 API地址：https://console.groq.com${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                ;;
            13)
                asr_provider_key="VoskASR"
                if [ "$IS_MEMORY_SUFFICIENT" = false ]; then
                    echo -e "\n${YELLOW}⚠️ 内存不足提醒：推荐≥2GB内存${RESET}"
                    read -r -p "按回车继续或输入0重新选择: " confirm_memory
                    if [ "$confirm_memory" = "0" ]; then
                        continue
                    fi
                fi
                echo -e "\n${GREEN}✅ 已选择本地模型 VoskASR。${RESET}"
                echo -e "${CYAN}ℹ️ 系统将自动配置 VoskASR 模型下载。${RESET}"
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
                ;;
            14)
                asr_provider_key="Qwen3ASRFlash"
                echo -e "\n${YELLOW}⚠️ 您选择了通义千问 Qwen3ASRFlash。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://dashscope.console.aliyun.com${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                ;;
            15)
                asr_provider_key="XunfeiStreamASR"
                echo -e "\n${YELLOW}⚠️ 您选择了讯飞 XunfeiStreamASR。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://www.xfyun.cn${RESET}"
                read -r -p "请输入 APP ID: " app_id
                app_id="${app_id:-}"
                read -r -p "请输入 API Secret: " api_secret
                api_secret="${api_secret:-}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
                if [ -n "$app_id" ]; then
                    sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    app_id: .*/    app_id: \"$app_id\"/" "$CONFIG_FILE"
                fi
                if [ -n "$api_secret" ]; then
                    sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    api_secret: .*/    api_secret: \"$api_secret\"/" "$CONFIG_FILE"
                fi
                if [ -n "$api_key" ]; then
                    sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                ;;
            *)
                echo -e "\n${RED}❌ 输入无效，请选择1-15范围内的数字，或输入0返回上一步${RESET}"
                echo -e "${YELLOW}💡 提示：默认推荐选项9（阿里云流式ASR）${RESET}"
                read -r -p "按回车键重新选择..."
                continue
                ;;
        esac
        
        # 配置完成，返回0表示成功
        return 0
    done
}

# ========================= LLM 配置（8个服务商） =========================
# 确保当前目录安全
check_working_directory() {
    if ! pwd >/dev/null 2>&1; then
        echo -e "${RED}❌ 工作目录错误，正在重置...${RESET}"
        cd /workspace
    fi
}

config_llm() {
    # 检查并修复工作目录
    check_working_directory
    
    while true; do
        echo -e "\n\n${GREEN}【2/5】配置 LLM (大语言模型) 服务${RESET}"
        echo "请选择LLM服务商（共15个）："
        echo " 0) ${YELLOW} 返回上一步 ${RESET}"
        echo " 1) ChatGLMLLM (智谱清言) [推荐]"
        echo " 2) QwenLLM (通义千问)"
        echo " 3) KimiLLM (月之暗面)"
        echo " 4) SparkLLM (讯飞星火)"
        echo " 5) WenxinLLM (百度文心一言)"
        echo " 6) DoubaoLLM (火山引擎豆包)"
        echo " 7) OpenaiLLM (OpenAI)"
        echo " 8) GroqLLM (Groq)"
        echo " 9) AliLLM (阿里云)"
        echo "10) DeepSeekLLM (DeepSeek)"
        echo "11) GeminiLLM (谷歌Gemini)"
        echo "12) DifyLLM (Dify)"
        echo "13) OllamaLLM (Ollama本地)"
        echo "14) XinferenceLLM (Xinference)"
        echo "15) FastgptLLM (FastGPT)"
        
        read -r -p "请输入序号 (默认推荐 1，输入0返回上一步): " llm_choice
        llm_choice=${llm_choice:-1}
        
        # 修复：处理返回上一步
        if [ "$llm_choice" = "0" ]; then
            return 1
        fi

        local llm_provider_key
        case $llm_choice in
            1)
                llm_provider_key="ChatGLMLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了智谱清言 ChatGLM。${RESET}"
                echo -e "${CYAN}🔑 密钥获取地址：https://open.bigmodel.cn/usercenter/apikeys${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                ;;
            2)
                llm_provider_key="QwenLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了通义千问 Qwen。${RESET}"
                echo -e "${CYAN}🔑 密钥获取地址：https://dashscope.console.aliyun.com/apiKey${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                ;;
            3)
                llm_provider_key="KimiLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了月之暗面 Kimi。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://platform.moonshot.cn/${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                ;;
            4)
                llm_provider_key="SparkLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了讯飞星火 Spark。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://console.xfyun.cn/${RESET}"
                read -r -p "请输入 App ID: " app_id
                read -r -p "请输入 API Secret: " api_secret
                read -r -p "请输入 API Key: " api_key
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$app_id" ] && [ -n "$api_secret" ] && [ -n "$api_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    app_id: .*/    app_id: \"$app_id\"/" "$CONFIG_FILE"
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_secret: .*/    api_secret: \"$api_secret\"/" "$CONFIG_FILE"
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                ;;
            5)
                llm_provider_key="WenxinLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了百度文心一言 Wenxin。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://console.bce.baidu.com/ai/#/ai/wenxinworkshop/app/index${RESET}"
                read -r -p "请输入 Access Key: " access_key
                read -r -p "请输入 Secret Key: " secret_key
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$access_key" ] && [ -n "$secret_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    access_key: .*/    access_key: \"$access_key\"/" "$CONFIG_FILE"
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    secret_key: .*/    secret_key: \"$secret_key\"/" "$CONFIG_FILE"
                fi
                ;;
            6)
                llm_provider_key="DoubaoLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了火山引擎豆包 Doubao。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://console.volcengine.com/ark${RESET}"
                read -r -p "请输入 Access Key ID: " access_key_id
                read -r -p "请输入 Secret Access Key: " secret_access_key
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$access_key_id" ] && [ -n "$secret_access_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    access_key_id: .*/    access_key_id: \"$access_key_id\"/" "$CONFIG_FILE"
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    secret_access_key: .*/    secret_access_key: \"$secret_access_key\"/" "$CONFIG_FILE"
                fi
                ;;
            7)
                llm_provider_key="OpenaiLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了 OpenAI。${RESET}"
                echo -e "${CYAN}🔑 密钥获取地址：https://platform.openai.com/api-keys${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                ;;
            8)
                llm_provider_key="GroqLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了 Groq。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://console.groq.com/keys${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                ;;
            9)
                llm_provider_key="AliLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了阿里云 AliLLM。${RESET}"
                echo -e "${CYAN}🔑 密钥获取地址：https://bailian.console.aliyun.com/?apiKey=1#/api-key${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                ;;
            10)
                llm_provider_key="DeepSeekLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了 DeepSeek。${RESET}"
                echo -e "${CYAN}🔑 密钥获取地址：https://platform.deepseek.com/${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                ;;
            11)
                llm_provider_key="GeminiLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了谷歌 Gemini。${RESET}"
                echo -e "${CYAN}🔑 密钥申请地址：https://aistudio.google.com/apikey${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                ;;
            12)
                llm_provider_key="DifyLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了 Dify。${RESET}"
                echo -e "${CYAN}🔑 建议使用本地部署的dify接口，国内部分区域访问dify公有云接口可能会受限${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                ;;
            13)
                llm_provider_key="OllamaLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了 Ollama本地部署。${RESET}"
                echo -e "${CYAN}🔑 需要预先使用ollama pull下载模型${RESET}"
                read -r -p "请输入模型名称 (默认: qwen2.5): " model_name
                model_name="${model_name:-qwen2.5}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$model_name" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    model_name: .*/    model_name: $model_name/" "$CONFIG_FILE"
                fi
                ;;
            14)
                llm_provider_key="XinferenceLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了 Xinference。${RESET}"
                echo -e "${CYAN}🔑 需要预先在Xinference启动对应模型${RESET}"
                read -r -p "请输入模型名称 (默认: qwen2.5:72b-AWQ): " model_name
                model_name="${model_name:-qwen2.5:72b-AWQ}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$model_name" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    model_name: .*/    model_name: $model_name/" "$CONFIG_FILE"
                fi
                ;;
            15)
                llm_provider_key="FastgptLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了 FastGPT。${RESET}"
                echo -e "${CYAN}🔑 密钥获取地址：https://cloud.tryfastgpt.ai/account/apikey${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                ;;
            *)
                echo -e "\n${RED}❌ 输入无效，请重新选择${RESET}"
                continue
                ;;
        esac
        
        # 配置完成，返回0表示成功
        return 0
    done
}

# ========================= VLLM 配置（4个服务商） =========================
config_vllm() {
    while true; do
        echo -e "\n\n${GREEN}【3/5】配置 VLLM (视觉大语言模型) 服务${RESET}"
        echo "请选择VLLM服务商（共4个）："
        echo " 0) ${YELLOW} 返回上一步 ${RESET}"
        echo " 1) ChatGLMVLLM (智谱清言) [推荐]"
        echo " 2) QwenVLLM (通义千问)"
        echo " 3) WenxinVLLM (百度文心一言)"
        echo " 4) OpenaiVLLM (OpenAI)"
        
        read -r -p "请输入序号 (默认推荐 1，输入0返回上一步): " vllm_choice
        vllm_choice=${vllm_choice:-1}
        
        # 修复：处理返回上一步
        if [ "$vllm_choice" = "0" ]; then
            return 1
        fi

        local vllm_provider_key
        case $vllm_choice in
            1)
                vllm_provider_key="ChatGLMVLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了智谱清言 ChatGLM VLLM。${RESET}"
                echo -e "${CYAN}🔑 密钥获取地址：https://open.bigmodel.cn/usercenter/apikeys${RESET}"
                safe_read "请输入 API Key: " api_key
                api_key="${api_key:-}"
                
                sed -i "/^  VLLM: /c\  VLLM: $vllm_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $vllm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                ;;
            2)
                vllm_provider_key="QwenVLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了通义千问 Qwen VLLM。${RESET}"
                echo -e "${CYAN}🔑 密钥获取地址：https://dashscope.console.aliyun.com/apiKey${RESET}"
                safe_read "请输入 API Key: " api_key
                api_key="${api_key:-}"
                
                sed -i "/^  VLLM: /c\  VLLM: $vllm_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $vllm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                ;;
            3)
                vllm_provider_key="WenxinVLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了百度文心一言 Wenxin VLLM。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://console.bce.baidu.com/ai/#/ai/wenxinworkshop/app/index${RESET}"
                safe_read "请输入 Access Key: " access_key
                safe_read "请输入 Secret Key: " secret_key
                
                sed -i "/^  VLLM: /c\  VLLM: $vllm_provider_key" "$CONFIG_FILE"
                if [ -n "$access_key" ] && [ -n "$secret_key" ]; then
                    sed -i "/^  $vllm_provider_key:/,/^  [A-Za-z]/ s/^    access_key: .*/    access_key: \"$access_key\"/" "$CONFIG_FILE"
                    sed -i "/^  $vllm_provider_key:/,/^  [A-Za-z]/ s/^    secret_key: .*/    secret_key: \"$secret_key\"/" "$CONFIG_FILE"
                fi
                ;;
            4)
                vllm_provider_key="OpenaiVLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了 OpenAI VLLM。${RESET}"
                echo -e "${CYAN}🔑 密钥获取地址：https://platform.openai.com/api-keys${RESET}"
                # 修复：确保工作目录稳定
                PWD_BACKUP="$(pwd)" 2>/dev/null || PWD_BACKUP="/tmp"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                # 修复：恢复到原始工作目录
                cd "$PWD_BACKUP" 2>/dev/null || true
                
                sed -i "/^  VLLM: /c\  VLLM: $vllm_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $vllm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                ;;
            *)
                echo -e "\n${RED}❌ 输入无效，请重新选择${RESET}"
                continue
                ;;
        esac
        
        # 配置完成，返回0表示成功
        return 0
    done
}

# ========================= TTS 配置（16个服务商） =========================
config_tts() {
    while true; do
        echo -e "\n\n${GREEN}【4/5】配置 TTS (语音合成) 服务${RESET}"
        echo "请选择TTS服务商（共16个）："
        echo " 0) ${YELLOW} 返回上一步 ${RESET}"
        echo " 1) EdgeTTS (微软) [推荐]"
        echo " 2) DoubaoTTS (火山引擎)"
        echo " 3) AliyunTTS (阿里云)"
        echo " 4) BaiduTTS (百度)"
        echo " 5) TencentTTS (腾讯云)"
        echo " 6) OpenaiTTS (OpenAI)"
        echo " 7) GizwitsTTS (机智云)"
        echo " 8) ACGNTTS (自部署)"
        echo " 9) LinkeraiTTS (LinkerAI)"
        echo "10) PaddleSpeechTTS (百度飞桨)"
        echo "11) IndexStreamTTS (Index-TTS-vLLM)"
        echo "12) AliBLTTS (阿里云百炼)"
        echo "13) XunFeiTTS (讯飞)"
        echo "14) 自定义TTS (Custom)"
        
        read -r -p "请输入序号 (默认推荐 1，输入0返回上一步): " tts_choice
        tts_choice=${tts_choice:-1}
        
        # 修复：处理返回上一步
        if [ "$tts_choice" = "0" ]; then
            return 1
        fi

        local tts_provider_key
        case $tts_choice in
            1)
                tts_provider_key="EdgeTTS"
                echo -e "\n${GREEN}✅ 已选择微软 EdgeTTS。${RESET}"
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                ;;
            2)
                tts_provider_key="DoubaoTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了火山引擎 Doubao TTS。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://console.volcengine.com/ark${RESET}"
                read -r -p "请输入 Access Key ID: " access_key_id
                read -r -p "请输入 Secret Access Key: " secret_access_key
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                if [ -n "$access_key_id" ] && [ -n "$secret_access_key" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    access_key_id: .*/    access_key_id: \"$access_key_id\"/" "$CONFIG_FILE"
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    secret_access_key: .*/    secret_access_key: \"$secret_access_key\"/" "$CONFIG_FILE"
                fi
                ;;
            3)
                tts_provider_key="AliyunTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了阿里云 Aliyun TTS。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://dashscope.console.aliyun.com${RESET}"
                read -r -p "请输入 Access Key ID: " access_key_id
                read -r -p "请输入 Access Key Secret: " access_key_secret
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                if [ -n "$access_key_id" ] && [ -n "$access_key_secret" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    access_key_id: .*/    access_key_id: \"$access_key_id\"/" "$CONFIG_FILE"
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    secret_access_key: .*/    secret_access_key: \"$access_key_secret\"/" "$CONFIG_FILE"
                fi
                ;;
            4)
                tts_provider_key="BaiduTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了百度 Baidu TTS。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://console.bce.baidu.com/ai/${RESET}"
                read -r -p "请输入 API Key: " api_key
                read -r -p "请输入 Secret Key: " secret_key
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ] && [ -n "$secret_key" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    secret_key: .*/    secret_key: \"$secret_key\"/" "$CONFIG_FILE"
                fi
                ;;
            5)
                tts_provider_key="TencentTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了腾讯云 Tencent TTS。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://console.cloud.tencent.com/asr${RESET}"
                read -r -p "请输入 Secret ID: " secret_id
                read -r -p "请输入 Secret Key: " secret_key
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                if [ -n "$secret_id" ] && [ -n "$secret_key" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    secret_id: .*/    secret_id: \"$secret_id\"/" "$CONFIG_FILE"
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    secret_key: .*/    secret_key: \"$secret_key\"/" "$CONFIG_FILE"
                fi
                ;;
            6)
                tts_provider_key="OpenaiTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了 OpenAI TTS。${RESET}"
                echo -e "${CYAN}🔑 密钥获取地址：https://platform.openai.com/api-keys${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                ;;
            7)
                tts_provider_key="GizwitsTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了机智云 Gizwits TTS。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://iot.gizwits.com/${RESET}"
                read -r -p "请输入 Product Key: " product_key
                read -r -p "请输入 Product Secret: " product_secret
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                if [ -n "$product_key" ] && [ -n "$product_secret" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    product_key: .*/    product_key: \"$product_key\"/" "$CONFIG_FILE"
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    product_secret: .*/    product_secret: \"$product_secret\"/" "$CONFIG_FILE"
                fi
                ;;
            8)
                tts_provider_key="ACGNTTS"
                echo -e "\n${GREEN}✅ 已选择自部署 ACGN TTS。${RESET}"
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                ;;
            9)
                tts_provider_key="LinkeraiTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了 LinkerAI TTS。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://linkerai.cn/${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                ;;
            10)
                tts_provider_key="PaddleSpeechTTS"
                echo -e "\n${GREEN}✅ 已选择百度飞桨 PaddleSpeech TTS。${RESET}"
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                ;;
            11)
                tts_provider_key="IndexStreamTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了 Index-TTS-vLLM。${RESET}"
                echo -e "${CYAN}🔑 请确保已部署Index-TTS-vLLM服务${RESET}"
                read -r -p "请输入服务地址: " service_url
                service_url="${service_url:-}"
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                if [ -n "$service_url" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    service_url: .*/    service_url: \"$service_url\"/" "$CONFIG_FILE"
                fi
                ;;
            12)
                tts_provider_key="AliBLTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了阿里云百炼 AliBL TTS。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://dashscope.console.aliyun.com${RESET}"
                read -r -p "请输入 API Key: " api_key
                api_key="${api_key:-}"
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                ;;
            13)
                tts_provider_key="XunFeiTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了讯飞 XunFei TTS。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://console.xfyun.cn/${RESET}"
                read -r -p "请输入 App ID: " app_id
                read -r -p "请输入 API Secret: " api_secret
                read -r -p "请输入 API Key: " api_key
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                if [ -n "$app_id" ] && [ -n "$api_secret" ] && [ -n "$api_key" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    app_id: .*/    app_id: \"$app_id\"/" "$CONFIG_FILE"
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    api_secret: .*/    api_secret: \"$api_secret\"/" "$CONFIG_FILE"
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                ;;
            14)
                tts_provider_key="Custom"
                echo -e "\n${YELLOW}⚠️ 您选择了自定义 TTS。${RESET}"
                echo -e "${CYAN}🔑 请输入自定义TTS服务配置${RESET}"
                read -r -p "请输入服务名称: " service_name
                read -r -p "请输入服务地址: " service_url
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                if [ -n "$service_name" ] && [ -n "$service_url" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    service_name: .*/    service_name: \"$service_name\"/" "$CONFIG_FILE"
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    service_url: .*/    service_url: \"$service_url\"/" "$CONFIG_FILE"
                fi
                ;;
            *)
                echo -e "\n${RED}❌ 输入无效，请重新选择${RESET}"
                continue
                ;;
        esac
        
        # 配置完成，返回0表示成功
        return 0
    done
}

# ========================= Memory 配置（3个服务商） =========================
config_memory() {
    while true; do
        echo -e "\n\n${GREEN}【5/5】配置 Memory (记忆) 服务${RESET}"
        echo "请选择Memory模式（共3个）："
        echo " 0) ${YELLOW} 返回上一步 ${RESET}"
        echo " 1) 不开启记忆 (nomem) [推荐]"
        echo " 2) 本地短记忆 (mem_local_short) - 隐私优先"
        echo " 3) Mem0AI (mem0ai) - 支持超长记忆 (每月免费1000次)"
        
        read -r -p "请输入序号 (默认推荐 1，输入0返回上一步): " memory_choice
        memory_choice=${memory_choice:-1}
        
        # 修复：处理返回上一步
        if [ "$memory_choice" = "0" ]; then
            return 1
        fi

        local memory_provider_key
        case $memory_choice in
            1)
                memory_provider_key="nomem"
                echo -e "\n${GREEN}✅ 已选择不开启记忆功能。${RESET}"
                sed -i "/^  Memory: /c\  Memory: $memory_provider_key" "$CONFIG_FILE"
                ;;
            2)
                memory_provider_key="mem_local_short"
                echo -e "\n${GREEN}✅ 已选择本地短记忆 (隐私优先)。${RESET}"
                sed -i "/^  Memory: /c\  Memory: $memory_provider_key" "$CONFIG_FILE"
                ;;
            3)
                memory_provider_key="mem0ai"
                echo -e "\n${YELLOW}⚠️ 您选择了 Mem0AI (支持超长记忆)。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://mem0ai.com/${RESET}"
                read -r -p "请输入 API Key: " mem0_api_key
                mem0_api_key="${mem0_api_key:-}"
                
                sed -i "/^  Memory: /c\  Memory: $memory_provider_key" "$CONFIG_FILE"
                if [ -n "$mem0_api_key" ]; then
                    sed -i "/^  mem0ai:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$mem0_api_key\"/" "$CONFIG_FILE"
                fi
                ;;
            *)
                echo -e "\n${RED}❌ 输入无效，请重新选择${RESET}"
                continue
                ;;
        esac
        
        # 配置完成，返回0表示成功
        return 0
    done
}

# ========================= 服务器地址配置 =========================
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

    sed -i "s|^[[:space:]]*websocket:[[:space:]]*.*$|  websocket: \"$ws_url\"|" "$CONFIG_FILE"
    sed -i "s|^[[:space:]]*vision_explain:[[:space:]]*.*$|  vision_explain: \"$vision_url\"|" "$CONFIG_FILE"

    echo -e "\n${GREEN}✅ 服务器地址配置完成：${RESET}"
    echo -e "  - WebSocket地址：$ws_url"
    echo -e "  - 视觉分析接口地址：$vision_url"
    
    echo -e "\n${deploy_type_color}${deploy_type_icon} ${deploy_description} 配置完成${RESET}"
    echo -e "${deploy_type_color}📋 您的OTA地址：${BOLD}${ota_url}${RESET}"
    echo -e "${deploy_type_color}💡 请在填写OTA地址时使用上述完整地址${RESET}"
}

# ========================= 核心服务配置入口 =========================
config_keys() {
    # 修复：如果选择了跳过详细配置，直接返回
    if [ "${SKIP_DETAILED_CONFIG:-false}" = true ]; then
        echo -e "\n${GREEN}✅ 检测到用户选择保留现有配置，跳过详细配置步骤${RESET}"
        echo -e "${CYAN}ℹ️ 将使用现有配置文件: $CONFIG_FILE${RESET}"
        export KEY_CONFIG_MODE="existing"
        return
    fi
    
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
        echo -e "${CYAN}ℹ️ 默认配置路径：$CONFIG_FILE${RESET}"
        
        # 设置默认配置
        sed -i "s/selected_module:.*/selected_module:\n  VAD: SileroVAD\n  ASR: AliyunStreamASR\n  LLM: ChatGLMLLM\n  VLLM: ChatGLMVLLM\n  TTS: EdgeTTS\n  Memory: nomem\n  Intent: function_call/" "$CONFIG_FILE"
        
        local ws_url="ws://$INTERNAL_IP:8000/xiaozhi/v1/"
        local vision_url="http://$INTERNAL_IP:8003/mcp/vision/explain"
        sed -i "s|^[[:space:]]*websocket:[[:space:]]*.*$|  websocket: \"$ws_url\"|" "$CONFIG_FILE"
        sed -i "s|^[[:space:]]*vision_explain:[[:space:]]*.*$|  vision_explain: \"$vision_url\"|" "$CONFIG_FILE"
        
        CURRENT_DEPLOY_TYPE="internal"
        export KEY_CONFIG_MODE="manual"
        return
    elif [ "$key_choice" = "2" ]; then
        echo -e "\n${YELLOW}⚠️ 已选择稍后手动填写。${RESET}"
        echo -e "${CYAN}ℹ️ 为防止服务启动失败，脚本将自动将服务商预设为 \"AliyunStreamASR\" 和 \"ChatGLMLLM\"。${RESET}"
        echo -e "${CYAN}ℹ️ 您可以稍后在配置文件中修改为您喜欢的服务商。配置文件路径：$CONFIG_FILE${RESET}"
        sed -i "s/selected_module:.*/selected_module:\n  VAD: SileroVAD\n  ASR: AliyunStreamASR\n  LLM: ChatGLMLLM\n  VLLM: ChatGLMVLLM\n  TTS: EdgeTTS\n  Memory: nomem\n  Intent: function_call/" "$CONFIG_FILE"
        
        local ws_url="ws://$INTERNAL_IP:8000/xiaozhi/v1/"
        local vision_url="http://$INTERNAL_IP:8003/mcp/vision/explain"
        sed -i "s|^[[:space:]]*websocket:[[:space:]]*.*$|  websocket: \"$ws_url\"|" "$CONFIG_FILE"
        sed -i "s|^[[:space:]]*vision_explain:[[:space:]]*.*$|  vision_explain: \"$vision_url\"|" "$CONFIG_FILE"
        
        CURRENT_DEPLOY_TYPE="internal"
        export KEY_CONFIG_MODE="manual"
        return
    fi

    if [[ "$key_choice" == "1" ]]; then
        echo -e "\n${GREEN}✅ 开始进行详细配置...${RESET}"
        
        # 恢复线性配置流程，一个接一个地配置
        echo -e "\n${CYAN}=== 第1步：配置 ASR (语音识别) 服务 ===${RESET}"
        config_asr
        if [ $? -eq 1 ]; then
            echo -e "${CYAN}🔄 用户取消配置，返回主菜单${RESET}"
            return 1
        fi
        
        echo -e "\n${CYAN}=== 第2步：配置 LLM (大语言模型) 服务 ===${RESET}"
        config_llm
        if [ $? -eq 1 ]; then
            echo -e "${CYAN}🔄 用户返回上一步，重新配置 ASR 服务${RESET}"
            echo -e "\n${CYAN}=== 重新配置 ASR (语音识别) 服务 ===${RESET}"
            config_asr
            if [ $? -eq 1 ]; then
                echo -e "${CYAN}🔄 用户取消配置，返回主菜单${RESET}"
                return 1
            fi
            
            echo -e "\n${CYAN}=== 重新配置 LLM (大语言模型) 服务 ===${RESET}"
            config_llm
            if [ $? -eq 1 ]; then
                echo -e "${CYAN}🔄 用户取消配置，返回主菜单${RESET}"
                return 1
            fi
        fi
        
        echo -e "\n${CYAN}=== 第3步：配置 VLLM (视觉大语言模型) 服务 ===${RESET}"
        config_vllm
        if [ $? -eq 1 ]; then
            echo -e "${CYAN}🔄 用户返回上一步，重新配置 LLM 服务${RESET}"
            echo -e "\n${CYAN}=== 重新配置 LLM (大语言模型) 服务 ===${RESET}"
            config_llm
            if [ $? -eq 1 ]; then
                echo -e "${CYAN}🔄 用户返回上一步，重新配置 ASR 服务${RESET}"
                echo -e "\n${CYAN}=== 重新配置 ASR (语音识别) 服务 ===${RESET}"
                config_asr
                if [ $? -eq 1 ]; then
                    echo -e "${CYAN}🔄 用户取消配置，返回主菜单${RESET}"
                    return 1
                fi
                
                echo -e "\n${CYAN}=== 重新配置 LLM (大语言模型) 服务 ===${RESET}"
                config_llm
                if [ $? -eq 1 ]; then
                    echo -e "${CYAN}🔄 用户取消配置，返回主菜单${RESET}"
                    return 1
                fi
            fi
            
            echo -e "\n${CYAN}=== 重新配置 VLLM (视觉大语言模型) 服务 ===${RESET}"
            config_vllm
            if [ $? -eq 1 ]; then
                echo -e "${CYAN}🔄 用户取消配置，返回主菜单${RESET}"
                return 1
            fi
        fi
        
        echo -e "\n${CYAN}=== 第4步：配置 TTS (语音合成) 服务 ===${RESET}"
        config_tts
        if [ $? -eq 1 ]; then
            echo -e "${CYAN}🔄 用户返回上一步，重新配置 VLLM 服务${RESET}"
            echo -e "\n${CYAN}=== 重新配置 VLLM (视觉大语言模型) 服务 ===${RESET}"
            config_vllm
            if [ $? -eq 1 ]; then
                echo -e "${CYAN}🔄 用户返回上一步，重新配置 LLM 服务${RESET}"
                echo -e "\n${CYAN}=== 重新配置 LLM (大语言模型) 服务 ===${RESET}"
                config_llm
                if [ $? -eq 1 ]; then
                    echo -e "${CYAN}🔄 用户返回上一步，重新配置 ASR 服务${RESET}"
                    echo -e "\n${CYAN}=== 重新配置 ASR (语音识别) 服务 ===${RESET}"
                    config_asr
                    if [ $? -eq 1 ]; then
                        echo -e "${CYAN}🔄 用户取消配置，返回主菜单${RESET}"
                        return 1
                    fi
                    
                    echo -e "\n${CYAN}=== 重新配置 LLM (大语言模型) 服务 ===${RESET}"
                    config_llm
                    if [ $? -eq 1 ]; then
                        echo -e "${CYAN}🔄 用户取消配置，返回主菜单${RESET}"
                        return 1
                    fi
                fi
                
                echo -e "\n${CYAN}=== 重新配置 VLLM (视觉大语言模型) 服务 ===${RESET}"
                config_vllm
                if [ $? -eq 1 ]; then
                    echo -e "${CYAN}🔄 用户取消配置，返回主菜单${RESET}"
                    return 1
                fi
            fi
            
            echo -e "\n${CYAN}=== 重新配置 TTS (语音合成) 服务 ===${RESET}"
            config_tts
            if [ $? -eq 1 ]; then
                echo -e "${CYAN}🔄 用户取消配置，返回主菜单${RESET}"
                return 1
            fi
        fi
        
        echo -e "\n${CYAN}=== 第5步：配置 Memory (记忆) 服务 ===${RESET}"
        config_memory
        if [ $? -eq 1 ]; then
            echo -e "${CYAN}🔄 用户返回上一步，重新配置 TTS 服务${RESET}"
            echo -e "\n${CYAN}=== 重新配置 TTS (语音合成) 服务 ===${RESET}"
            config_tts
            if [ $? -eq 1 ]; then
                echo -e "${CYAN}🔄 用户返回上一步，重新配置 VLLM 服务${RESET}"
                echo -e "\n${CYAN}=== 重新配置 VLLM (视觉大语言模型) 服务 ===${RESET}"
                config_vllm
                if [ $? -eq 1 ]; then
                    echo -e "${CYAN}🔄 用户返回上一步，重新配置 LLM 服务${RESET}"
                    echo -e "\n${CYAN}=== 重新配置 LLM (大语言模型) 服务 ===${RESET}"
                    config_llm
                    if [ $? -eq 1 ]; then
                        echo -e "${CYAN}🔄 用户返回上一步，重新配置 ASR 服务${RESET}"
                        echo -e "\n${CYAN}=== 重新配置 ASR (语音识别) 服务 ===${RESET}"
                        config_asr
                        if [ $? -eq 1 ]; then
                            echo -e "${CYAN}🔄 用户取消配置，返回主菜单${RESET}"
                            return 1
                        fi
                        
                        echo -e "\n${CYAN}=== 重新配置 LLM (大语言模型) 服务 ===${RESET}"
                        config_llm
                        if [ $? -eq 1 ]; then
                            echo -e "${CYAN}🔄 用户取消配置，返回主菜单${RESET}"
                            return 1
                        fi
                    fi
                    
                    echo -e "\n${CYAN}=== 重新配置 VLLM (视觉大语言模型) 服务 ===${RESET}"
                    config_vllm
                    if [ $? -eq 1 ]; then
                        echo -e "${CYAN}🔄 用户取消配置，返回主菜单${RESET}"
                        return 1
                    fi
                fi
                
                echo -e "\n${CYAN}=== 重新配置 TTS (语音合成) 服务 ===${RESET}"
                config_tts
                if [ $? -eq 1 ]; then
                    echo -e "${CYAN}🔄 用户取消配置，返回主菜单${RESET}"
                    return 1
                fi
            fi
            
            echo -e "\n${CYAN}=== 重新配置 Memory (记忆) 服务 ===${RESET}"
            config_memory
            if [ $? -eq 1 ]; then
                echo -e "${CYAN}🔄 用户取消配置，返回主菜单${RESET}"
                return 1
            fi
        fi
        
        echo -e "\n${CYAN}=== 第6步：配置服务器地址 (自动生成) ===${RESET}"
        config_server
        if [ $? -eq 1 ]; then
            echo -e "${CYAN}🔄 用户返回上一步，重新配置 Memory 服务${RESET}"
            echo -e "\n${CYAN}=== 重新配置 Memory (记忆) 服务 ===${RESET}"
            config_memory
            if [ $? -eq 1 ]; then
                echo -e "${CYAN}🔄 用户返回上一步，重新配置 TTS 服务${RESET}"
                echo -e "\n${CYAN}=== 重新配置 TTS (语音合成) 服务 ===${RESET}"
                config_tts
                if [ $? -eq 1 ]; then
                    echo -e "${CYAN}🔄 用户返回上一步，重新配置 VLLM 服务${RESET}"
                    echo -e "\n${CYAN}=== 重新配置 VLLM (视觉大语言模型) 服务 ===${RESET}"
                    config_vllm
                    if [ $? -eq 1 ]; then
                        echo -e "${CYAN}🔄 用户返回上一步，重新配置 LLM 服务${RESET}"
                        echo -e "\n${CYAN}=== 重新配置 LLM (大语言模型) 服务 ===${RESET}"
                        config_llm
                        if [ $? -eq 1 ]; then
                            echo -e "${CYAN}🔄 用户返回上一步，重新配置 ASR 服务${RESET}"
                            echo -e "\n${CYAN}=== 重新配置 ASR (语音识别) 服务 ===${RESET}"
                            config_asr
                            if [ $? -eq 1 ]; then
                                echo -e "${CYAN}🔄 用户取消配置，返回主菜单${RESET}"
                                return 1
                            fi
                            
                            echo -e "\n${CYAN}=== 重新配置 LLM (大语言模型) 服务 ===${RESET}"
                            config_llm
                            if [ $? -eq 1 ]; then
                                echo -e "${CYAN}🔄 用户取消配置，返回主菜单${RESET}"
                                return 1
                            fi
                        fi
                        
                        echo -e "\n${CYAN}=== 重新配置 VLLM (视觉大语言模型) 服务 ===${RESET}"
                        config_vllm
                        if [ $? -eq 1 ]; then
                            echo -e "${CYAN}🔄 用户取消配置，返回主菜单${RESET}"
                            return 1
                        fi
                    fi
                    
                    echo -e "\n${CYAN}=== 重新配置 TTS (语音合成) 服务 ===${RESET}"
                    config_tts
                    if [ $? -eq 1 ]; then
                        echo -e "${CYAN}🔄 用户取消配置，返回主菜单${RESET}"
                        return 1
                    fi
                fi
                
                echo -e "\n${CYAN}=== 重新配置 Memory (记忆) 服务 ===${RESET}"
                config_memory
                if [ $? -eq 1 ]; then
                    echo -e "${CYAN}🔄 用户取消配置，返回主菜单${RESET}"
                    return 1
                fi
            fi
            
            echo -e "\n${CYAN}=== 重新配置服务器地址 (自动生成) ===${RESET}"
            config_server
            if [ $? -eq 1 ]; then
                echo -e "${CYAN}🔄 用户取消配置，返回主菜单${RESET}"
                return 1
            fi
        fi
        
        echo -e "\n${GREEN}✅ 配置完成！${RESET}"
        echo -e "${CYAN}ℹ️ 详细配置文件已保存至: $CONFIG_FILE${RESET}"
        export KEY_CONFIG_MODE="auto"
    fi
}

# ========================= 服务启动 =========================
start_service() {
    check_docker_installed
    echo -e "\n${BLUE}🚀 开始启动服务...${RESET}"
    cd "$MAIN_DIR" || { echo -e "${RED}❌ 进入目录 $MAIN_DIR 失败${RESET}"; exit 1; }
    retry_exec "docker compose up -d" "启动Docker服务"
    
    echo -e "${CYAN}🔍 正在检查服务状态...${RESET}"
    sleep 5

    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "\n${GREEN}🎉 小智服务器启动成功！${RESET}"
        [[ "${KEY_CONFIG_MODE:-manual}" == "manual" ]] && {
            echo -e "${YELLOW}⚠️ 您选择了手动配置，请尽快编辑配置文件：$CONFIG_FILE${RESET}"
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
    
    echo -e "${GREEN}OTA接口（内网）：${BOLD}http://$INTERNAL_IP:8003/xiaozhi/ota/${RESET}"
    echo -e "${GREEN}OTA接口（公网）：${BOLD}http://$EXTERNAL_IP:8003/xiaozhi/ota/${RESET}"
    echo -e "${GREEN}Websocket接口：${BOLD}ws://$INTERNAL_IP:8000/xiaozhi/v1/${RESET}"
    echo -e "${GREEN}Websocket接口：${BOLD}ws://$EXTERNAL_IP:8000/xiaozhi/v1/${RESET}"
    echo -e "${PURPLE}==================================================${RESET}"
}

# ========================= 部署操作函数 =========================

# 全新部署
deploy_server() {
    echo -e "${CYAN}🚀 开始全新部署小智服务器${RESET}"
    
    check_and_install_docker
    clean_container
    create_dirs
    setup_config_file
    download_files "$CONFIG_DOWNLOAD_NEEDED"
    config_keys
    if [ $? -eq 1 ]; then
        echo -e "${CYAN}🔄 用户取消配置，返回主菜单${RESET}"
        return 1
    fi
    start_service
    show_connection_info

    echo -e "\n${PURPLE}==================================================${RESET}"
    echo -e "${GREEN}🎊 小智服务器部署成功！！🎊${RESET}"
    echo -e "${GREEN}🥳🥳🥳 请尽情使用吧 🥳🥳🥳${RESET}"
    echo -e "${PURPLE}==================================================${RESET}"
    
    read -r -p "按回车键返回主菜单..."
    return  # 修复：使用return而不是递归
}

# 重新部署（完全删除并重新开始）
redeploy_server() {
    echo -e "${RED}⚠️ 警告：重新部署将完全删除现有服务器数据和配置！${RESET}"
    echo -e "${YELLOW}这将删除：${RESET}"
    echo "  - 所有Docker容器和镜像"
    echo "  - 服务器目录和配置文件"
    echo "  - 所有用户数据"
    
    read -r -p "确认继续？(输入 'YES' 确认，其他任意键取消): " confirm
    if [ "$confirm" != "YES" ]; then
        echo -e "${CYAN}✅ 已取消重新部署${RESET}"
        read -r -p "按回车键返回主菜单..."
        return  # 修复：使用return而不是递归
    fi
    
    echo -e "${CYAN}🗑️ 开始删除现有服务器...${RESET}"
    
    # 停止并删除容器
    if [ "$CONTAINER_EXISTS" = true ]; then
        docker stop "$CONTAINER_NAME" 2>/dev/null
        docker rm "$CONTAINER_NAME" 2>/dev/null
        echo -e "${GREEN}✅ 已删除容器 ${CONTAINER_NAME}${RESET}"
    fi
    
    # 删除镜像
    docker rmi xiaozhi-esp32-server 2>/dev/null && echo -e "${GREEN}✅ 已删除镜像${RESET}"
    
    # 删除服务器目录
    if [ "$SERVER_DIR_EXISTS" = true ]; then
        rm -rf "$MAIN_DIR"
        echo -e "${GREEN}✅ 已删除服务器目录${RESET}"
    fi
    
    echo -e "${GREEN}✅ 现有服务器删除完成，开始全新部署...${RESET}"
    
    # 执行全新部署
    deploy_server
}

# 更新服务器（保留配置，更新到最新版本）
update_server() {
    echo -e "${CYAN}📦 开始更新服务器到最新版本${RESET}"
    echo -e "${YELLOW}更新流程：${RESET}"
    echo "1. 备份现有配置文件"
    echo "2. 删除容器和服务器文件"
    echo "3. 重新下载最新版本（不下载配置文件）"
    echo "4. 恢复配置文件"
    echo "5. 重启服务"
    
    read -r -p "确认继续更新？(y/n，默认y): " confirm
    confirm=${confirm:-y}
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${CYAN}✅ 已取消更新${RESET}"
        read -r -p "按回车键返回主菜单..."
        return  # 修复：使用return而不是递归
    fi
    
    echo -e "${CYAN}🔄 开始更新流程...${RESET}"
    
    # 1. 备份配置文件
    echo -e "${CYAN}1. 备份配置文件...${RESET}"
    BACKUP_DIR="/tmp/xiaozhi_backup_$(date +%s)"
    mkdir -p "$BACKUP_DIR"
    
    # 检查并备份所有配置文件
    if [ -d "$MAIN_DIR/data" ] && [ "$(ls -A "$MAIN_DIR/data" 2>/dev/null)" ]; then
        echo -e "${CYAN}📋 找到配置文件目录，备份内容：${RESET}"
        ls -la "$MAIN_DIR/data/"
        
        # 使用shopt确保隐藏文件也被复制
        shopt -s dotglob
        cp -r "$MAIN_DIR/data/"* "$BACKUP_DIR/" 2>/dev/null
        shopt -u dotglob
        
        echo -e "${GREEN}✅ 配置文件已备份到: $BACKUP_DIR${RESET}"
        echo -e "${CYAN}📋 备份的文件：${RESET}"
        ls -la "$BACKUP_DIR"
    else
        echo -e "${YELLOW}⚠️ 没有找到现有配置文件可备份${RESET}"
        # 检查可能的配置文件位置
        if [ -f "$MAIN_DIR/.config.yaml" ]; then
            echo -e "${CYAN}🔍 找到配置文件在非标准位置，尝试备份...${RESET}"
            cp "$MAIN_DIR/.config.yaml" "$BACKUP_DIR/"
        fi
        # 创建空的data目录防止后续问题
        mkdir -p "$MAIN_DIR/data"
    fi
    
    # 2. 停止并删除容器
    echo -e "${CYAN}2. 停止并删除容器...${RESET}"
    if [ "$CONTAINER_RUNNING" = true ]; then
        docker stop "$CONTAINER_NAME" 2>/dev/null
        echo -e "${GREEN}✅ 已停止容器${RESET}"
    fi
    docker rm "$CONTAINER_NAME" 2>/dev/null
    echo -e "${GREEN}✅ 已删除容器${RESET}"
    
    # 删除镜像
    docker rmi xiaozhi-esp32-server 2>/dev/null && echo -e "${GREEN}✅ 已删除旧镜像${RESET}"
    
    # 3. 删除服务器目录
    echo -e "${CYAN}3. 删除服务器目录...${RESET}"
    rm -rf "$MAIN_DIR"
    echo -e "${GREEN}✅ 已删除服务器目录${RESET}"
    
    # 检查数据目录是否存在（如果配置文件存在的话）
    echo -e "${CYAN}3.5. 检查配置文件状态...${RESET}"
    if [ -f "$HOME/xiaozhi-server/data/.config.yaml" ]; then
        echo -e "${YELLOW}⚠️ 检测到配置文件残留，将被清理${RESET}"
    else
        echo -e "${GREEN}✅ 没有残留的配置文件${RESET}"
    fi
    
    # 4. 重新下载docker-compose.yml（更新时必需）
    echo -e "${CYAN}4. 重新下载docker-compose.yml...${RESET}"
    create_dirs
    echo -e "${YELLOW}🔄 正在下载docker-compose.yml...${RESET}"
    retry_exec "curl -fSL $DOCKER_COMPOSE_URL -o $MAIN_DIR/docker-compose.yml" "下载 docker-compose.yml"
    
    # 4.5. 强制重新构建Docker镜像
    echo -e "${CYAN}4.5. 重新构建Docker镜像...${RESET}"
    cd "$MAIN_DIR" || { echo -e "${RED}❌ 进入目录 $MAIN_DIR 失败${RESET}"; exit 1; }
    echo -e "${YELLOW}🔄 正在重新构建Docker镜像...${RESET}"
    retry_exec "docker compose build --no-cache" "重新构建Docker镜像"
    echo -e "${GREEN}✅ Docker镜像重新构建完成${RESET}"
    
    # 5. 恢复配置文件
    echo -e "${CYAN}5. 恢复配置文件...${RESET}"
    if [ -d "$BACKUP_DIR" ] && [ "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        echo -e "${CYAN}📂 从备份恢复配置文件...${RESET}"
        echo -e "${CYAN}📋 备份文件列表：${RESET}"
        ls -la "$BACKUP_DIR"
        
        # 使用shopt确保隐藏文件也被复制
        shopt -s dotglob
        cp -r "$BACKUP_DIR/"* "$MAIN_DIR/data/" 2>/dev/null
        shopt -u dotglob
        
        echo -e "${GREEN}✅ 配置文件已恢复${RESET}"
        echo -e "${CYAN}📋 恢复的文件：${RESET}"
        ls -la "$MAIN_DIR/data/"
        
        # 验证配置文件恢复成功
        if [ -f "$MAIN_DIR/data/.config.yaml" ]; then
            echo -e "${GREEN}✅ 配置文件验证成功${RESET}"
        else
            echo -e "${YELLOW}⚠️ 配置文件恢复可能有问题，检查手动恢复${RESET}"
        fi
    else
        echo -e "${YELLOW}⚠️ 没有配置文件需要恢复${RESET}"
        echo -e "${CYAN}💡 可能的原因：${RESET}"
        echo "  - 首次安装，没有现有配置"
        echo "  - 配置文件在非标准位置"
        echo "  - 备份目录创建失败"
    fi
    
    # 清理备份
    rm -rf "$BACKUP_DIR"
    
    # 6. 重启服务
    echo -e "${CYAN}6. 重启服务...${RESET}"
    start_service
    show_connection_info
    
    echo -e "\n${GREEN}🎉 服务器更新完成！${RESET}"
    echo -e "${CYAN}💡 您的配置已保留，服务已更新到最新版本${RESET}"
    
    read -r -p "按回车键返回主菜单..."
    return  # 修复：使用return而不是递归
}

# 仅修改配置文件
config_only() {
    echo -e "${CYAN}⚙️ 进入配置文件修改模式${RESET}"
    echo -e "${YELLOW}这将：${RESET}"
    echo "1. 保留现有的服务器文件和容器"
    echo "2. 只修改配置文件"
    echo "3. 重启服务以应用新配置"
    
    read -r -p "确认继续？(y/n，默认y): " confirm
    confirm=${confirm:-y}
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${CYAN}✅ 已取消配置修改${RESET}"
        read -r -p "按回车键返回主菜单..."
        return  # 修复：使用return而不是递归
    fi
    
    # 设置跳过下载，直接配置
    CONFIG_DOWNLOAD_NEEDED="false"
    USE_EXISTING_CONFIG=true
    SKIP_DETAILED_CONFIG=false
    
    echo -e "${CYAN}⚙️ 开始修改配置...${RESET}"
    config_keys
    if [ $? -eq 1 ]; then
        echo -e "${CYAN}🔄 用户取消配置，返回主菜单${RESET}"
        return 1
    fi
    
    # 重启服务
    echo -e "${CYAN}🔄 重启服务以应用新配置...${RESET}"
    check_docker_installed
    cd "$MAIN_DIR" || exit 1
    docker restart "$CONTAINER_NAME" 2>/dev/null || start_service
    
    echo -e "${GREEN}✅ 配置修改完成，服务已重启${RESET}"
    
    read -r -p "按回车键返回主菜单..."
    return  # 修复：使用return而不是递归
}

# 连接信息展示
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

# 通用端口检查函数
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
                    echo -e "${YELLOW}⚠️  OTA服务已启动但返回空内容或拒绝连接${RESET}"
                fi
            else
                echo -e "${YELLOW}⚠️  无法获取OTA内容（连接超时或服务器未响应）${RESET}"
                echo -e "${YELLOW}💡 建议手动测试：curl $ota_url${RESET}"
            fi
        else
            echo -e "${YELLOW}⚠️  OTA端口连接异常 (HTTP状态码: $ota_status)${RESET}"
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

# 测试服务器连接
test_server() {
    echo -e "${CYAN}🧪 测试服务器连接状态${RESET}"
    echo -e "${YELLOW}这将测试：${RESET}"
    echo "1. Docker容器运行状态"
    echo "2. 服务器端口连通性"
    echo "3. OTA接口响应"
    echo "4. Websocket连接测试"
    
    read -r -p "确认开始测试？(y/n，默认y): " confirm
    confirm=${confirm:-y}
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${CYAN}✅ 已取消测试${RESET}"
        read -r -p "按回车键返回主菜单..."
        return  # 修复：使用return避免递归
    fi
    
    echo -e "\n${CYAN}🔍 开始服务器状态检查...${RESET}"
    
    # 1. 检查Docker容器状态
    echo -e "\n${YELLOW}1. 检查Docker容器状态${RESET}"
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${GREEN}✅ 容器 $CONTAINER_NAME 正在运行${RESET}"
        CONTAINER_STATUS="running"
    else
        echo -e "${RED}❌ 容器 $CONTAINER_NAME 未运行${RESET}"
        CONTAINER_STATUS="stopped"
        
        # 尝试显示容器日志
        if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            echo -e "${YELLOW}📄 最近的容器日志：${RESET}"
            docker logs --tail 10 "$CONTAINER_NAME" 2>/dev/null || echo "无法获取日志"
        fi
    fi
    
    # 2. 检查端口连通性
    echo -e "\n${YELLOW}2. 检查端口连通性${RESET}"
    
    # 检查8003端口（HTTP服务）
    if netstat -tln 2>/dev/null | grep -q ":8003 " || ss -tln 2>/dev/null | grep -q ":8003 "; then
        echo -e "${GREEN}✅ HTTP服务端口 8003 正在监听${RESET}"
    else
        echo -e "${RED}❌ HTTP服务端口 8003 未监听${RESET}"
    fi
    
    # 检查8000端口（WebSocket服务）
    if netstat -tln 2>/dev/null | grep -q ":8000 " || ss -tln 2>/dev/null | grep -q ":8000 "; then
        echo -e "${GREEN}✅ WebSocket端口 8000 正在监听${RESET}"
    else
        echo -e "${RED}❌ WebSocket端口 8000 未监听${RESET}"
    fi
    
    # 3. 测试OTA接口
    echo -e "\n${YELLOW}3. 测试OTA接口${RESET}"
    
    # 测试内网OTA地址
    OTA_URL="http://$INTERNAL_IP:8003/xiaozhi/ota/"
    echo -e "${CYAN}测试内网OTA地址: $OTA_URL${RESET}"
    
    if curl -s --max-time 10 -I "$OTA_URL" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ 内网OTA接口响应正常${RESET}"
        OTA_STATUS="ok"
        
        # 尝试获取OTA接口详细信息
        echo -e "${CYAN}📄 OTA接口响应信息：${RESET}"
        curl -s --max-time 10 -I "$OTA_URL" 2>/dev/null | head -3
    else
        echo -e "${RED}❌ 内网OTA接口无法访问${RESET}"
        OTA_STATUS="failed"
    fi
    
    # 4. 测试公网OTA地址（如果可用）
    if [ "$EXTERNAL_IP" != "$INTERNAL_IP" ]; then
        echo -e "\n${CYAN}测试公网OTA地址: http://$EXTERNAL_IP:8003/xiaozhi/ota/${RESET}"
        
        if curl -s --max-time 10 -I "http://$EXTERNAL_IP:8003/xiaozhi/ota/" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ 公网OTA接口响应正常${RESET}"
        else
            echo -e "${YELLOW}⚠️ 公网OTA接口无法访问（可能需要配置防火墙或端口转发）${RESET}"
        fi
    fi
    
    # 5. WebSocket连接测试
    echo -e "\n${YELLOW}4. WebSocket连接测试${RESET}"
    
    WS_URL="ws://$INTERNAL_IP:8000/xiaozhi/v1/"
    echo -e "${CYAN}测试WebSocket地址: $WS_URL${RESET}"
    
    # 使用简单的TCP测试WebSocket端口
    if timeout 3 bash -c "echo >/dev/tcp/$INTERNAL_IP/8000" 2>/dev/null; then
        echo -e "${GREEN}✅ WebSocket端口 8000 可达${RESET}"
        echo -e "${CYAN}💡 WebSocket服务正在运行，如需完整连接测试请使用WebSocket客户端${RESET}"
    else
        echo -e "${RED}❌ WebSocket端口 8000 不可达${RESET}"
    fi
    
    # 6. 生成测试报告
    echo -e "\n${PURPLE}==================================================${RESET}"
    echo -e "${CYAN}📊 服务器测试报告${RESET}"
    echo -e "${PURPLE}==================================================${RESET}"
    
    echo -e "容器状态: $([ "$CONTAINER_STATUS" = "running" ] && echo -e "${GREEN}运行中${RESET}" || echo -e "${RED}已停止${RESET}")"
    echo -e "HTTP端口: $(netstat -tln 2>/dev/null | grep -q ":8003 " && echo -e "${GREEN}正常${RESET}" || echo -e "${RED}异常${RESET}")"
    echo -e "WebSocket端口: $(netstat -tln 2>/dev/null | grep -q ":8000 " && echo -e "${GREEN}正常${RESET}" || echo -e "${RED}异常${RESET}")"
    echo -e "OTA接口: $([ "$OTA_STATUS" = "ok" ] && echo -e "${GREEN}正常${RESET}" || echo -e "${RED}异常${RESET}")"
    
    echo -e "\n${CYAN}🌐 可用的连接地址：${RESET}"
    echo -e "内网OTA: ${BOLD}http://$INTERNAL_IP:8003/xiaozhi/ota/${RESET}"
    echo -e "内网WebSocket: ${BOLD}ws://$INTERNAL_IP:8000/xiaozhi/v1/${RESET}"
    
    if [ "$EXTERNAL_IP" != "$INTERNAL_IP" ]; then
        echo -e "公网OTA: ${BOLD}http://$EXTERNAL_IP:8003/xiaozhi/ota/${RESET}"
        echo -e "公网WebSocket: ${BOLD}ws://$EXTERNAL_IP:8000/xiaozhi/v1/${RESET}"
    fi
    
    echo -e "${PURPLE}==================================================${RESET}"
    
    # 7. 提供操作建议
    echo -e "\n${CYAN}💡 操作建议：${RESET}"
    
    if [ "$CONTAINER_STATUS" != "running" ]; then
        echo -e "${RED}• 服务器未运行，请重启服务或检查配置${RESET}"
        echo -e "${CYAN}  重启命令：docker restart $CONTAINER_NAME${RESET}"
    fi
    
    if [ "$OTA_STATUS" != "ok" ]; then
        echo -e "${YELLOW}• OTA接口异常，请检查服务器配置和网络连接${RESET}"
    fi
    
    if [ "$CONTAINER_STATUS" = "running" ] && [ "$OTA_STATUS" = "ok" ]; then
        echo -e "${GREEN}• 服务器运行正常，可以正常使用！${RESET}"
    fi
    
    echo -e "\n${CYAN}🔧 常用调试命令：${RESET}"
    echo -e "查看容器状态: ${BOLD}docker ps -a | grep xiaozhi${RESET}"
    echo -e "查看容器日志: ${BOLD}docker logs $CONTAINER_NAME${RESET}"
    echo -e "重启容器: ${BOLD}docker restart $CONTAINER_NAME${RESET}"
    echo -e "进入容器: ${BOLD}docker exec -it $CONTAINER_NAME /bin/bash${RESET}"
    
    read -r -p "按回车键返回主菜单..."
    return  # 修复：使用return避免递归
}

# 测试服务器端口（新的详细端口测试）
test_ports() {
    echo -e "${CYAN}🧪 测试服务器端口连通性${RESET}"
    echo -e "${YELLOW}这将进行详细的端口检查：${RESET}"
    echo "1. OTA端口(8003)HTTP连接测试"
    echo "2. WebSocket端口(8000)TCP连接测试"
    echo "3. 详细诊断信息显示"
    echo "4. 故障排除建议"
    
    read -r -p "确认开始端口测试？(y/n，默认y): " confirm
    confirm=${confirm:-y}
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${CYAN}✅ 已取消测试${RESET}"
        read -r -p "按回车键返回主菜单..."
        return
    fi
    
    # 检查Docker容器状态
    echo -e "\n${YELLOW}🔍 检查Docker容器状态${RESET}"
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${GREEN}✅ 容器 $CONTAINER_NAME 正在运行${RESET}"
    else
        echo -e "${RED}❌ 容器 $CONTAINER_NAME 未运行${RESET}"
        echo -e "${YELLOW}💡 请先启动服务器再进行端口测试${RESET}"
        read -r -p "按回车键返回主菜单..."
        return
    fi
    
    # 调用连接信息展示函数
    show_connection_info
    
    read -r -p "按回车键返回主菜单..."
    return
}

# 查看Docker日志
docker_logs() {
    echo -e "${CYAN}📋 Docker日志查看${RESET}"
    echo -e "${PURPLE}==================================================${RESET}"
    
    if ! [ "$SERVER_DIR_EXISTS" = true ] || ! [ "$CONFIG_EXISTS" = true ]; then
        echo -e "${RED}❌ 未检测到现有服务器配置${RESET}"
        if [ "$SERVER_DIR_EXISTS" != true ] || [ "$CONFIG_EXISTS" != true ]; then
            echo -e "${CYAN}💡 请先选择选项1进行首次部署${RESET}"
        fi
        read -r -p "按回车键继续..."
        return
    fi
    
    # 检查Docker是否安装
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker未安装${RESET}"
        read -r -p "按回车键返回主菜单..."
        return
    fi
    
    # 检查容器是否存在
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${YELLOW}⚠️ 未找到小智服务器容器${RESET}"
        read -r -p "按回车键返回主菜单..."
        return
    fi
    
    echo -e "${CYAN}选择日志查看方式：${RESET}"
    echo "1) 查看最新50行日志"
    echo "2) 查看最新100行日志"
    echo "3) 查看全部日志"
    echo "4) 实时跟踪日志 (按Ctrl+C退出)"
    echo "5) 查看特定时间段日志"
    echo "0) 返回主菜单"
    
    read -r -p "请选择日志查看方式 (0-5): " log_choice
    
    case $log_choice in
        1)
            echo -e "\n${CYAN}📜 最新50行Docker日志：${RESET}"
            echo -e "${PURPLE}==================================================${RESET}"
            docker logs --tail 50 "$CONTAINER_NAME"
            ;;
        2)
            echo -e "\n${CYAN}📜 最新100行Docker日志：${RESET}"
            echo -e "${PURPLE}==================================================${RESET}"
            docker logs --tail 100 "$CONTAINER_NAME"
            ;;
        3)
            echo -e "\n${CYAN}📜 全部Docker日志：${RESET}"
            echo -e "${PURPLE}==================================================${RESET}"
            docker logs "$CONTAINER_NAME"
            ;;
        4)
            echo -e "\n${CYAN}🔄 实时跟踪Docker日志 (按Ctrl+C退出)：${RESET}"
            echo -e "${PURPLE}==================================================${RESET}"
            docker logs -f "$CONTAINER_NAME"
            ;;
        5)
            echo -e "\n${CYAN}📅 查看特定时间段日志${RESET}"
            echo "格式示例："
            echo "  开始时间: 2024-01-01 12:00:00"
            echo "  结束时间: 2024-01-01 13:00:00"
            echo ""
            read -r -p "开始时间 (YYYY-MM-DD HH:MM:SS): " start_time
            read -r -p "结束时间 (YYYY-MM-DD HH:MM:SS): " end_time
            
            if [ -n "$start_time" ] && [ -n "$end_time" ]; then
                echo -e "\n${CYAN}📜 $start_time 到 $end_time 的Docker日志：${RESET}"
                echo -e "${PURPLE}==================================================${RESET}"
                docker logs --since "$start_time" --until "$end_time" "$CONTAINER_NAME" 2>/dev/null || {
                    echo -e "${YELLOW}⚠️ 无法获取指定时间段的日志，可能格式不正确${RESET}"
                    echo -e "${CYAN}💡 请确保时间格式为：YYYY-MM-DD HH:MM:SS${RESET}"
                }
            else
                echo -e "${YELLOW}⚠️ 时间不能为空${RESET}"
            fi
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}❌ 无效选择${RESET}"
            ;;
    esac
    
    read -r -p "按回车键返回主菜单..."
    return
}

# 删除服务器（完全删除所有数据）
delete_server() {
    echo -e "${RED}⚠️ 警告：完全删除小智服务器！${RESET}"
    echo -e "${RED}这将删除：${RESET}"
    echo "  - 所有Docker容器和镜像"
    echo "  - 服务器目录和所有文件"
    echo "  - 所有用户数据和配置"
    echo "  - 彻底清理，无法恢复！"
    
    read -r -p "确认完全删除？(输入 'DELETE' 确认，其他任意键取消): " confirm
    if [ "$confirm" != "DELETE" ]; then
        echo -e "${CYAN}✅ 已取消删除操作${RESET}"
        read -r -p "按回车键返回主菜单..."
        return  # 修复：使用return而不是递归
    fi
    
    echo -e "${RED}🗑️ 开始完全删除小智服务器...${RESET}"
    
    # 停止所有相关容器
    echo -e "${CYAN}1. 停止所有相关容器...${RESET}"
    docker stop "$CONTAINER_NAME" 2>/dev/null
    docker rm "$CONTAINER_NAME" 2>/dev/null
    echo -e "${GREEN}✅ 相关容器已清理${RESET}"
    
    # 删除镜像
    echo -e "${CYAN}2. 删除Docker镜像...${RESET}"
    docker rmi xiaozhi-esp32-server 2>/dev/null && echo -e "${GREEN}✅ 镜像已删除${RESET}"
    
    # 删除服务器目录
    echo -e "${CYAN}3. 删除服务器文件...${RESET}"
    if [ "$SERVER_DIR_EXISTS" = true ]; then
        rm -rf "$MAIN_DIR"
        echo -e "${GREEN}✅ 服务器目录已删除${RESET}"
    fi
    
    # 清理可能的残留
    echo -e "${CYAN}4. 清理残留文件...${RESET}"
    rm -rf /tmp/xiaozhi_backup_* 2>/dev/null
    echo -e "${GREEN}✅ 残留文件已清理${RESET}"
    
    echo -e "\n${GREEN}🎉 小智服务器已完全删除！${RESET}"
    echo -e "${CYAN}💡 如需重新部署，请运行脚本选择全新部署${RESET}"
    
    read -r -p "按回车键返回主菜单..."
    return  # 修复：使用return而不是递归
}

# ========================= 系统检查函数 =========================
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

# ========================= 主执行函数 =========================
main() {
    # 修复：确保工作目录安全，处理不同执行方式的环境差异
    check_working_directory
    
    check_root_permission
    check_system
    install_dependencies
    check_server_config 
    show_start_ui        
    show_server_config 
    
    # 修复：进入主菜单循环而不是直接调用
    while true; do
        main_menu
    done
}

# 启动脚本执行
main "$@"
