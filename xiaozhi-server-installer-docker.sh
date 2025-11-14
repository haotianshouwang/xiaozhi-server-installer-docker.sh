#!/bin/bash
set -uo pipefail
trap exit_confirm SIGINT

# ========================= 基础配置 =========================
# 小智服务器一键部署脚本：自动安装Docker、创建目录、配置密钥、启动服务
# 新功能：端口检测 一键更新 新bug
# 作者：昊天兽王
# 版本：1.2.31（系统监控完善版本）
# 修复内容：修复未部署状态菜单映射问题，确保选项3和7正确对应系统监控工具
# v1.2.20:
# - 修复Docker服务启动流程问题
# - 确保用户选择Docker操作后正确执行docker-compose up -d
# - 添加服务启动后的连接信息显示
# - 优化智能内存风险处理逻辑
# v1.2.21:
# - 新增Docker操作工具菜单（选项0）
# - 集成到主菜单，支持服务管理、镜像清理、系统维护
# - 包含7个Docker操作子菜单：服务管理、镜像管理、容器管理、系统信息、深度清理、网络端口管理、日志管理
# - 提供完整的Docker生命周期管理功能
# - 保持向后兼容，不影响现有功能
# 详细说明：
# 0) 现在通过脚本配置密钥和服务商（默认）
# 1) 稍后手动填写所有配置
# 2) 退出配置（将使用现有配置文件）
# 3) 不配置所有配置，直接返回菜单（智能ASR检测，无在线ASR无警告）
# 4) 返回上一个菜单
# 修正内容：
# v1.2.17:
# - 添加check_asr_config函数，智能检测配置文件中的ASR设置
# - 添加smart_handle_memory_risk函数，根据ASR类型选择警告策略
# - 在线ASR配置（阿里云、讯飞、百度等）跳过内存警告，直接Docker操作
# - 本地ASR配置显示完整内存不足警告和风险提示
# - 优化Docker管理流程，确保正常返回处理结果
# - 清理测试代码残留，提升用户体验
# v1.2.18:
# - 修复create_default_config_file函数中LLM type设置错误
# - 将zhipuai类型改为openai类型（ChatGLM实际使用的类型）
# - 修正LLM和VLLM配置参数，使用正确的base_url和model_name格式
# v1.2.19:
# v1.2.20:
# - 修复Docker服务启动流程问题
# - 确保用户选择Docker操作后正确执行 docker-compose up -d
# - 添加专用服务启动函数 start_xiaozhi_service
# - 优化智能内存风险处理，确保服务能正常启动
# - 修复内存检测逻辑中bc命令依赖问题
# - 解决部分系统缺少bc命令导致的内存检测失败
# - 使用awk替代bc进行除法计算，提高脚本兼容性
# v1.2.21:
# - 新增Docker操作工具菜单，集成到主菜单选项0
# v1.2.23:
# - 解决GitHub脚本被替换为报告文件导致的语法错误
# - 提供完整的bash脚本，确保从GitHub下载时正常执行
# v1.2.26:
# - 增强网络监控功能：添加实时网络流量监控，每秒流量统计
# - 网络连接详细信息：显示谁连接我的IP和端口，我连接谁的IP和端口
# - 活跃连接监控：实时显示活跃连接数量和连接详情
# - 监听端口显示：显示当前系统监听的端口列表
# - 网络接口优化：自动检测网络接口，支持多种网络配置
# - 连接状态跟踪：实时跟踪TCP连接状态和详细信息
# - 菜单选项优化：退出脚本选项从10改为0，用户体验更友好
# - 网络数据缓存：实现网络流量实时计算，避免数据丢失
# - 网络兼容性增强：支持不同Linux发行版的网络统计方式

# v1.2.25:
# - 新增系统监控工具：高科技风格黑客大屏界面，实时系统状态监控
# - 详细系统信息：CPU核心使用率、内存使用情况、磁盘使用率、网络状态
# - 实时进程监控：显示TOP 5 CPU使用进程
# - 系统健康检查：CPU温度监控、内存风险评估、磁盘空间预警
# - 网络信息显示：内网IP、公网IP、收发数据流量统计
# - Docker状态监控：容器运行状态、资源使用情况
# - 彩色进度条显示：内存和磁盘使用率直观展示
# - 智能刷新机制：每2秒自动更新，支持键盘快捷键操作
# - 终端尺寸自适应：自动检测并提示最小窗口尺寸要求
# - 菜单结构调整：系统监控工具置于选项7，退出选项改为10
# - 完整向后兼容：不影响现有部署和Docker工具功能

# v1.2.24:
# - 调整菜单结构：Docker工具从选项0移至选项6
# - 完善Docker工具功能：所有子函数都支持循环菜单
# - 优化用户体验：每次操作完成后返回Docker工具主页
# - 新增Docker系统信息子菜单功能
# - Docker服务管理：启动/停止/重启/查看状态/资源监控
# - Docker镜像管理：查看/清理/重新拉取镜像
# - Docker容器管理：查看/进入/清理/重置容器
# - Docker系统信息：版本/资源使用/磁盘使用/事件信息
# - Docker深度清理：选择性清理Docker资源或完全重置
# - Docker网络端口管理：网络查看/端口检查/连接测试
# - Docker日志管理：查看/搜索/导出/实时跟踪日志
# - 保持完全向后兼容，不影响现有部署功能
# v1.2.22:
# - 修复case语句语法错误，删除多余分号
# - 解决Docker操作工具菜单启动时的bash语法问题
# - 确保脚本可以在所有bash环境中正常运行
# 因为看到很多小白都不会部署小智服务器，所以写了这个sh。前前后后改了3天，终于写出一个像样的、可以用的版本（豆包和MINIMAX是MVP）
AUTHOR="昊天兽王" 
SCRIPT_DESC="小智服务器一键部署脚本：自动安装Docker、配置ASR/LLM/VLLM/TTS、启动服务"
Version="1.2.31"

# 配置文件链接
CONFIG_FILE_URL="https://gh-proxy.com/https://raw.githubusercontent.com/haotianshouwang/xiaozhi-server-installer-docker.sh/refs/heads/main/config.yaml"
CONFIG_FILE_URL_BACKUP="https://gh-proxy.com/https://raw.githubusercontent.com/xinnan-tech/xiaozhi-esp32-server/refs/heads/main/xiaozhi-server/config.yaml"
CONFIG_FILE_URL_FALLBACK="https://mirror.ghproxy.com/https://raw.githubusercontent.com/xinnan-tech/xiaozhi-esp32-server/refs/heads/main/xiaozhi-server/config.yaml"
DOCKER_COMPOSE_URL="https://gh-proxy.com/https://raw.githubusercontent.com/haotianshouwang/xiaozhi-server-installer-docker.sh/refs/heads/main/docker-compose.yml"

MAIN_DIR="$HOME/xiaozhi-server"
CONTAINER_NAME="xiaozhi-esp32-server"

CONFIG_FILE="$MAIN_DIR/data/.config.yaml"
LOCAL_ASR_MODEL_URL="https://modelscope.cn/models/iic/SenseVoiceSmall/resolve/master/model.pt"
RETRY_MAX=3
RETRY_DELAY=3

# 颜色定义
RED="\033[31m" GREEN="\033[32m" YELLOW="\033[33m" BLUE="\033[34m" PURPLE="\033[35m" CYAN="\033[36m" WHITE_RED="\033[31;47;1m" RESET="\033[0m" BOLD="\033[1m"

# 全局变量
CHATGLM_API_KEY=""
IS_MEMORY_SUFFICIENT=false
IS_SHERPA_PARAFORMER_AVAILABLE=false
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
read -r -p "$prompt" "$var_name" < /dev/tty
    
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
read -r -n 1 choice < /dev/tty
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
    
    # 容器检测逻辑
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

# 检查系统内存大小
check_memory_size() {
    local mem_total_kb
    local mem_total_gb
    
    # 获取总内存大小（KB）
    if [ -f /proc/meminfo ]; then
        mem_total_kb=$(grep -i MemTotal /proc/meminfo | awk '{print $2}')
    else
        mem_total_kb=$(vm_stat | grep "Pages free:" | awk '{print $3}' | sed 's/\.//')  # 估算值
    fi
    
    if [ -z "$mem_total_kb" ] || [ "$mem_total_kb" -eq 0 ]; then
        echo -e "${YELLOW}⚠️ 无法获取内存信息，默认使用4GB作为基准${RESET}"
        return 1
    fi
    
    # 转换为GB（1GB = 1048576 KB）
    mem_total_gb=$(echo "scale=1; $mem_total_kb / 1048576" | bc 2>/dev/null || echo "$((mem_total_kb / 1048576))")
    
    # 检查是否小于4GB
    if [ "$mem_total_kb" -lt 4194304 ]; then  # 4GB = 4*1024*1024 = 4194304 KB
        return 1  # 内存不足
    else
        return 0  # 内存充足
    fi
}

# ========================= 主菜单函数 =========================
main_menu() {
    # 确保工作目录安全，防止执行方式不同导致的问题
    check_working_directory
    
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
        echo "6) Docker操作工具 (服务管理/镜像清理/系统维护)"
        echo "7) 系统监控工具 (实时系统状态监控)"
        echo "8) 查看Docker日志"
        echo "9) 删除服务器 (完全删除所有数据)"
        echo "0) 退出脚本"
    else
        echo -e "${GREEN}欢迎使用小智服务器部署脚本${RESET}"
        echo
        echo "请选择操作："
        echo "1) 开始部署小智服务器"
        echo "2) Docker操作工具 (服务管理/镜像清理/系统维护)"
        echo "3) 系统监控工具 (实时系统状态监控)"
        echo "0) 退出脚本"
    fi
    
    echo -e "${PURPLE}==================================================${RESET}"
    
        #输入验证机制
    while true; do
read -r -p "请输入选项: " menu_choice < /dev/tty
        
        if [ -z "$menu_choice" ]; then
            echo -e "${YELLOW}⚠️ 检测到空输入，请输入有效的选项编号${RESET}"
            echo -e "${CYAN}💡 已部署：1-9,0 | 未部署：1-3,0${RESET}"
            echo -e "${PURPLE}----------------------------------------${RESET}"
            continue  # 重新开始输入循环
        fi
        
        # 输入不为空，跳出循环处理选项
        break
    done
    
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
            break
            ;;
        2)
            if [ "$SERVER_DIR_EXISTS" = true ] && [ "$CONFIG_EXISTS" = true ]; then
                # 已部署 -> 更新服务器
                update_server
            else
                # 未部署 -> Docker操作工具
                docker_operation_tool_menu
            fi
            break
            ;;
        3)
            if [ "$SERVER_DIR_EXISTS" = true ] && [ "$CONFIG_EXISTS" = true ]; then
                # 已部署 -> 仅修改配置文件
                config_only
            else
                # 未部署 -> 系统监控工具
                system_monitor_tool
            fi
            break
            ;;
        4)
            # 测试服务器连接
            if [ "$SERVER_DIR_EXISTS" = true ] && [ "$CONFIG_EXISTS" = true ]; then
                test_server
                break  
            else
                echo -e "${RED}❌ 未检测到现有服务器配置${RESET}"
                echo -e "${CYAN}💡 请先选择选项1进行首次部署${RESET}"
read -r -p "按回车键继续..." < /dev/tty < /dev/tty
                break 
            fi
            ;;
        5)
            # 测试服务器端口
            if [ "$SERVER_DIR_EXISTS" = true ] && [ "$CONFIG_EXISTS" = true ]; then
                test_ports
                break 
            else
                echo -e "${RED}❌ 未检测到现有服务器配置${RESET}"
                echo -e "${CYAN}💡 请先选择选项1进行首次部署${RESET}"
read -r -p "按回车键继续..." < /dev/tty < /dev/tty
                break
            fi
            ;;
        6)
            # Docker操作工具
            docker_operation_tool_menu
            break
            ;;
        7)
            # 系统监控工具（仅已部署状态可用）
            if [ "$SERVER_DIR_EXISTS" = true ] && [ "$CONFIG_EXISTS" = true ]; then
                system_monitor_tool
                break
            else
                echo -e "${RED}❌ 该功能需要先部署服务器${RESET}"
                echo -e "${CYAN}💡 请先选择选项1进行首次部署${RESET}"
read -r -p "按回车键继续..." < /dev/tty < /dev/tty
                break
            fi
            ;;
        8)
            # 查看Docker日志
            docker_logs
            break  
            ;;
        9)
            # 删除服务器
            if [ "$SERVER_DIR_EXISTS" = true ] || [ "$CONTAINER_EXISTS" = true ]; then
                delete_server
            else
                echo -e "${YELLOW}⚠️ 未检测到服务器数据${RESET}"
read -r -p "按回车键继续..." < /dev/tty < /dev/tty
            fi
            break 
            ;;
        0)
            echo -e "${GREEN}👋 感谢使用，脚本退出${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ 无效选项，请重新选择${RESET}"
            if [ "$SERVER_DIR_EXISTS" = true ] && [ "$CONFIG_EXISTS" = true ]; then
                echo -e "${CYAN}💡 已部署：1-9,0 | 未部署：1-3,0${RESET}"
            else
                echo -e "${CYAN}💡 未部署：1-3,0${RESET}"
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

    # 获取硬件信息（四舍五入处理内存，避免系统预留内存导致误判）
    # 修复v1.2.19: 消除bc命令依赖，使用awk直接计算
    MEM_TOTAL=$(free -m | awk 'BEGIN{sum=0} /Mem:/ {sum+=$2} END{print int((sum/1024)+0.5)}')
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

# 检测配置文件中的ASR配置
check_asr_config() {
    local config_file=""
    
    # 查找配置文件
    if [ -f "$MAIN_DIR/data/.config.yaml" ]; then
        config_file="$MAIN_DIR/data/.config.yaml"
    elif [ -f "$HOME/xiaozhi-server/data/.config.yaml" ]; then
        config_file="$HOME/xiaozhi-server/data/.config.yaml"
    elif [ -f "$MAIN_DIR/.config.yaml" ]; then
        config_file="$MAIN_DIR/.config.yaml"
    fi
    
    # 如果没有找到配置文件，返回空字符串
    if [ -z "$config_file" ] || [ ! -f "$config_file" ]; then
        echo ""
        return 0
    fi
    
    # 检测ASR配置
    if [ -f "$config_file" ]; then
        # 检查是否包含本地ASR相关配置
        if grep -i "faster_whisper\|vosk\|espeak\|pyttsx3\|local\|本地" "$config_file" >/dev/null 2>&1; then
            echo "local"
        elif grep -i "aliyun\|阿里云\|azure\|azure_OPENAI_API_BASE\|gpt\|openai\|讯飞\|百度\|腾讯\|火山\|doubao" "$config_file" >/dev/null 2>&1; then
            echo "online"
        else
            echo "unknown"
        fi
    else
        echo ""
    fi
}

# 智能内存风险处理函数
smart_handle_memory_risk() {
    echo -e "\n${CYAN}🧠 智能内存风险评估${RESET}"
    
    # 检测当前ASR配置
    local asr_config=$(check_asr_config)
    
    echo -e "\033[36m📊 配置检测结果：$asr_config\033[0m"
    
    # 如果检测到在线ASR或者没有找到配置文件，使用温和处理
    if [ "$asr_config" = "online" ] || [ "$asr_config" = "unknown" ] || [ -z "$asr_config" ]; then
        # 在线ASR或未知配置，使用温和处理
        echo -e "${GREEN}✅ 检测到在线ASR配置${RESET}"
        echo -e "${CYAN}ℹ️ 当前配置不会导致内存不足问题${RESET}"
        echo -e "${CYAN}ℹ️ Docker操作将继续正常使用${RESET}"
        
        # 进入Docker管理选择
        docker_container_management
        local docker_result=$?
        
        if [ $docker_result -eq 0 ]; then
            echo -e "\n${CYAN}🎉 Docker操作和服务启动完成！${RESET}"
            echo -e "${CYAN}📋 您可以查看上面的连接地址信息使用服务${RESET}"
            return 0  # 成功完成
        else
            echo -e "\n${CYAN}🔄 Docker操作失败或被取消${RESET}"
            return 1  # 操作失败或被取消
        fi
    else
        # 本地ASR，使用原有逻辑
        handle_insufficient_memory
        local handle_result=$?
        
        if [ $handle_result -eq 0 ]; then
            echo -e "\n${CYAN}🎉 Docker操作和服务启动完成！${RESET}"
            echo -e "${CYAN}📋 您可以查看上面的连接地址信息使用服务${RESET}"
            return 0  # 成功完成
        else
            echo -e "\n${CYAN}🔄 Docker操作失败或被取消${RESET}"
            return 1  # 操作失败或被取消
        fi
    fi
}

# Docker容器管理选择界面
docker_container_management() {
    echo -e "\n${PURPLE}==================================================${RESET}"
    echo -e "${CYAN}🐳 Docker容器管理选择  🐳${RESET}"
    echo -e "${PURPLE}==================================================${RESET}"
    echo "1) 不执行docker退出，直接结束脚本"
    echo "2) 执行docker退出"
    echo ""
    
    read -r -p "请选择Docker操作 (1-2，默认1): " docker_choice < /dev/tty
    docker_choice=${docker_choice:-1}
    
    if [ "$docker_choice" = "1" ]; then
        echo -e "\n${GREEN}✅ 您选择了不执行docker退出${RESET}"
        echo -e "${CYAN}🛑 脚本将直接结束${RESET}"
        
        read -r -p "按回车键退出脚本..." < /dev/tty
        exit 0
    fi
    
    # 如果选择2执行docker退出
    if [ "$docker_choice" = "2" ]; then
        echo -e "\n${YELLOW}⚠️ 确认执行Docker操作${RESET}"
        echo -e "${CYAN}📋 Docker操作将按正常流程执行${RESET}"
        
        # 显示标准的Docker操作确认信息（温和版本）
        echo -e "\n${GREEN}==================================================${RESET}"
        echo -e "${GREEN}ℹ️ 注意事项：${RESET}"
        echo -e "${GREEN}请确认您的配置已正确设置${RESET}"
        echo -e "${GREEN}如遇问题可参考脚本日志${RESET}"
        echo -e "${GREEN}==================================================${RESET}"
        
        read -r -p "按回车键继续..." < /dev/tty
        
        # 执行Docker操作并启动服务
        echo -e "\n${YELLOW}⚠️ 正在执行Docker操作...${RESET}"
        
        # 清理现有容器
        echo -e "${CYAN}🔍 检查并清理现有容器...${RESET}"
        if command -v docker &> /dev/null; then
            if docker ps | grep -q "$CONTAINER_NAME"; then
                echo -e "${YELLOW}⚠️ 正在停止Docker容器...${RESET}"
                docker stop "$CONTAINER_NAME" 2>/dev/null
                docker rm "$CONTAINER_NAME" 2>/dev/null
                echo -e "${GREEN}✅ Docker容器已停止并删除${RESET}"
            else
                echo -e "${GREEN}✅ 未发现运行中的Docker容器${RESET}"
            fi
        else
            echo -e "${YELLOW}⚠️ Docker未安装，跳过容器操作${RESET}"
            return 1
        fi
        
        # 检查并启动服务
        echo -e "\n${CYAN}🚀 准备启动小智服务器服务...${RESET}"
        
        # 检查目录和配置文件
        if [ ! -d "$MAIN_DIR" ]; then
            echo -e "${RED}❌ 服务器目录不存在：$MAIN_DIR${RESET}"
            echo -e "${YELLOW}💡 请先运行脚本进行完整部署${RESET}"
            return 1
        fi
        
        if [ ! -f "$CONFIG_FILE" ]; then
            echo -e "${RED}❌ 配置文件不存在：$CONFIG_FILE${RESET}"
            echo -e "${YELLOW}💡 请先运行脚本进行配置${RESET}"
            return 1
        fi
        
        # 切换到服务器目录并启动服务
        cd "$MAIN_DIR" || {
            echo -e "${RED}❌ 进入目录失败：$MAIN_DIR${RESET}"
            return 1
        }
        
        if [ -f "docker-compose.yml" ]; then
            echo -e "${CYAN}🐳 执行 'docker compose up -d' 启动服务...${RESET}"
            
            # 启动服务
            if docker compose up -d; then
                echo -e "${CYAN}⏳ 等待服务启动...${RESET}"
                sleep 10
                
                # 检查服务状态
                if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
                    echo -e "${GREEN}🎉 小智服务器启动成功！${RESET}"
                    echo -e "${GREEN}✅ 容器 $CONTAINER_NAME 正在运行${RESET}"
                    
                    # 显示连接信息
                    INTERNAL_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
                    EXTERNAL_IP=$(curl -s --max-time 5 https://api.ip.sb/ip 2>/dev/null || echo "$INTERNAL_IP")
                    
                    echo -e "\n${PURPLE}==================================================${RESET}"
                    echo -e "${GREEN}📡 服务器连接地址信息${RESET}"
                    echo -e "${PURPLE}==================================================${RESET}"
                    echo -e "内网地址：$INTERNAL_IP"
                    echo -e "公网地址：$EXTERNAL_IP"
                    echo -e "${GREEN}OTA接口（内网）：http://$INTERNAL_IP:8003/xiaozhi/ota/${RESET}"
                    echo -e "${GREEN}WebSocket接口（内网）：ws://$INTERNAL_IP:8000/xiaozhi/v1/${RESET}"
                    echo -e "${PURPLE}==================================================${RESET}"
                    
                    return 0  # 服务启动成功
                else
                    echo -e "${RED}❌ 服务启动失败${RESET}"
                    echo -e "${YELLOW}💡 请检查容器日志：docker logs $CONTAINER_NAME${RESET}"
                    return 1
                fi
            else
                echo -e "${RED}❌ Docker服务启动失败${RESET}"
                return 1
            fi
        else
            echo -e "${RED}❌ 未找到 docker-compose.yml 文件${RESET}"
            echo -e "${YELLOW}💡 请先下载配置文件：${RESET}"
            echo -e "${CYAN}curl -O $CONFIG_FILE_URL${RESET}"
            return 1
        fi
    fi
    
    # 默认返回1表示不执行docker
    return 1
}

# 内存不足处理函数
handle_insufficient_memory() {
    echo -e "${RED}⚠️ 严重警告 - 内存不足风险${RESET}"
    echo -e "${RED}❌ 您的服务器内存${MEM_TOTAL}GB小于2GB${RESET}"
    echo -e "${YELLOW}⚠️ 当前脚本已配置为使用本地ASR模型${RESET}"
    echo -e "${YELLOW}⚠️ Docker容器默认设置自动启动${RESET}"
    echo -e "${RED}💀 这将导致您的服务器无限卡死！${RESET}"
    
    echo -e "\n${PURPLE}==================================================${RESET}"
    echo -e "${CYAN}🐳 Docker容器管理选择  🐳${RESET}"
    echo -e "${PURPLE}==================================================${RESET}"
    echo "1) 不执行docker退出，直接结束脚本"
    echo "2) 执行docker退出"
    echo ""
    
    read -r -p "请选择Docker操作 (1-2，默认1): " docker_choice < /dev/tty
    docker_choice=${docker_choice:-1}
    
    if [ "$docker_choice" = "1" ]; then
        echo -e "\n${GREEN}✅ 您选择了不执行docker退出${RESET}"
        echo -e "${CYAN}🛑 脚本将直接结束，避免服务器卡死风险${RESET}"
        echo -e "\n${YELLOW}💡 建议：${RESET}"
        echo -e "  - 升级服务器内存至2GB以上"
        echo -e "  - 修改配置文件，使用在线ASR服务"
        echo -e "  - 重新运行脚本进行配置"
        
        read -r -p "按回车键退出脚本..." < /dev/tty
        exit 0
    fi
    
    # 如果选择2执行docker退出，显示严重警告
    if [ "$docker_choice" = "2" ]; then
        echo -e "\n${RED}⚠️ 你知道你在干什么吗？这不是在开玩笑！${RESET}"
        echo -e "${RED}❌ 因为你服务器内存不足${RESET}"
        echo -e "${RED}❌ 配置文件默认使用本地ASR模型${RESET}"
        echo -e "${RED}❌ Docker容器默认设置自动启动${RESET}"
        echo -e "${RED}💀 这将导致你服务器无限卡死...${RESET}"
        
        echo -e "\n${RED}==================================================${RESET}"
        echo -e "${RED}🛑 免责声明：${RESET}"
        echo -e "${RED}脚本已尽最大努力保护你的服务器${RESET}"
        echo -e "${RED}如果坚持继续，你将承担服务器卡死的全部风险${RESET}"
        echo -e "${RED}作者不承担任何责任${RESET}"
        echo -e "${RED}==================================================${RESET}"
        
        echo -e "\n${RED}🆘 如果你的服务器卡死，请尝试以下方式自救：${RESET}"
        echo -e "${RED}1. 如果你是云服务器，请尝试VNC登录，执行sudo systemctl stop docker${RESET}"
        echo -e "${RED}2. 如果你是云服务器，请检查控制台是否有远程指令${RESET}"
        echo -e "${RED}3. 如果是云服务器，请配置远程指令：sudo systemctl stop docker${RESET}"
        echo -e "${RED}4. 如果都没有用，请自行百度解决方案${RESET}"
        echo -e "${RED}5. 最后手段：重装系统${RESET}"
        
        echo -e "\n${YELLOW}⚠️ 正在执行Docker操作...${RESET}"
        echo ""
        
        # 执行docker相关操作（停止现有容器等）
        echo -e "${CYAN}🔍 检查容器状态...${RESET}"
        if command -v docker &> /dev/null; then
            if docker ps | grep -q "$CONTAINER_NAME"; then
                echo -e "${YELLOW}⚠️ 正在停止Docker容器...${RESET}"
                docker stop "$CONTAINER_NAME" 2>/dev/null
                docker rm "$CONTAINER_NAME" 2>/dev/null
                echo -e "${GREEN}✅ Docker容器已停止并删除${RESET}"
            else
                echo -e "${GREEN}✅ 未发现运行中的Docker容器${RESET}"
            fi
        else
            echo -e "${YELLOW}⚠️ Docker未安装，跳过容器操作${RESET}"
        fi
        
        echo -e "\n${GREEN}✅ Docker容器清理完成${RESET}"
        
        # 检查并启动服务
        echo -e "${CYAN}🚀 准备启动小智服务器服务...${RESET}"
        
        # 检查目录和配置文件
        if [ ! -d "$MAIN_DIR" ]; then
            echo -e "${RED}❌ 服务器目录不存在：$MAIN_DIR${RESET}"
            echo -e "${YELLOW}💡 请先运行脚本进行完整部署${RESET}"
            return 1
        fi
        
        if [ ! -f "$CONFIG_FILE" ]; then
            echo -e "${RED}❌ 配置文件不存在：$CONFIG_FILE${RESET}"
            echo -e "${YELLOW}💡 请先运行脚本进行配置${RESET}"
            return 1
        fi
        
        # 切换到服务器目录并启动服务
        cd "$MAIN_DIR" || {
            echo -e "${RED}❌ 进入目录失败：$MAIN_DIR${RESET}"
            return 1
        }
        
        if [ -f "docker-compose.yml" ]; then
            echo -e "${CYAN}🐳 执行 'docker compose up -d' 启动服务...${RESET}"
            
            # 启动服务
            if docker compose up -d; then
                echo -e "${CYAN}⏳ 等待服务启动...${RESET}"
                sleep 10
                
                # 检查服务状态
                if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
                    echo -e "${GREEN}🎉 小智服务器启动成功！${RESET}"
                    echo -e "${GREEN}✅ 容器 $CONTAINER_NAME 正在运行${RESET}"
                    
                    # 显示连接信息
                    INTERNAL_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
                    EXTERNAL_IP=$(curl -s --max-time 5 https://api.ip.sb/ip 2>/dev/null || echo "$INTERNAL_IP")
                    
                    echo -e "\n${PURPLE}==================================================${RESET}"
                    echo -e "${GREEN}📡 服务器连接地址信息${RESET}"
                    echo -e "${PURPLE}==================================================${RESET}"
                    echo -e "内网地址：$INTERNAL_IP"
                    echo -e "公网地址：$EXTERNAL_IP"
                    echo -e "${GREEN}OTA接口（内网）：http://$INTERNAL_IP:8003/xiaozhi/ota/${RESET}"
                    echo -e "${GREEN}WebSocket接口（内网）：ws://$INTERNAL_IP:8000/xiaozhi/v1/${RESET}"
                    echo -e "${PURPLE}==================================================${RESET}"
                    
                    return 0  # 服务启动成功
                else
                    echo -e "${RED}❌ 服务启动失败${RESET}"
                    echo -e "${YELLOW}💡 请检查容器日志：docker logs $CONTAINER_NAME${RESET}"
                    return 1
                fi
            else
                echo -e "${RED}❌ Docker服务启动失败${RESET}"
                return 1
            fi
        else
            echo -e "${RED}❌ 未找到 docker-compose.yml 文件${RESET}"
            echo -e "${YELLOW}💡 请先下载配置文件：${RESET}"
            echo -e "${CYAN}curl -O $CONFIG_FILE_URL${RESET}"
            return 1
        fi
    fi
    
    echo -e "\n${RED}⚠️ 无效选择，脚本结束${RESET}"
    exit 0
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
        echo -e "${GREEN}✅ 内存检查通过（${MEM_TOTAL} GB ≥ 4 GB），可以选择所有本地ASR模型${RESET}"
        IS_MEMORY_SUFFICIENT=true
        IS_SHERPA_PARAFORMER_AVAILABLE=true
    elif [ "$MEM_TOTAL" -ge 2 ]; then
        echo -e "${YELLOW}⚠️ 内存检查：${MEM_TOTAL} GB${RESET}"
        echo -e "${GREEN}✅ 可以使用轻量级本地ASR模型（如SherpaParaformerASR）${RESET}"
        echo -e "${YELLOW}💡 其他本地ASR模型需要≥4GB内存${RESET}"
        IS_MEMORY_SUFFICIENT=false
        IS_SHERPA_PARAFORMER_AVAILABLE=true
    else
        echo -e "${RED}❌ 内存检查失败（${MEM_TOTAL} GB < 2 GB）${RESET}"
        echo -e "${RED}⚠️ 内存不足，建议选择在线ASR模型${RESET}"
        echo -e "${RED}⚠️ 最低内存要求：SherpaParaformerASR需≥2GB，其他本地模型需≥4GB${RESET}"
        IS_MEMORY_SUFFICIENT=false
        IS_SHERPA_PARAFORMER_AVAILABLE=false
        
        # 调用内存不足处理函数
        handle_insufficient_memory
        return $?
    fi
    echo
}

choose_docker_mirror() {
    echo -e "${GREEN}📦 选择Docker镜像源（加速下载）：${RESET}"
    echo "1) 阿里云 2) 腾讯云 3) 华为云 4) DaoCloud 5) 网易云"
    echo "6) 清华源 7) 中科大 8) 中科院 9) 百度云 10) 京东云"
    echo "11) 淘宝源 12) 官方源 13) 腾讯云国际 14) Azure中国 15) 360镜像源"
    echo "16) 阿里云GAE 17) 自定义 18) 官方源(不推荐)"
read -r -p "请输入序号（默认1）：" mirror_choice < /dev/tty
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
read -r mirror_url < /dev/tty
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
read -r -p "🔧 是否安装Docker？(y/n，默认y): " docker_install_choice < /dev/tty
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
read -r configure_mirror < /dev/tty
    configure_mirror=${configure_mirror:-y}
    [[ "$configure_mirror" == "y" || "$configure_mirror" == "Y" ]] && choose_docker_mirror

    # 检查Docker Compose
    if ! docker compose version &> /dev/null; then
        echo -e "${YELLOW}❌ Docker Compose 未安装，开始安装...${RESET}"
        retry_exec "sudo curl -SL \"https://gh-proxy.com/https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose" "安装Docker Compose"
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
    
    echo -e "${CYAN}🔄 开始多链接配置文件下载...${RESET}"
    
    # 配置文件链接列表
    declare -a config_urls=(
        "GitHub主源|$CONFIG_FILE_URL"
        "xinnan-tech备用源|$CONFIG_FILE_URL_BACKUP"
        "镜像源备用|$CONFIG_FILE_URL_FALLBACK"
    )
    
    for url_info in "${config_urls[@]}"; do
        mirror_count=$((mirror_count + 1))
        IFS='|' read -r link_name config_url <<< "$url_info"
        
        echo -e "\n${CYAN}🎯 尝试第$mirror_count个链接：$link_name${RESET}"
        echo -e "${YELLOW}📎 链接：$config_url${RESET}"
        
        # 使用详细的下载日志
        if curl -fSL --connect-timeout 10 --max-time 30 "$config_url" -o "$output_file" 2>&1; then
            if [ -f "$output_file" ] && [ -s "$output_file" ]; then
                # 检查文件内容是否有效
                if grep -q "server:" "$output_file" 2>/dev/null || grep -q "llm:" "$output_file" 2>/dev/null; then
                    echo -e "${GREEN}✅ $link_name 下载成功${RESET}"
                    echo -e "${GREEN}✅ 文件大小：$(du -h "$output_file" 2>/dev/null | cut -f1 || echo '未知')${RESET}"
                    download_success=true
                    break
                else
                    echo -e "${YELLOW}⚠️ $link_name 下载文件无效，尝试下一个${RESET}"
                    echo -e "${YELLOW}📝 文件内容预览：$(head -3 "$output_file" 2>/dev/null || echo '无法读取')${RESET}"
                    rm -f "$output_file"
                fi
            else
                echo -e "${RED}❌ $link_name 下载文件为空或不存在${RESET}"
            fi
        else
            echo -e "${RED}❌ $link_name 下载失败${RESET}"
            echo -e "${RED}🔍 错误详情：检查网络连接或代理设置${RESET}"
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
        
        # 下载服务器配置文件
        echo -e "\n${CYAN}🔧 下载服务器配置文件...${RESET}"
        if ! download_config_with_fallback "$CONFIG_FILE"; then
            echo -e "${RED}❌ 服务器配置文件下载失败${RESET}"
            echo -e "${YELLOW}💡 请检查网络连接或稍后重试${RESET}"
            return 1
        fi
        
        # 下载Docker配置文件（带备用链接）
        echo -e "\n${CYAN}🐳 下载Docker配置文件...${RESET}"
        if [ ! -f "$MAIN_DIR/docker-compose.yml" ]; then
            # Docker配置文件备用链接（使用统一定义的DOCKER_COMPOSE_URL）
            local docker_urls=(
                "$DOCKER_COMPOSE_URL"
                "https://mirror.ghproxy.com/https://raw.githubusercontent.com/haotianshouwang/xiaozhi-server-installer-docker.sh/refs/heads/main/docker-compose.yml"
            )
            
            local docker_download_success=false
            local docker_mirror_count=0
            
            for docker_url in "${docker_urls[@]}"; do
                docker_mirror_count=$((docker_mirror_count + 1))
                echo -e "${YELLOW}🎯 尝试第$docker_mirror_count个Docker链接${RESET}"
                echo -e "${YELLOW}📎 链接：$docker_url${RESET}"
                
                if curl -fSL --connect-timeout 10 --max-time 30 "$docker_url" -o "$MAIN_DIR/docker-compose.yml" --progress-bar; then
                    if [ -f "$MAIN_DIR/docker-compose.yml" ] && [ -s "$MAIN_DIR/docker-compose.yml" ]; then
                        echo -e "${GREEN}✅ Docker配置文件下载成功${RESET}"
                        echo -e "${GREEN}✅ 文件大小：$(du -h "$MAIN_DIR/docker-compose.yml" 2>/dev/null | cut -f1 || echo '未知')${RESET}"
                        docker_download_success=true
                        break
                    else
                        echo -e "${RED}❌ Docker配置文件下载失败或为空${RESET}"
                    fi
                else
                    echo -e "${RED}❌ Docker配置文件下载失败${RESET}"
                fi
                
                if [ $docker_mirror_count -lt ${#docker_urls[@]} ]; then
                    echo -e "${YELLOW}⏳ 等待3秒后尝试下一个Docker链接...${RESET}"
                    sleep 3
                fi
            done
            
            if [ "$docker_download_success" != "true" ]; then
                echo -e "${RED}❌ Docker配置文件下载失败，使用默认模板${RESET}"
                echo -e "${YELLOW}💡 创建默认docker-compose.yml模板${RESET}"
                
                # 创建默认的docker-compose.yml
                cat > "$MAIN_DIR/docker-compose.yml" << 'EOF'
version: '3.8'
services:
  xiaozhi-esp32-server:
    image: xiaozhi-esp32-server:latest
    container_name: xiaozhi-esp32-server
    ports:
      - "3000:3000"
      - "3001:3001"
      - "8000:8000"
    volumes:
      - ./data:/app/data
      - ./models:/app/models
      - ./music:/app/music
    environment:
      - TZ=Asia/Shanghai
    restart: unless-stopped
    # 如果需要GPU支持，取消注释下面两行
    # deploy:
    #   resources:
    #     reservations:
    #       devices:
    #         - driver: nvidia
    #           count: all
    #           capabilities: [gpu]
EOF
                echo -e "${GREEN}✅ 已创建默认docker-compose.yml模板${RESET}"
            fi
        else
            echo -e "${GREEN}✅ Docker配置文件已存在，跳过下载${RESET}"
        fi
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

create_default_config_file() {
    echo -e "\n${YELLOW}⚠️ 正在创建完全干净的默认配置文件${RESET}"
    
    # 创建目录
    mkdir -p "$(dirname "$CONFIG_FILE")"
    
    # 创建完全干净的默认配置文件，只包含基本模块配置
    cat > "$CONFIG_FILE" << 'EOF'
# 小智服务器默认配置文件
# 此文件包含基础的模块配置，不包含任何API密钥
# 用户可以稍后在此文件中添加必要的API密钥

# 模块选择配置
selected_module:
  VAD: SileroVAD
  ASR: AliyunStreamASR
  LLM: ChatGLMLLM
  VLLM: ChatGLMVLLM
  TTS: EdgeTTS
  Memory: nomem
  Intent: function_call

# VAD配置
VAD:
  SileroVAD:
    type: silero_vad
    sample_rate: 16000

# ASR配置 (阿里云流式)
ASR:
  AliyunStreamASR:
    type: aliyun_stream
    appkey: ""  # 需要用户填入
    token: ""   # 需要用户填入
    audio_format: PCM
    sample_rate: 16000
    channel: 1
    encoding: linear16

# LLM配置 (智谱清言)
LLM:
  ChatGLMLLM:
    type: openai
    model_name: glm-4-flash
    base_url: https://open.bigmodel.cn/api/paas/v4/
    api_key: ""     # 需要用户填入
    temperature: 0.7
    max_tokens: 500
    top_p: 1
    top_k: 50
    frequency_penalty: 0

# VLLM配置 (智谱清言)
VLLM:
  ChatGLMVLLM:
    type: openai
    model_name: glm-4v-flash
    base_url: https://open.bigmodel.cn/api/paas/v4/
    api_key: ""     # 需要用户填入

# TTS配置 (微软Edge)
TTS:
  EdgeTTS:
    type: edge
    voice: "zh-CN-XiaoxiaoNeural"
    output_dir: tmp/

# Memory配置
Memory:
  nomem:
    type: no_memory

# Intent配置
Intent:
  function_call:
    type: function_call

# WebSocket配置
websocket: "ws://localhost:8000/xiaozhi/v1/"
vision_explain: "http://localhost:8003/mcp/vision/explain"
EOF
    
    echo -e "${GREEN}✅ 已创建干净的默认配置文件${RESET}"
    echo -e "${CYAN}📝 配置文件位置：$CONFIG_FILE${RESET}"
    echo -e "${YELLOW}⚠️ 请注意：此文件仅包含基础配置，所有API密钥都需要您手动填入${RESET}"
}

setup_config_file() {
    echo -e "\n${CYAN}📁 配置小智服务器配置文件...${RESET}"
    
    mkdir -p "$MAIN_DIR/data"
    echo -e "${GREEN}✅ 已创建 data 目录: $MAIN_DIR/data${RESET}"
    
    # 检查是否用户选择退出配置并使用现有配置文件
    if [ "${USE_EXISTING_CONFIG:-false}" = "true" ]; then
        echo -e "${GREEN}✅ 检测到用户选择退出配置，使用现有的配置文件${RESET}"
        CONFIG_DOWNLOAD_NEEDED="false"
        USE_EXISTING_CONFIG=true
        SKIP_DETAILED_CONFIG=false
        return
    fi
    
    # 检查是否用户选择稍后手动填写并创建了默认配置
    if [ "${USE_DEFAULT_CONFIG:-false}" = "true" ]; then
        echo -e "${GREEN}✅ 检测到用户选择稍后手动填写，使用已创建的默认配置文件${RESET}"
        CONFIG_DOWNLOAD_NEEDED="false"
        USE_EXISTING_CONFIG=true
        SKIP_DETAILED_CONFIG=false
        return
    fi
    
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
        echo -e "\n${YELLOW}📥 需要下载配置文件，稍后将统一处理...${RESET}"
        CONFIG_DOWNLOAD_NEEDED="true"
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

# 阿里云ASR配置
config_aliyun_asr() {
    echo -e "\n${YELLOW}⚠️ 您选择了阿里云 AliyunStreamASR。${RESET}"
    echo -e "${CYAN}🔑 开通地址：https://nls-portal.console.aliyun.com/${RESET}"
    echo -e "${CYAN}🔑 Appkey地址：https://nls-portal.console.aliyun.com/applist${RESET}"
    
    echo -e "${CYAN}📝 阿里云流式ASR需要以下参数：${RESET}"
    echo "  - Appkey: 语音交互服务项目Appkey（必填）"
    echo "  - Token: 临时AccessToken，24小时有效（必填）"
    echo -e "${YELLOW}💡 长期使用建议设置下方Access Key（可选）：${RESET}"
    echo "  - Access Key ID: 阿里云账号访问密钥ID（可选，长期使用推荐）"
    echo "  - Access Key Secret: 阿里云账号访问密钥（可选，长期使用推荐）"
    
    safe_read "请输入 Appkey: " appkey
    safe_read "请输入 Token: " token
    
    echo -e "\n${YELLOW}💡 是否要配置长期使用的Access Key？${RESET}"
    echo "如需长期使用（避免Token过期），建议配置Access Key:"
    read -r -p "请输入 Access Key ID (留空跳过): " access_key_id < /dev/tty
    read -r -p "请输入 Access Key Secret (留空跳过): " access_key_secret < /dev/tty
    
    local asr_provider_key="AliyunStreamASR"
    sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
    
    if [ -n "$appkey" ]; then
        sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    appkey: .*/    appkey: \"$appkey\"/" "$CONFIG_FILE"
    fi
    if [ -n "$token" ]; then
        sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    token: .*/    token: \"$token\"/" "$CONFIG_FILE"
    fi
    if [ -n "$access_key_id" ]; then
        sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    access_key_id: .*/    access_key_id: \"$access_key_id\"/" "$CONFIG_FILE"
    fi
    if [ -n "$access_key_secret" ]; then
        sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    access_key_secret: .*/    access_key_secret: \"$access_key_secret\"/" "$CONFIG_FILE"
    fi
    
    echo -e "\n${GREEN}✅ 阿里云流式ASR配置完成${RESET}"
}

# ========================= 高级ASR配置 =========================
config_asr_advanced() {
    echo -e "${YELLOW}🎤 语音识别(ASR)服务详细配置${RESET}"
    echo -e "${CYAN}请选择ASR服务类型：${RESET}"
    
    # 始终显示所有选项，根据内存情况显示警告
    if [ "$IS_MEMORY_SUFFICIENT" = true ]; then
        echo "1) FunASR (本地SenseVoiceSmall，推荐)"
    else
        echo -e "1) FunASR (本地SenseVoiceSmall，推荐 ${RED}⚠️ 内存不足 无法使用${RESET})"
    fi
    
    # FunASRServer 是独立部署服务，不需要本地内存，始终可选
    echo "2) FunASRServer (独立部署服务)"
    echo -e "    ${GREEN}✅ 独立服务，无需本地内存${RESET}"
    
    if [ "$IS_MEMORY_SUFFICIENT" = true ]; then
        echo "3) SherpaASR (本地多语言)"
    else
        echo -e "3) SherpaASR (本地多语言 ${RED}⚠️ 内存不足 无法使用${RESET})"
    fi
    
    if [ "$IS_SHERPA_PARAFORMER_AVAILABLE" = true ]; then
        echo "4) SherpaParaformerASR (本地中文专用)"
    else
        echo -e "4) SherpaParaformerASR (本地中文专用 ${RED}⚠️ 内存不足 无法使用${RESET})"
    fi
    
    if [ "$IS_MEMORY_SUFFICIENT" = true ]; then
        echo "5) VoskASR (本地离线)"
    else
        echo -e "5) VoskASR (本地离线 ${RED}⚠️ 内存不足 无法使用${RESET})"
    fi
    
    echo "6) AliyunStreamASR (阿里云流式，推荐)"
    echo "7) AliyunASR (阿里云批量)"
    echo "8) DoubaoStreamASR (火山引擎流式)"
    echo "9) DoubaoASR (火山引擎批量)"
    echo "10) TencentASR (腾讯云)"
    echo "11) BaiduASR (百度智能云)"
    echo "12) OpenaiASR (OpenAI)"
    echo "13) GroqASR (Groq)"
    echo "14) Qwen3ASRFlash (通义千问)"
    echo "15) XunfeiStreamASR (讯飞流式)"
    echo "0) 返回上级菜单"
    
    read -r -p "请选择ASR服务类型 (0-15，默认6): " asr_choice < /dev/tty
    asr_choice=${asr_choice:-6}
    
    case $asr_choice in
        0)
            echo -e "${CYAN}🔄 取消配置，返回主菜单${RESET}"
            return 2  # 返回码2表示完全退出配置
            ;;
        1)
            if [ "$IS_MEMORY_SUFFICIENT" = true ]; then
                config_funasr_local
            else
                echo -e "${RED}💀 内存不足无法选择${RESET}"
                echo -e "${YELLOW}请重新选择ASR服务类型...${RESET}"
                sleep 2
                config_asr_advanced
            fi
            ;;
        2)
            config_funasr_server
            return 0
            ;;
        3)
            if [ "$IS_MEMORY_SUFFICIENT" = true ]; then
                config_sherpa_asr
            else
                echo -e "${RED}💀 内存不足无法选择${RESET}"
                echo -e "${YELLOW}请重新选择ASR服务类型...${RESET}"
                sleep 2
                config_asr_advanced
            fi
            ;;
        4)
            if [ "$IS_SHERPA_PARAFORMER_AVAILABLE" = true ]; then
                config_sherpa_paraformer_asr
            else
                echo -e "${RED}💀 内存不足 (${MEM_TOTAL}GB < 2GB) 无法选择${RESET}"
                echo -e "${YELLOW}请重新选择ASR服务类型...${RESET}"
                sleep 2
                config_asr_advanced
            fi
            ;;
        5)
            if [ "$IS_MEMORY_SUFFICIENT" = true ]; then
                config_vosk_asr
            else
                echo -e "${RED}💀 内存不足无法选择${RESET}"
                echo -e "${YELLOW}请重新选择ASR服务类型...${RESET}"
                sleep 2
                config_asr_advanced
            fi
            ;;
        6)
            config_aliyun_asr
            ;;
        7)
            config_aliyun_batch_asr
            ;;
        8)
            config_doubao_stream_asr
            ;;
        9)
            config_doubao_asr
            ;;
        10)
            config_tencent_asr
            ;;
        11)
            config_baidu_asr
            ;;
        12)
            config_openai_asr
            ;;
        13)
            config_groq_asr
            ;;
        14)
            config_qwen_asr
            ;;
        15)
            config_xunfei_stream_asr
            ;;
        *)
            echo -e "${YELLOW}⚠️ 无效选择，请重新选择${RESET}"
            config_asr_advanced
            ;;
    esac
}

# ========================= LLM 配置（8个服务商） =========================

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
        echo " 0) ${YELLOW} 返回上一步 ${RESET}"
        
read -r -p "请输入序号 (默认推荐 1，输入0返回上一步): " llm_choice < /dev/tty
        llm_choice=${llm_choice:-1}
        
        if [ "$llm_choice" = "0" ]; then
            echo -e "${CYAN}🔄 返回上一步${RESET}"
            return 1  # 返回上一步
        fi

        local llm_provider_key
        case $llm_choice in
            1)
                llm_provider_key="ChatGLMLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了智谱清言 ChatGLM。${RESET}"
                echo -e "${CYAN}🔑 密钥获取地址：https://open.bigmodel.cn/usercenter/apikeys${RESET}"
read -r -p "请输入 API Key: " api_key < /dev/tty
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
read -r -p "请输入 API Key: " api_key < /dev/tty
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
read -r -p "请输入 API Key: " api_key < /dev/tty
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
read -r -p "请输入 App ID: " app_id < /dev/tty
read -r -p "请输入 API Secret: " api_secret < /dev/tty
read -r -p "请输入 API Key: " api_key < /dev/tty
                
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
read -r -p "请输入 Access Key: " access_key < /dev/tty
read -r -p "请输入 Secret Key: " secret_key < /dev/tty
                
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
read -r -p "请输入 Access Key ID: " access_key_id < /dev/tty
read -r -p "请输入 Secret Access Key: " secret_access_key < /dev/tty
                
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
read -r -p "请输入 API Key: " api_key < /dev/tty
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
read -r -p "请输入 API Key: " api_key < /dev/tty
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
read -r -p "请输入 API Key: " api_key < /dev/tty
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
read -r -p "请输入 API Key: " api_key < /dev/tty
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
                echo -e "${CYAN}🌐 Gemini需要配置反向代理，请选择代理类型：${RESET}"
                echo " 1) HTTP 代理"
                echo " 2) HTTPS 代理"
                echo " 3) 不使用代理（直接连接）"
                
read -r -p "请选择代理类型 (1-3，默认3): " proxy_choice < /dev/tty
                proxy_choice=${proxy_choice:-3}
                
                case $proxy_choice in
                    1)
read -r -p "请输入HTTP代理地址: " http_proxy < /dev/tty
read -r -p "请输入API Key: " api_key < /dev/tty
                        api_key="${api_key:-}"
                        
                        sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                        if [ -n "$api_key" ]; then
                            sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                        fi
                        if [ -n "$http_proxy" ]; then
                            sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    # http_proxy: .*/    http_proxy: \"$http_proxy\"/" "$CONFIG_FILE"
                        fi
                        ;;
                    2)
read -r -p "请输入HTTPS代理地址: " https_proxy < /dev/tty
read -r -p "请输入API Key: " api_key < /dev/tty
                        api_key="${api_key:-}"
                        
                        sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                        if [ -n "$api_key" ]; then
                            sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                        fi
                        if [ -n "$https_proxy" ]; then
                            sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    # https_proxy: .*/    https_proxy: \"$https_proxy\"/" "$CONFIG_FILE"
                        fi
                        ;;
                    3)
read -r -p "请输入 API Key: " api_key < /dev/tty
                        api_key="${api_key:-}"
                        
                        sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                        if [ -n "$api_key" ]; then
                            sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                        fi
                        ;;
                    *)
                        # 默认不配置代理
read -r -p "请输入 API Key: " api_key < /dev/tty
                        api_key="${api_key:-}"
                        
                        sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                        if [ -n "$api_key" ]; then
                            sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                        fi
                        ;;
                esac
                ;;
            12)
                llm_provider_key="DifyLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了 Dify。${RESET}"
                echo -e "${CYAN}🔑 Dify配置需要以下参数：${RESET}"
                echo "  - API类型: dify (固定值)"
                echo "  - 服务地址: Dify服务地址 (默认: https://api.dify.ai/v1)"
                echo "  - API Key: Dify API密钥"
                echo "  - 对话模式: chat-messages/workflows/run/completion-messages (默认: chat-messages)"
                echo -e "${CYAN}💡 建议使用本地部署的dify接口，国内部分区域访问dify公有云接口可能会受限${RESET}"
                echo -e "${CYAN}💡 如果使用Dify，配置文件里prompt(提示词)是无效的，需要在dify控制台设置提示词${RESET}"
                
read -r -p "请输入服务地址 (默认: https://api.dify.ai/v1): " base_url < /dev/tty
                base_url="${base_url:-https://api.dify.ai/v1}"
read -r -p "请输入 API Key: " api_key < /dev/tty
                api_key="${api_key:-}"
read -r -p "请输入对话模式 (默认: chat-messages): " mode < /dev/tty
                mode="${mode:-chat-messages}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$base_url" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s|^    base_url: .*|    base_url: \"$base_url\"|" "$CONFIG_FILE"
                fi
                if [ -n "$api_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                if [ -n "$mode" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    mode: .*/    mode: \"$mode\"/" "$CONFIG_FILE"
                fi
                echo -e "\n${GREEN}✅ 已选择Dify并配置完成。${RESET}"
                ;;
            13)
                llm_provider_key="OllamaLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了 Ollama本地部署。${RESET}"
                echo -e "${CYAN}🔑 Ollama配置需要以下参数：${RESET}"
                echo "  - API类型: ollama (固定值)"
                echo "  - 服务地址: Ollama服务地址 (默认: http://localhost:11434)"
                echo "  - 模型名称: 已下载的模型名称 (默认: qwen2.5)"
                echo -e "${CYAN}💡 请确保Ollama服务已运行，并使用 'ollama pull <model>' 下载了模型${RESET}"
read -r -p "请输入服务地址 (默认: http://localhost:11434): " service_url < /dev/tty
                service_url="${service_url:-http://localhost:11434}"
read -r -p "请输入模型名称 (默认: qwen2.5): " model_name < /dev/tty
                model_name="${model_name:-qwen2.5}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$service_url" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    service_url: .*/    service_url: \"$service_url\"/" "$CONFIG_FILE"
                fi
                if [ -n "$model_name" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    model_name: .*/    model_name: \"$model_name\"/" "$CONFIG_FILE"
                fi
                echo -e "\n${GREEN}✅ 已选择Ollama本地部署并配置完成。${RESET}"
                ;;
            14)
                llm_provider_key="XinferenceLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了 Xinference。${RESET}"
                echo -e "${CYAN}🔑 Xinference配置需要以下参数：${RESET}"
                echo "  - 服务地址: Xinference服务地址 (默认: http://localhost:9997)"
                echo "  - 模型名称: 已启动的模型名称 (默认: qwen2.5:72b-AWQ)"
                echo -e "${CYAN}💡 请确保Xinference服务已运行，并已启动对应模型${RESET}"
read -r -p "请输入服务地址 (默认: http://localhost:9997): " service_url < /dev/tty
                service_url="${service_url:-http://localhost:9997}"
read -r -p "请输入模型名称 (默认: qwen2.5:72b-AWQ): " model_name < /dev/tty
                model_name="${model_name:-qwen2.5:72b-AWQ}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$service_url" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    service_url: .*/    service_url: \"$service_url\"/" "$CONFIG_FILE"
                fi
                if [ -n "$model_name" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    model_name: .*/    model_name: \"$model_name\"/" "$CONFIG_FILE"
                fi
                echo -e "\n${GREEN}✅ 已选择Xinference并配置完成。${RESET}"
                ;;
            15)
                llm_provider_key="FastgptLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了 FastGPT。${RESET}"
                echo -e "${CYAN}🔑 FastGPT配置需要以下参数：${RESET}"
                echo "  - API类型: fastgpt (固定值)"
                echo "  - 服务地址: FastGPT服务地址 (必需，如: http://localhost:3000/api/v1)"
                echo "  - API Key: FastGPT API密钥"
                echo "  - 自定义变量: 可选的键值对配置 (格式: k1=v1,k2=v2)"
                echo -e "${CYAN}🔑 密钥获取地址：https://cloud.tryfastgpt.ai/account/apikey${RESET}"
                echo -e "${CYAN}💡 如果使用FastGPT，配置文件里prompt(提示词)是无效的，需要在fastgpt控制台设置提示词${RESET}"
                
read -r -p "请输入服务地址 (如: http://localhost:3000/api/v1): " base_url < /dev/tty
                base_url="${base_url:-}"
read -r -p "请输入 API Key: " api_key < /dev/tty
                api_key="${api_key:-}"
read -r -p "请输入自定义变量 (可选，格式: k1=v1,k2=v2): " variables < /dev/tty
                variables="${variables:-}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$base_url" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s|^    base_url: .*|    base_url: \"$base_url\"|" "$CONFIG_FILE"
                fi
                if [ -n "$api_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                if [ -n "$variables" ]; then
                    # 解析变量并写入配置文件
                    IFS=',' read -ra VAR_ARRAY <<< "$variables"
                    for var_pair in "${VAR_ARRAY[@]}"; do
                        if [[ $var_pair == *"="* ]]; then
                            key="${var_pair%%=*}"
                            value="${var_pair#*=}"
                            echo "      $key: \"$value\"" >> /tmp/vars_temp.txt
                        fi
                    done
                    # 删除现有的variables部分并替换
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ { /^  $llm_provider_key:/,/^  [A-Za-z]/ { /^    variables:/,/^    [a-z]/d; } }" "$CONFIG_FILE"
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ { /^    api_key:/a\    variables:" "$CONFIG_FILE"
                    cat /tmp/vars_temp.txt >> "$CONFIG_FILE"
                    rm -f /tmp/vars_temp.txt
                fi
                echo -e "\n${GREEN}✅ 已选择FastGPT并配置完成。${RESET}"
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
        echo "请选择VLLM服务商（共3个）："
        echo " 1) ChatGLMVLLM (智谱清言) [推荐]"
        echo " 2) QwenVLVLLM (通义千问)"
        echo " 3) XunfeiSparkLLM (讯飞星火)"
        echo " 0) ${YELLOW} 返回上一步 ${RESET}"
        
read -r -p "请输入序号 (默认推荐 1，输入0返回上一步): " vllm_choice < /dev/tty
        vllm_choice=${vllm_choice:-1}
        
        if [ "$vllm_choice" = "0" ]; then
            echo -e "${CYAN}🔄 返回上一步，重新配置 LLM 服务${RESET}"
            return 1
        fi

        local vllm_provider_key
        case $vllm_choice in
            1)
                vllm_provider_key="ChatGLMVLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了智谱清言 ChatGLM VLLM。${RESET}"
                echo -e "${CYAN}🔑 密钥获取地址：https://open.bigmodel.cn/usercenter/apikeys${RESET}"
                
                # 检查是否已配置智谱LLM，如果已配置则复用API Key
                existing_llm=$(grep "^  LLM:" "$CONFIG_FILE" | head -1 | cut -d: -f2 | xargs 2>/dev/null || echo "")
                if [ "$existing_llm" = "ChatGLMLLM" ]; then
                    echo -e "${CYAN}🔄 检测到已配置智谱LLM，尝试复用API Key...${RESET}"
                    existing_api_key=$(grep -A 10 "^  ChatGLMLLM:" "$CONFIG_FILE" 2>/dev/null | grep "api_key:" | head -1 | sed 's/.*api_key: "\(.*\)".*/\1/' 2>/dev/null || echo "")
                    
                    if [ -n "$existing_api_key" ] && [ "$existing_api_key" != '""' ] && [ "$existing_api_key" != '""' ]; then
                        echo -e "${GREEN}✅ 已自动复用智谱LLM的API Key: ${existing_api_key:0:10}...${RESET}"
                        api_key="$existing_api_key"
                    else
                        echo -e "${YELLOW}⚠️ 未找到有效的智谱LLM API Key，请重新输入${RESET}"
                        safe_read "请输入 API Key: " api_key
                        api_key="${api_key:-}"
                    fi
                else
                    echo -e "${YELLOW}💡 提示：建议配置智谱LLM以复用API Key${RESET}"
                    safe_read "请输入 API Key: " api_key
                    api_key="${api_key:-}"
                fi
                
                sed -i "/^  VLLM: /c\  VLLM: $vllm_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $vllm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                echo -e "\n${GREEN}✅ 已选择智谱清言VLLM并配置完成。${RESET}"
                ;;
            2)
                vllm_provider_key="QwenVLVLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了通义千问 Qwen VLLM。${RESET}"
                echo -e "${CYAN}🔑 密钥获取地址：https://dashscope.console.aliyun.com/apiKey${RESET}"
                safe_read "请输入 API Key: " api_key
                api_key="${api_key:-}"
                
                sed -i "/^  VLLM: /c\  VLLM: $vllm_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $vllm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                echo -e "\n${GREEN}✅ 通义千问VLLM配置完成${RESET}"
                ;;
            3)
                vllm_provider_key="XunfeiSparkLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了讯飞星火 Xunfei Spark VLLM。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://console.xfyun.cn/app/myapp${RESET}"
                read -r -p "API Password: " api_key < /dev/tty
                api_key="${api_key:-}"
                
                sed -i "/^  VLLM: /c\  VLLM: $vllm_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $vllm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                echo -e "\n${GREEN}✅ 讯飞星火VLLM配置完成${RESET}"
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
        echo "请选择TTS服务商（共22个）："
        echo " 1) EdgeTTS (微软) [推荐]"
        echo " 2) DoubaoTTS (火山引擎)"
        echo " 3) HuoshanDoubleStreamTTS (火山双流)"
        echo " 4) CosyVoiceSiliconflow (SiliconFlow)"
        echo " 5) CozeCnTTS (Coze中文)"
        echo " 6) VolcesAiGatewayTTS (火山网关)"
        echo " 7) FishSpeech (自部署)"
        echo " 8) AliyunTTS (阿里云)"
        echo " 9) AliyunStreamTTS (阿里云流式)"
        echo "10) TencentTTS (腾讯云)"
        echo "11) TTS302AI (302AI)"
        echo "12) GizwitsTTS (机智云)"
        echo "13) ACGNTTS (自部署)"
        echo "14) OpenaiTTS (OpenAI)"
        echo "15) MinimaxTTSHTTPStream (MiniMax流式)"
        echo "16) 自定义TTS (Custom)"
        echo "17) LinkeraiTTS (LinkerAI)"
        echo "18) PaddleSpeechTTS (百度飞桨)"
        echo "19) IndexStreamTTS (Index-TTS-vLLM)"
        echo "20) GPT-Sovits (自部署)"
        echo "21) AliBLTTS (阿里云百炼)"
        echo "22) XunFeiTTS (讯飞)"
        echo " 0) ${YELLOW} 返回上一步 ${RESET}"
        
read -r -p "请输入序号 (默认推荐 1，输入0返回上一步): " tts_choice < /dev/tty
        tts_choice=${tts_choice:-1}
        
        if [ "$tts_choice" = "0" ]; then
            echo -e "${CYAN}🔄 返回上一步，重新配置 VLLM 服务${RESET}"
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
                echo -e "${CYAN}📝 火山引擎TTS需要以下参数：${RESET}"
                echo "  - AppID: 火山引擎语音合成服务AppID"
                echo "  - Access Token: 火山引擎语音合成服务Access Token"
                
                safe_read "请输入 AppID: " appid
                safe_read "请输入 Access Token: " access_token
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                if [ -n "$appid" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    appid: .*/    appid: \"$appid\"/" "$CONFIG_FILE"
                fi
                if [ -n "$access_token" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    access_token: .*/    access_token: \"$access_token\"/" "$CONFIG_FILE"
                fi
                echo -e "\n${GREEN}✅ 已选择火山引擎Doubao TTS。${RESET}"
                ;;
            3)
                tts_provider_key="HuoshanDoubleStreamTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了火山双流 HuoshanDoubleStreamTTS。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://console.volcengine.com/ark${RESET}"
                echo -e "${CYAN}📝 需要以下参数：${RESET}"
                echo "  - AppID: 火山引擎语音合成服务AppID"
                echo "  - Access Token: 火山引擎语音合成服务Access Token"
                
                safe_read "请输入 AppID: " appid
                safe_read "请输入 Access Token: " access_token
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                if [ -n "$appid" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    appid: .*/    appid: \"$appid\"/" "$CONFIG_FILE"
                fi
                if [ -n "$access_token" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    access_token: .*/    access_token: \"$access_token\"/" "$CONFIG_FILE"
                fi
                echo -e "\n${GREEN}✅ 已选择火山双流TTS。${RESET}"
                ;;
            4)
                tts_provider_key="CosyVoiceSiliconflow"
                echo -e "\n${YELLOW}⚠️ 您选择了 CosyVoiceSiliconflow。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://cloud.siliconflow.cn/${RESET}"
                echo -e "${CYAN}📝 需要以下参数：${RESET}"
                echo "  - Access Token: SiliconFlow访问令牌"
                
                safe_read "请输入 Access Token: " access_token
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                if [ -n "$access_token" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    access_token: .*/    access_token: \"$access_token\"/" "$CONFIG_FILE"
                fi
                echo -e "\n${GREEN}✅ 已选择CosyVoiceSiliconflow。${RESET}"
                ;;
            5)
                tts_provider_key="CozeCnTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了 CozeCnTTS。${RESET}"
                echo -e "${CYAN}🔑 需要Coze访问令牌${RESET}"
                echo -e "${CYAN}📝 需要以下参数：${RESET}"
                echo "  - Access Token: Coze访问令牌"
                
                safe_read "请输入 Access Token: " access_token
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                if [ -n "$access_token" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    access_token: .*/    access_token: \"$access_token\"/" "$CONFIG_FILE"
                fi
                echo -e "\n${GREEN}✅ 已选择CozeCnTTS。${RESET}"
                ;;
            6)
                tts_provider_key="VolcesAiGatewayTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了 VolcesAiGatewayTTS。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://www.volcengine.com/products/doubao${RESET}"
                echo -e "${CYAN}📝 需要以下参数：${RESET}"
                echo "  - API Key: API密钥"
                
                safe_read "请输入 API Key: " api_key
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                echo -e "\n${GREEN}✅ 已选择VolcesAiGatewayTTS。${RESET}"
                ;;
            7)
                tts_provider_key="FishSpeech"
                echo -e "\n${YELLOW}⚠️ 您选择了 FishSpeech。${RESET}"
                echo -e "${CYAN}🔧 需要部署 FishSpeech 服务：https://fish.audio${RESET}"
                echo -e "${CYAN}📝 需要API密钥和服务地址${RESET}"
                safe_read "请输入 API Key: " api_key
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                echo -e "\n${GREEN}✅ 已选择FishSpeech。${RESET}"
                ;;
            8)
                tts_provider_key="AliyunTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了阿里云 Aliyun TTS。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://dashscope.console.aliyun.com${RESET}"
                echo -e "${CYAN}📝 阿里云TTS需要以下参数：${RESET}"
                echo "  - Access Key ID: 阿里云账号访问密钥ID"
                echo "  - Access Key Secret: 阿里云账号访问密钥"
                
                safe_read "请输入 Access Key ID: " access_key_id
                safe_read "请输入 Access Key Secret: " access_key_secret
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                if [ -n "$access_key_id" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    access_key_id: .*/    access_key_id: \"$access_key_id\"/" "$CONFIG_FILE"
                fi
                if [ -n "$access_key_secret" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    access_key_secret: .*/    access_key_secret: \"$access_key_secret\"/" "$CONFIG_FILE"
                fi
                echo -e "\n${GREEN}✅ 已选择阿里云Aliyun TTS。${RESET}"
                ;;
            9)
                tts_provider_key="AliyunStreamTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了阿里云 AliyunStreamTTS。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://dashscope.console.aliyun.com${RESET}"
                echo -e "${CYAN}📝 需要以下参数：${RESET}"
                echo "  - Access Key ID: 阿里云账号访问密钥ID"
                echo "  - Access Key Secret: 阿里云账号访问密钥"
                
                safe_read "请输入 Access Key ID: " access_key_id
                safe_read "请输入 Access Key Secret: " access_key_secret
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                if [ -n "$access_key_id" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    access_key_id: .*/    access_key_id: \"$access_key_id\"/" "$CONFIG_FILE"
                fi
                if [ -n "$access_key_secret" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    access_key_secret: .*/    access_key_secret: \"$access_key_secret\"/" "$CONFIG_FILE"
                fi
                echo -e "\n${GREEN}✅ 已选择阿里云AliyunStreamTTS。${RESET}"
                ;;
            10)
                tts_provider_key="TencentTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了腾讯云 Tencent TTS。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://console.cloud.tencent.com/tts${RESET}"
                echo -e "${CYAN}📝 腾讯云TTS需要以下参数：${RESET}"
                echo "  - APPID: 腾讯云语音合成服务APPID"
                echo "  - SecretID: 腾讯云语音合成服务SecretID"
                echo "  - SecretKey: 腾讯云语音合成服务SecretKey"
                
                safe_read "请输入 APPID: " appid
                safe_read "请输入 SecretID: " secret_id
                safe_read "请输入 SecretKey: " secret_key
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                if [ -n "$appid" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    appid: .*/    appid: \"$appid\"/" "$CONFIG_FILE"
                fi
                if [ -n "$secret_id" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    secret_id: .*/    secret_id: \"$secret_id\"/" "$CONFIG_FILE"
                fi
                if [ -n "$secret_key" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    secret_key: .*/    secret_key: \"$secret_key\"/" "$CONFIG_FILE"
                fi
                echo -e "\n${GREEN}✅ 已选择腾讯云Tencent TTS。${RESET}"
                ;;
            11)
                tts_provider_key="TTS302AI"
                echo -e "\n${YELLOW}⚠️ 您选择了 TTS302AI。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://www.302.ai/${RESET}"
                echo -e "${CYAN}📝 需要以下参数：${RESET}"
                echo "  - Access Token: 302AI访问令牌"
                
                safe_read "请输入 Access Token: " access_token
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                if [ -n "$access_token" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    access_token: .*/    access_token: \"$access_token\"/" "$CONFIG_FILE"
                fi
                echo -e "\n${GREEN}✅ 已选择TTS302AI。${RESET}"
                ;;
            12)
                tts_provider_key="GizwitsTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了机智云 Gizwits TTS。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://iot.gizwits.com/${RESET}"
                echo -e "${CYAN}📝 需要以下参数：${RESET}"
                echo "  - Access Token: 火山引擎访问令牌"
                
                safe_read "请输入 Access Token: " access_token
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                if [ -n "$access_token" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    access_token: .*/    access_token: \"$access_token\"/" "$CONFIG_FILE"
                fi
                echo -e "\n${GREEN}✅ 已选择机智云Gizwits TTS。${RESET}"
                ;;
            13)
                tts_provider_key="ACGNTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了自部署 ACGN TTS。${RESET}"
                echo -e "${CYAN}🔑 ACGN TTS配置需要以下参数：${RESET}"
                echo "  - Token: ACGN TTS API Token"
                echo "  - 角色ID: 语音角色ID (默认: 1695)"
                echo "  - 语速倍数: 语速调节倍数 (默认: 1)"
                echo "  - 音调倍数: 音调调节倍数 (默认: 0)"
                echo -e "${CYAN}🔑 在线网址：https://acgn.ttson.cn/${RESET}"
                echo -e "${CYAN}🔑 Token购买：www.ttson.cn${RESET}"
                
                safe_read "请输入 Token: " token
                safe_read "请输入角色ID (默认: 1695): " voice_id
                safe_read "请输入语速倍数 (默认: 1): " speed_factor
                safe_read "请输入音调倍数 (默认: 0): " pitch_factor
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                if [ -n "$token" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    token: .*/    token: \"$token\"/" "$CONFIG_FILE"
                fi
                if [ -n "$voice_id" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    voice_id: .*/    voice_id: $voice_id/" "$CONFIG_FILE"
                fi
                if [ -n "$speed_factor" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    speed_factor: .*/    speed_factor: $speed_factor/" "$CONFIG_FILE"
                fi
                if [ -n "$pitch_factor" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    pitch_factor: .*/    pitch_factor: $pitch_factor/" "$CONFIG_FILE"
                fi
                echo -e "\n${GREEN}✅ 已选择自部署 ACGN TTS。${RESET}"
                ;;
            14)
                tts_provider_key="OpenaiTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了 OpenAI TTS。${RESET}"
                echo -e "${CYAN}🔑 密钥获取地址：https://platform.openai.com/api-keys${RESET}"
                safe_read "请输入 API Key: " api_key
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                echo -e "\n${GREEN}✅ 已选择OpenAI TTS。${RESET}"
                ;;
            15)
                tts_provider_key="MinimaxTTSHTTPStream"
                echo -e "\n${YELLOW}⚠️ 您选择了 MiniMax流式TTS。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://platform.minimaxi.cn/${RESET}"
                echo -e "${CYAN}📝 需要以下参数：${RESET}"
                echo "  - Group ID: MiniMax分组ID"
                echo "  - API Key: MiniMax API密钥"
                
                safe_read "请输入 Group ID: " group_id
                safe_read "请输入 API Key: " api_key
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                if [ -n "$group_id" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    group_id: .*/    group_id: \"$group_id\"/" "$CONFIG_FILE"
                fi
                if [ -n "$api_key" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                echo -e "\n${GREEN}✅ 已选择MiniMax流式TTS。${RESET}"
                ;;
            16)
                tts_provider_key="CustomTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了自定义 TTS。${RESET}"
                echo -e "${CYAN}🔑 请输入自定义TTS服务配置${RESET}"
                safe_read "请输入服务名称: " service_name
                safe_read "请输入服务地址: " service_url
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                if [ -n "$service_name" ] && [ -n "$service_url" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    service_name: .*/    service_name: \"$service_name\"/" "$CONFIG_FILE"
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    service_url: .*/    service_url: \"$service_url\"/" "$CONFIG_FILE"
                fi
                echo -e "\n${GREEN}✅ 已选择自定义TTS。${RESET}"
                ;;
            17)
                tts_provider_key="LinkeraiTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了 LinkerAI TTS。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://linkerai.cn/${RESET}"
                safe_read "请输入 API Key: " api_key
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    access_token: .*/    access_token: \"$api_key\"/" "$CONFIG_FILE"
                fi
                echo -e "\n${GREEN}✅ 已选择LinkerAI TTS。${RESET}"
                ;;
            18)
                tts_provider_key="PaddleSpeechTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了百度飞桨 PaddleSpeech TTS。${RESET}"
                echo -e "${CYAN}🔧 需要部署 PaddleSpeech 服务：https://github.com/PaddlePaddle/PaddleSpeech${RESET}"
                echo -e "${CYAN}📝 默认服务地址：ws://127.0.0.1:8092/paddlespeech/tts/streaming${RESET}"
                safe_read "请输入服务地址 (默认: ws://127.0.0.1:8092/paddlespeech/tts/streaming): " url
                url="${url:-ws://127.0.0.1:8092/paddlespeech/tts/streaming}"
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s|^    url: .*|    url: \"$url\"|" "$CONFIG_FILE"
                echo -e "\n${GREEN}✅ 已选择百度飞桨 PaddleSpeech TTS。${RESET}"
                ;;
            19)
                tts_provider_key="IndexStreamTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了 Index-TTS-vLLM。${RESET}"
                echo -e "${CYAN}🔧 需要部署 Index-TTS-vLLM 服务${RESET}"
                safe_read "请输入服务地址 (默认: http://127.0.0.1:11996/tts): " api_url
                api_url="${api_url:-http://127.0.0.1:11996/tts}"
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s|^    api_url: .*|    api_url: \"$api_url\"|" "$CONFIG_FILE"
                echo -e "\n${GREEN}✅ 已选择Index-TTS-vLLM。${RESET}"
                ;;
            20)
                echo -e "\n${YELLOW}⚠️ 您选择了 GPT-SoVITS。${RESET}"
                echo -e "${CYAN}🔑 请选择GPT-SoVITS版本：${RESET}"
                echo "  1) GPT_SOVITS_V2"
                echo "  2) GPT_SOVITS_V3"
                read -r -p "请选择版本 (默认1): " sovits_version
                sovits_version=${sovits_version:-1}
                
                if [ "$sovits_version" = "2" ]; then
                    tts_provider_key="GPT_SOVITS_V3"
                    echo -e "\n${GREEN}✅ 已选择 GPT_SOVITS_V3。${RESET}"
                    echo "  - 服务地址: http://localhost:9880"
                    echo "  - 文本语言: auto/zh/en/ja/ko/zh-hans/zh-hant/粤 (默认: auto)"
                    echo "  - 参考音频: caixukun.wav"
                    echo "  - 提示语言: zh/en/ja/ko/zh-hans/zh-hant/粤 (默认: zh)"
                    echo "  - 提示文本: 提示文本内容 (可选)"
                    echo -e "${CYAN}💡 启动方法：python api.py${RESET}"
                    
                    read -r -p "请输入服务地址 (默认: http://localhost:9880): " url
                    url="${url:-http://localhost:9880}"
                    read -r -p "请输入文本语言 (默认: auto): " text_language
                    text_language="${text_language:-auto}"
                    read -r -p "请输入参考音频路径 (默认: caixukun.wav): " refer_wav_path
                    refer_wav_path="${refer_wav_path:-caixukun.wav}"
                    read -r -p "请输入提示语言 (默认: zh): " prompt_language
                    prompt_language="${prompt_language:-zh}"
                    read -r -p "请输入提示文本 (可选): " prompt_text
                    
                    sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                    if [ -n "$url" ]; then
                        sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s|^    url: .*|    url: \"$url\"|" "$CONFIG_FILE"
                    fi
                    if [ -n "$text_language" ]; then
                        sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s|^    text_language: .*|    text_language: \"$text_language\"|" "$CONFIG_FILE"
                    fi
                    if [ -n "$refer_wav_path" ]; then
                        sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s|^    refer_wav_path: .*|    refer_wav_path: \"$refer_wav_path\"|" "$CONFIG_FILE"
                    fi
                    if [ -n "$prompt_language" ]; then
                        sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s|^    prompt_language: .*|    prompt_language: \"$prompt_language\"|" "$CONFIG_FILE"
                    fi
                    if [ -n "$prompt_text" ]; then
                        sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s|^    prompt_text: .*|    prompt_text: \"$prompt_text\"|" "$CONFIG_FILE"
                    fi
                    echo -e "\n${GREEN}🎉 GPT-SoVITS V3 配置完成！${RESET}"
                else
                    tts_provider_key="GPT_SOVITS_V2"
                    echo -e "\n${GREEN}✅ 已选择 GPT_SOVITS_V2。${RESET}"
                    echo "  - 服务地址: http://localhost:9880/tts"
                    echo "  - 文本语言: auto/zh/en/ja/ko/zh-hans/zh-hant/粤 (默认: auto)"
                    echo "  - 参考音频: demo.wav"
                    echo "  - 提示语言: zh/en/ja/ko/zh-hans/zh-hant/粤 (默认: zh)"
                    echo "  - 提示文本: 提示文本内容 (可选)"
                    echo -e "${CYAN}💡 启动方法：python api_v2.py -a 127.0.0.1 -p 9880 -c GPT_SoVITS/configs/demo.yaml${RESET}"
                    
                    read -r -p "请输入服务地址 (默认: http://localhost:9880/tts): " url
                    url="${url:-http://localhost:9880/tts}"
                    read -r -p "请输入文本语言 (默认: auto): " text_lang
                    text_lang="${text_lang:-auto}"
                    read -r -p "请输入参考音频路径 (默认: demo.wav): " ref_audio_path
                    ref_audio_path="${ref_audio_path:-demo.wav}"
                    read -r -p "请输入提示语言 (默认: zh): " prompt_lang
                    prompt_lang="${prompt_lang:-zh}"
                    read -r -p "请输入提示文本 (可选): " prompt_text
                    
                    sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                    if [ -n "$url" ]; then
                        sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s|^    url: .*|    url: \"$url\"|" "$CONFIG_FILE"
                    fi
                    if [ -n "$text_lang" ]; then
                        sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s|^    text_lang: .*|    text_lang: \"$text_lang\"|" "$CONFIG_FILE"
                    fi
                    if [ -n "$ref_audio_path" ]; then
                        sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s|^    ref_audio_path: .*|    ref_audio_path: \"$ref_audio_path\"|" "$CONFIG_FILE"
                    fi
                    if [ -n "$prompt_lang" ]; then
                        sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s|^    prompt_lang: .*|    prompt_lang: \"$prompt_lang\"|" "$CONFIG_FILE"
                    fi
                    if [ -n "$prompt_text" ]; then
                        sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s|^    prompt_text: .*|    prompt_text: \"$prompt_text\"|" "$CONFIG_FILE"
                    fi
                    echo -e "\n${GREEN}🎉 GPT-SoVITS V2 配置完成！${RESET}"
                fi
                ;;
            21)
                tts_provider_key="AliBLTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了阿里云百炼 AliBL TTS。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://dashscope.console.aliyun.com${RESET}"
                safe_read "请输入 API Key: " api_key
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                echo -e "\n${GREEN}✅ 已选择阿里云百炼AliBL TTS。${RESET}"
                ;;
            22)
                tts_provider_key="XunFeiTTS"
                echo -e "\n${YELLOW}⚠️ 您选择了讯飞 XunFei TTS。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://console.xfyun.cn/${RESET}"
                safe_read "请输入 App ID: " app_id
                safe_read "请输入 API Secret: " api_secret
                safe_read "请输入 API Key: " api_key
                
                sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$CONFIG_FILE"
                if [ -n "$app_id" ] && [ -n "$api_secret" ] && [ -n "$api_key" ]; then
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    app_id: .*/    app_id: \"$app_id\"/" "$CONFIG_FILE"
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    api_secret: .*/    api_secret: \"$api_secret\"/" "$CONFIG_FILE"
                    sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                echo -e "\n${GREEN}✅ 已选择讯飞XunFei TTS。${RESET}"
                ;;
        esac
        
        # 配置完成，返回0表示成功
        echo -e "\n${GREEN}✅ TTS服务配置完成！${RESET}"
        return 0
    done
}

# ========================= Memory 配置（3个服务商） =========================
config_memory() {
    while true; do
        echo -e "\n\n${GREEN}【5/5】配置 Memory (记忆) 服务${RESET}"
        echo "请选择Memory模式（共3个）："
        echo " 1) 不开启记忆 (nomem) [推荐]"
        echo " 2) 本地短记忆 (mem_local_short) - 隐私优先"
        echo " 3) Mem0AI (mem0ai) - 支持超长记忆 (每月免费1000次)"
        echo " 0) ${YELLOW} 返回上一步 ${RESET}"
        
read -r -p "请输入序号 (默认推荐 1，输入0返回上一步): " memory_choice < /dev/tty
        memory_choice=${memory_choice:-1}
        
        if [ "$memory_choice" = "0" ]; then
            echo -e "${CYAN}🔄 返回上一步，重新配置 TTS 服务${RESET}"
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
read -r -p "请输入 API Key: " mem0_api_key < /dev/tty
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
read -r -p "请输入序号 (默认1): " deploy_choice < /dev/tty
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
    
    # 使用while循环包装配置选择逻辑，支持用户取消后重新选择
    while true; do
        echo -e "\n${PURPLE}==================================================${RESET}"
        echo -e "${CYAN}🔑 选择配置方式  🔑${RESET}"
        echo -e "${PURPLE}==================================================${RESET}"
        echo "0) 现在通过脚本配置密钥和服务商"
        echo "1) 稍后手动填写所有配置（脚本将预设在线服务商以避免启动报错）"
        echo "2) 退出配置（将使用现有配置文件）"
        echo "3) 不配置所有配置，直接返回菜单"
        echo "4) 返回上一个菜单"
        read -r -p "请选择（默认0）：" key_choice < /dev/tty
        key_choice=${key_choice:-0}
        
        # 处理返回上一个菜单
        if [ "$key_choice" = "4" ]; then
            echo -e "\n${CYAN}🔄 返回上一个菜单${RESET}"
            main_menu
            return 1
        fi
        
        # 处理不配置所有配置
        if [ "$key_choice" = "3" ]; then
            echo -e "\n${YELLOW}⚠️ 确认不配置所有配置？${RESET}"
            echo -e "${CYAN}ℹ️ 将跳过所有配置步骤${RESET}"
            echo ""
            echo "请选择："
            echo "1) 确认不配置所有配置"
            echo "2) 取消，返回配置选择菜单"
            read -r -p "请选择（默认1）：" confirm_skip < /dev/tty
            confirm_skip=${confirm_skip:-1}
            
            if [ "$confirm_skip" = "1" ]; then
                echo -e "\n${GREEN}✅ 跳过所有配置${RESET}"
                
                # 使用智能内存风险处理
                show_server_config
                smart_handle_memory_risk
                if [ $? -eq 1 ]; then
                    echo -e "\n${CYAN}🔄 用户取消Docker操作，返回主菜单${RESET}"
                    return 1
                else
                    echo -e "\n${CYAN}🔄 正在返回主菜单...${RESET}"
                    return 1
                fi
            elif [ "$confirm_skip" = "2" ]; then
                echo -e "\n${BLUE}ℹ️ 已取消，返回配置选择菜单${RESET}"
                continue
            else
                echo -e "\n${BLUE}ℹ️ 无效选择，请重新选择${RESET}"
                continue
            fi
        fi
        
        # 处理详细配置选项（选项0）
        if [ "$key_choice" = "0" ]; then
            echo -e "\n${GREEN}✅ 开始进行详细配置...${RESET}"
            break  # 退出循环，进入详细配置
        fi
        
        # 处理默认配置选项（选项1）
        if [ "$key_choice" = "1" ]; then
            echo -e "\n${YELLOW}⚠️ 已选择稍后手动填写。${RESET}"
            echo -e "${CYAN}ℹ️ 为防止服务启动失败，脚本将创建干净的默认配置文件。${RESET}"
            echo -e "${CYAN}ℹ️ 您可以稍后在配置文件中修改为您喜欢的服务商。配置文件路径：$CONFIG_FILE${RESET}"
            
            # 创建干净的默认配置文件
            create_default_config_file
            
            # 设置标志，告知setup_config_file使用默认配置
            export USE_DEFAULT_CONFIG=true
            CURRENT_DEPLOY_TYPE="internal"
            export KEY_CONFIG_MODE="manual"
            
            # 直接返回，不进入配置步骤循环
            echo -e "\n${CYAN}📋 已创建默认配置文件：$CONFIG_FILE${RESET}"
            echo -e "${CYAN}🔄 正在准备启动服务...${RESET}"
            return 0  # 直接返回，不进入配置步骤循环
        fi
        
        # 处理退出配置
        if [ "$key_choice" = "2" ]; then
            echo -e "\n${YELLOW}⚠️ 确认退出详细配置流程？${RESET}"
            echo -e "${CYAN}ℹ️ 退出后将直接使用现有的配置文件${RESET}"
            echo -e "${CYAN}ℹ️ 配置文件路径：$CONFIG_FILE${RESET}"
            echo ""
            echo "请选择："
            echo "1) 确认退出配置，使用现有配置"
            echo "2) 取消，返回配置选择菜单"
            read -r -p "请选择（默认1）：" confirm_exit < /dev/tty
            confirm_exit=${confirm_exit:-1}
            
            if [ "$confirm_exit" = "1" ]; then
                echo -e "\n${GREEN}✅ 使用现有配置文件，退出详细配置流程${RESET}"
                
                # 使用智能内存风险处理
                show_server_config
                smart_handle_memory_risk
                if [ $? -eq 1 ]; then
                    echo -e "\n${CYAN}🔄 用户取消Docker操作，返回主菜单${RESET}"
                    return 1
                else
                    echo -e "\n${CYAN}📋 配置文件将使用：$CONFIG_FILE${RESET}"
                    echo -e "${CYAN}🔄 正在返回主菜单...${RESET}"
                    return 1
                fi
                
                # 设置标志，告知setup_config_file使用现有配置
                export USE_EXISTING_CONFIG=true
                CONFIG_DOWNLOAD_NEEDED="false"
                USE_EXISTING_CONFIG=true
                SKIP_DETAILED_CONFIG=false
                CURRENT_DEPLOY_TYPE="internal"
                export KEY_CONFIG_MODE="manual"
                
                # 关键修复：直接返回到deploy_server，并返回取消状态
                echo -e "\n${CYAN}📋 配置文件将使用：$CONFIG_FILE${RESET}"
                echo -e "${CYAN}🔄 正在返回主菜单...${RESET}"
                return 1  # 返回1表示用户取消配置，返回主菜单
            elif [ "$confirm_exit" = "2" ]; then
                echo -e "\n${BLUE}ℹ️ 已取消退出，返回配置选择菜单${RESET}"
                continue  # 继续循环，重新显示菜单
            else
                echo -e "\n${BLUE}ℹ️ 无效选择，请重新选择${RESET}"
                continue  # 继续循环，重新显示菜单
            fi
        fi
        

    done
        
        # 简化的线性配置流程，支持返回上一步
        local config_step=1
        local max_steps=5
        
        while [ $config_step -le $max_steps ]; do
            case $config_step in
                1)
                    echo -e "\n${CYAN}=== 第1步：配置 ASR (语音识别) 服务 ===${RESET}"
                    config_asr_advanced
                    local asr_result=$?
                    if [ $asr_result -eq 2 ]; then
                        echo -e "\n${YELLOW}⚠️ 用户取消配置${RESET}"
                        return 1  # 完全退出配置
                    elif [ $asr_result -eq 1 ]; then
                        echo -e "\n${CYAN}🔄 重新开始配置流程${RESET}"
                        config_step=1
                        continue
                    fi
                    ;;
                2)
                    echo -e "\n${CYAN}=== 第2步：配置 LLM (大语言模型) 服务 ===${RESET}"
                    config_llm_advanced
                    local llm_result=$?
                    if [ $llm_result -eq 2 ]; then
                        echo -e "\n${YELLOW}⚠️ 用户取消配置${RESET}"
                        return 1
                    elif [ $llm_result -eq 1 ]; then
                        config_step=1  # 返回上一步
                        echo -e "\n${CYAN}🔄 返回上一步${RESET}"
                        continue
                    fi
                    ;;
                3)
                    echo -e "\n${CYAN}=== 第3步：配置 VLLM (视觉大语言模型) 服务 ===${RESET}"
                    config_vllm
                    local vllm_result=$?
                    if [ $vllm_result -eq 2 ]; then
                        echo -e "\n${YELLOW}⚠️ 用户取消配置${RESET}"
                        return 1
                    elif [ $vllm_result -eq 1 ]; then
                        config_step=2  # 返回上一步
                        echo -e "\n${CYAN}🔄 返回上一步${RESET}"
                        continue
                    fi
                    ;;
                4)
                    echo -e "\n${CYAN}=== 第4步：配置 TTS (语音合成) 服务 ===${RESET}"
                    config_tts_advanced
                    local tts_result=$?
                    if [ $tts_result -eq 2 ]; then
                        echo -e "\n${YELLOW}⚠️ 用户取消配置${RESET}"
                        return 1
                    elif [ $tts_result -eq 1 ]; then
                        config_step=3  # 返回上一步
                        echo -e "\n${CYAN}🔄 返回上一步${RESET}"
                        continue
                    fi
                    ;;
                5)
                    echo -e "\n${CYAN}=== 第5步：配置 Memory (记忆) 服务 ===${RESET}"
                    config_memory
                    local memory_result=$?
                    if [ $memory_result -eq 2 ]; then
                        echo -e "\n${YELLOW}⚠️ 用户取消配置${RESET}"
                        return 1
                    elif [ $memory_result -eq 1 ]; then
                        config_step=4  # 返回上一步
                        echo -e "\n${CYAN}🔄 返回上一步${RESET}"
                        continue
                    fi
                    ;;
            esac
            config_step=$((config_step + 1))
        done
        
        echo -e "\n${GREEN}🎉 所有服务配置完成！${RESET}"
        
        echo -e "\n${CYAN}=== 第6步：配置服务器地址 (自动生成) ===${RESET}"
        config_server
        if [ $? -eq 1 ]; then
            echo -e "\n${CYAN}=== 重新配置 Memory (记忆) 服务 ===${RESET}"
            config_memory
            if [ $? -eq 1 ]; then
                return 1  # 直接返回，不再继续配置流程
            fi
        fi
        
        echo -e "\n${GREEN}✅ 配置完成！${RESET}"
        echo -e "${CYAN}ℹ️ 详细配置文件已保存至: $CONFIG_FILE${RESET}"
        export KEY_CONFIG_MODE="auto"
        return 0  # 配置成功完成
}

# ========================= 高级TTS配置 =========================
config_tts_advanced() {
    echo -e "${YELLOW}🎤 语音合成(TTS)服务详细配置${RESET}"
    echo -e "${CYAN}请选择TTS服务类型：${RESET}"
    echo "1)  EdgeTTS (微软Edge浏览器语音，免费)"
    echo "2)  DoubaoTTS (火山引擎语音，需要购买)"
    echo "3)  HuoshanDoubleStreamTTS (火山大模型语音)"
    echo "4)  CosyVoiceSiliconflow (硅基流动)"
    echo "5)  CozeCnTTS (Coze中国)"
    echo "6)  VolcesAiGatewayTTS (火山网关)"
    echo "7)  MinimaxTTSHTTPStream (MiniMax流式TTS)"
    echo "8)  AliyunStreamTTS (阿里云流式CosyVoice)"
    echo "9)  TencentTTS (腾讯云智能语音)"
    echo "10) GPT_SOVITS_V2 (自定义声音克隆)"
    echo "11) GPT_SOVITS_V3 (GPT-SoVITS v3版本)"
    echo "12) TTS302AI (302AI语音合成)"
    echo "13) GizwitsTTS (机智云TTS)"
    echo "14) OpenAITTS (OpenAI官方语音)"
    echo "15) 阿里云TTS (传统TTS)"
    echo "16) 讯飞TTS (传统TTS)"
    echo "17) AliBLTTS (阿里百炼CosyVoice)"
    echo "18) CustomTTS (自定义TTS接口)"
    echo "19) LinkeraiTTS (Linker AI TTS)"
    echo "20) PaddleSpeechTTS (百度飞桨本地TTS)"
    echo "21) IndexStreamTTS (Index-TTS-vLLM)"
    echo "22) ACGNTTS (ACGN角色TTS)"
    echo "23) 本地FishSpeech (需要独立部署)"
    echo "0)  返回上级菜单"
    
    read -r -p "请选择TTS服务类型 (0-23，默认1): " tts_choice < /dev/tty
    tts_choice=${tts_choice:-1}
    
    case $tts_choice in
        0)
            return 1
            ;;
        1)
            config_edge_tts
            ;;
        2)
            config_doubao_tts
            ;;
        3)
            config_huoshan_tts
            ;;
        4)
            config_cosyvoice_siliconflow
            ;;
        5)
            config_cozecn_tts
            ;;
        6)
            config_volces_aigateway_tts
            ;;
        7)
            config_minimax_tts
            ;;
        8)
            config_aliyun_stream_tts
            ;;
        9)
            config_tencent_tts
            ;;
        10)
            config_gpt_sovits_v2
            ;;
        11)
            config_gpt_sovits_v3
            ;;
        12)
            config_tts_302ai
            ;;
        13)
            config_gizwits_tts
            ;;
        14)
            config_openai_tts
            ;;
        15)
            config_aliyun_tts
            ;;
        16)
            config_xunfei_tts
            ;;
        17)
            config_alibl_tts
            ;;
        18)
            config_custom_tts
            ;;
        19)
            config_linkerai_tts
            ;;
        20)
            config_paddle_speech_tts
            ;;
        21)
            config_index_stream_tts
            ;;
        22)
            config_acgn_tts
            ;;
        23)
            config_fish_speech
            ;;
        *)
            echo -e "${YELLOW}⚠️ 无效选择，使用默认EdgeTTS${RESET}"
            config_edge_tts
            ;;
    esac
}

# EdgeTTS配置
config_edge_tts() {
    echo -e "\n${CYAN}🎭 配置EdgeTTS (微软语音)${RESET}"
    echo -e "${YELLOW}EdgeTTS提供多种免费音色，支持中英文等多种语言${RESET}"
    
    echo -e "\n${CYAN}推荐的中文音色：${RESET}"
    echo "1) zh-CN-XiaoxiaoNeural (小晓 - 女声，温柔)"
    echo "2) zh-CN-YunxiNeural (云希 - 男声，清朗)"
    echo "3) zh-CN-YunjianNeural (云健 - 男声，磁性)"
    echo "4) zh-CN-XiaoyiNeural (小艺 - 女声，活泼)"
    echo "5) zh-CN-XiaohanNeural (小涵 - 女声，知性)"
    echo "6) 自定义音色名称"
    
    read -r -p "请选择音色 (1-6，默认1): " voice_choice < /dev/tty
    voice_choice=${voice_choice:-1}
    
    case $voice_choice in
        1) voice="zh-CN-XiaoxiaoNeural" ;;
        2) voice="zh-CN-YunxiNeural" ;;
        3) voice="zh-CN-YunjianNeural" ;;
        4) voice="zh-CN-XiaoyiNeural" ;;
        5) voice="zh-CN-XiaohanNeural" ;;
        6)
            echo -e "${CYAN}请输入自定义音色名称：${RESET}"
            read -r voice < /dev/tty
            [ -z "$voice" ] && voice="zh-CN-XiaoxiaoNeural"
            ;;
        *)
            voice="zh-CN-XiaoxiaoNeural"
            ;;
    esac
    
    # 更新配置文件
    sed -i "s/selected_module:/selected_module:\n  VAD: SileroVAD\n  ASR: AliyunStreamASR\n  LLM: ChatGLMLLM\n  VLLM: ChatGLMVLLM\n  TTS: EdgeTTS\n  Memory: nomem\n  Intent: function_call/" "$CONFIG_FILE"
    
    # 写入EdgeTTS配置
    cat >> "$CONFIG_FILE" << EOF

TTS:
  EdgeTTS:
    type: edge
    voice: $voice
    output_dir: tmp/
EOF
    
    echo -e "${GREEN}✅ EdgeTTS配置完成，使用音色：$voice${RESET}"
}

# DoubaoTTS配置
config_doubao_tts() {
    echo -e "\n${CYAN}🔥 配置DoubaoTTS (火山引擎)${RESET}"
    echo -e "${YELLOW}需要购买服务，起步价30元，100并发。免费版仅2并发${RESET}"
    
    echo -e "\n${CYAN}请输入火山引擎语音配置信息：${RESET}"
    read -r -p "AppID: " appid < /dev/tty
    read -r -p "Access Token: " access_token < /dev/tty
    
    if [ -z "$appid" ] || [ -z "$access_token" ]; then
        echo -e "${YELLOW}⚠️ 缺少必要配置，使用默认配置${RESET}"
        appid="你的火山引擎语音合成服务appid"
        access_token="你的火山引擎语音合成服务access_token"
    fi
    
    echo -e "\n${CYAN}音色选择：${RESET}"
    echo "1) BV001_streaming (默认)"
    echo "2) zh_female_wanwanxiaohe_moon_bigtts (湾湾小何)"
    echo "3) 自定义音色"
    
    read -r -p "请选择音色 (1-3，默认1): " doubao_voice_choice < /dev/tty
    doubao_voice_choice=${doubao_voice_choice:-1}
    
    case $doubao_voice_choice in
        1) voice="BV001_streaming" ;;
        2) voice="zh_female_wanwanxiaohe_moon_bigtts" ;;
        3)
            echo -e "${CYAN}请输入自定义音色名称：${RESET}"
            read -r voice < /dev/tty
            [ -z "$voice" ] && voice="BV001_streaming"
            ;;
        *)
            voice="BV001_streaming"
            ;;
    esac
    
    sed -i "s/selected_module:/selected_module:\n  VAD: SileroVAD\n  ASR: AliyunStreamASR\n  LLM: ChatGLMLLM\n  VLLM: ChatGLMVLLM\n  TTS: DoubaoTTS\n  Memory: nomem\n  Intent: function_call/" "$CONFIG_FILE"
    
    cat >> "$CONFIG_FILE" << EOF

TTS:
  DoubaoTTS:
    type: doubao
    api_url: https://openspeech.bytedance.com/api/v1/tts
    voice: $voice
    output_dir: tmp/
    authorization: "Bearer;"
    appid: $appid
    access_token: $access_token
    cluster: volcano_tts
    speed_ratio: 1.0
    volume_ratio: 1.0
    pitch_ratio: 1.0
EOF
    
    echo -e "${GREEN}✅ DoubaoTTS配置完成${RESET}"
}

# GPT-SoVITS V2配置
config_gpt_sovits_v2() {
    echo -e "\n${CYAN}🎙️ 配置GPT-SoVITS V2 (声音克隆)${RESET}"
    echo -e "${YELLOW}GPT-SoVITS是开源的声音克隆工具，需要先本地部署TTS服务${RESET}"
    
    echo -e "\n${CYAN}服务启动方法：${RESET}"
    echo "1. 下载并配置GPT-SoVITS"
    echo "2. 启动TTS服务：python api_v2.py -a 127.0.0.1 -p 9880 -c GPT_SoVITS/configs/demo.yaml"
    echo "3. 准备参考音频和文本"
    
    echo -e "\n${CYAN}请输入配置信息：${RESET}"
    read -r -p "TTS服务地址 (默认127.0.0.1:9880): " sovits_url < /dev/tty
    sovits_url=${sovits_url:-127.0.0.1:9880}
    
    read -r -p "参考音频路径 (默认demo.wav): " ref_audio < /dev/tty
    ref_audio=${ref_audio:-demo.wav}
    
    read -r -p "提示文本 (可选): " prompt_text < /dev/tty
    
    echo -e "\n${CYAN}高级参数设置：${RESET}"
    read -r -p "TopK (默认5): " top_k < /dev/tty
    top_k=${top_k:-5}
    
    read -r -p "Temperature (默认1): " temperature < /dev/tty
    temperature=${temperature:-1}
    
    sed -i "s/selected_module:/selected_module:\n  VAD: SileroVAD\n  ASR: AliyunStreamASR\n  LLM: ChatGLMLLM\n  VLLM: ChatGLMVLLM\n  TTS: GPT_SOVITS_V2\n  Memory: nomem\n  Intent: function_call/" "$CONFIG_FILE"
    
    cat >> "$CONFIG_FILE" << EOF

TTS:
  GPT_SOVITS_V2:
    type: gpt_sovits_v2
    url: "http://$sovits_url/tts"
    output_dir: tmp/
    text_lang: "auto"
    ref_audio_path: "$ref_audio"
    prompt_text: "$prompt_text"
    prompt_lang: "zh"
    top_k: $top_k
    top_p: 1
    temperature: $temperature
    text_split_method: "cut0"
    batch_size: 1
    batch_threshold: 0.75
    split_bucket: true
    return_fragment: false
    speed_factor: 1.0
    streaming_mode: false
    seed: -1
    parallel_infer: true
    repetition_penalty: 1.35
    aux_ref_audio_paths: []
EOF
    
    echo -e "${GREEN}✅ GPT-SoVITS V2配置完成${RESET}"
    echo -e "${YELLOW}💡 请确保TTS服务已启动在 $sovits_url${RESET}"
}

# GPT-SoVITS V3配置
config_gpt_sovits_v3() {
    echo -e "\n${CYAN}🎙️ 配置GPT-SoVITS V3 (最新版本)${RESET}"
    echo -e "${YELLOW}GPT-SoVITS-v3lora版本，提供更好的声音克隆效果${RESET}"
    
    echo -e "\n${CYAN}服务启动方法：${RESET}"
    echo "1. 下载并配置GPT-SoVITS V3"
    echo "2. 启动服务：python api.py"
    echo "3. 访问 http://127.0.0.1:9880"
    
    echo -e "\n${CYAN}请输入配置信息：${RESET}"
    read -r -p "服务地址 (默认127.0.0.1:9880): " sovits_v3_url < /dev/tty
    sovits_v3_url=${sovits_v3_url:-127.0.0.1:9880}
    
    read -r -p "参考音频路径: " refer_wav < /dev/tty
    
    read -r -p "提示文本 (可选): " prompt_text_v3 < /dev/tty
    
    echo -e "\n${CYAN}高级参数设置：${RESET}"
    read -r -p "TopK (默认15): " top_k_v3 < /dev/tty
    top_k_v3=${top_k_v3:-15}
    
    read -r -p "Temperature (默认1.0): " temp_v3 < /dev/tty
    temp_v3=${temp_v3:-1.0}
    
    read -r -p "Speed (默认1.0): " speed_v3 < /dev/tty
    speed_v3=${speed_v3:-1.0}
    
    sed -i "s/selected_module:/selected_module:\n  VAD: SileroVAD\n  ASR: AliyunStreamASR\n  LLM: ChatGLMLLM\n  VLLM: ChatGLMVLLM\n  TTS: GPT_SOVITS_V3\n  Memory: nomem\n  Intent: function_call/" "$CONFIG_FILE"
    
    cat >> "$CONFIG_FILE" << EOF

TTS:
  GPT_SOVITS_V3:
    type: gpt_sovits_v3
    url: "http://$sovits_v3_url"
    output_dir: tmp/
    text_language: "auto"
    refer_wav_path: "$refer_wav"
    prompt_language: "zh"
    prompt_text: "$prompt_text_v3"
    top_k: $top_k_v3
    top_p: 1.0
    temperature: $temp_v3
    cut_punc: ""
    speed: $speed_v3
    inp_refs: []
    sample_steps: 32
    if_sr: false
EOF
    
    echo -e "${GREEN}✅ GPT-SoVITS V3配置完成${RESET}"
    echo -e "${YELLOW}💡 请确保服务已启动在 $sovits_v3_url${RESET}"
}

# 高级LLM配置
config_llm_advanced() {
    echo -e "${YELLOW}🤖 大语言模型(LLM)服务详细配置${RESET}"
    echo -e "${CYAN}请选择LLM服务类型：${RESET}"
    
    while true; do
        echo "1)  ChatGLMLLM (智谱清言，推荐)"
        echo "2)  QwenLLM (通义千问)"
        echo "3)  KimiLLM (月之暗面)"
        echo "4)  SparkLLM (讯飞星火)"
        echo "5)  WenxinLLM (百度文心一言)"
        echo "6)  DoubaoLLM (火山引擎豆包)"
        echo "7)  OpenaiLLM (OpenAI)"
        echo "8)  GroqLLM (Groq)"
        echo "9)  AliLLM (阿里云)"
        echo "10) DeepSeekLLM (DeepSeek)"
        echo "11) GeminiLLM (谷歌Gemini)"
        echo "12) DifyLLM (Dify)"
        echo "13) OllamaLLM (Ollama本地)"
        echo "14) XinferenceLLM (Xinference)"
        echo "15) FastgptLLM (FastGPT)"
        echo "16) AliAppLLM (阿里百炼应用型)"
        echo "17) CozeLLM (Coze个人令牌)"
        echo "18) VolcesAiGatewayLLM (火山网关)"
        echo "19) LMStudioLLM (LM Studio本地)"
        echo "20) HomeAssistant (家庭助手集成)"
        echo "21) XinferenceSmallLLM (轻量级Xinference)"
        echo "0)  返回上级菜单"
        
        read -r -p "请选择LLM服务类型 (0-21，默认1): " llm_choice < /dev/tty
        llm_choice=${llm_choice:-1}
        
        if [ "$llm_choice" = "0" ]; then
            return 1
        fi
        
        local llm_provider_key
        case $llm_choice in
            1)
                llm_provider_key="ChatGLMLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了智谱清言 ChatGLM。${RESET}"
                echo -e "${CYAN}🔑 密钥获取地址：https://open.bigmodel.cn/usercenter/apikeys${RESET}"
                read -r -p "请输入 API Key: " api_key < /dev/tty
                api_key="${api_key:-}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                echo -e "${GREEN}✅ ChatGLM配置完成${RESET}"
                return 0
                ;;
            2)
                llm_provider_key="QwenLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了通义千问 Qwen。${RESET}"
                echo -e "${CYAN}🔑 密钥获取地址：https://dashscope.console.aliyun.com/apiKey${RESET}"
                read -r -p "请输入 API Key: " api_key < /dev/tty
                api_key="${api_key:-}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                echo -e "${GREEN}✅ Qwen配置完成${RESET}"
                return 0
                ;;
            3)
                llm_provider_key="KimiLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了月之暗面 Kimi。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://platform.moonshot.cn/${RESET}"
                read -r -p "请输入 API Key: " api_key < /dev/tty
                api_key="${api_key:-}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                echo -e "${GREEN}✅ Kimi配置完成${RESET}"
                return 0
                ;;
            4)
                llm_provider_key="SparkLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了讯飞星火 Spark。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://console.xfyun.cn/${RESET}"
                read -r -p "请输入 App ID: " app_id < /dev/tty
                read -r -p "请输入 API Secret: " api_secret < /dev/tty
                read -r -p "请输入 API Key: " api_key < /dev/tty
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$app_id" ] && [ -n "$api_secret" ] && [ -n "$api_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    app_id: .*/    app_id: \"$app_id\"/" "$CONFIG_FILE"
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_secret: .*/    api_secret: \"$api_secret\"/" "$CONFIG_FILE"
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                echo -e "${GREEN}✅ Spark配置完成${RESET}"
                return 0
                ;;
            5)
                llm_provider_key="WenxinLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了百度文心一言 Wenxin。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://console.bce.baidu.com/ai/#/ai/wenxinworkshop/app/index${RESET}"
                read -r -p "请输入 Access Key: " access_key < /dev/tty
                read -r -p "请输入 Secret Key: " secret_key < /dev/tty
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$access_key" ] && [ -n "$secret_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    access_key: .*/    access_key: \"$access_key\"/" "$CONFIG_FILE"
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    secret_key: .*/    secret_key: \"$secret_key\"/" "$CONFIG_FILE"
                fi
                echo -e "${GREEN}✅ Wenxin配置完成${RESET}"
                return 0
                ;;
            6)
                llm_provider_key="DoubaoLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了火山引擎豆包 Doubao。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://www.volcengine.com/console/doubao${RESET}"
                read -r -p "请输入 API Key: " api_key < /dev/tty
                api_key="${api_key:-}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                echo -e "${GREEN}✅ Doubao配置完成${RESET}"
                return 0
                ;;
            7)
                llm_provider_key="OpenaiLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了 OpenAI。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://platform.openai.com/api-keys${RESET}"
                read -r -p "请输入 API Key: " api_key < /dev/tty
                api_key="${api_key:-}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                echo -e "${GREEN}✅ OpenAI配置完成${RESET}"
                return 0
                ;;
            8)
                llm_provider_key="GroqLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了 Groq。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://console.groq.com/keys${RESET}"
                read -r -p "请输入 API Key: " api_key < /dev/tty
                api_key="${api_key:-}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                echo -e "${GREEN}✅ Groq配置完成${RESET}"
                return 0
                ;;
            9)
                llm_provider_key="AliLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了阿里云。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://dashscope.console.aliyun.com/apiKey${RESET}"
                read -r -p "请输入 API Key: " api_key < /dev/tty
                api_key="${api_key:-}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                echo -e "${GREEN}✅ 阿里云配置完成${RESET}"
                return 0
                ;;
            10)
                llm_provider_key="DeepSeekLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了 DeepSeek。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://platform.deepseek.com/api_keys${RESET}"
                read -r -p "请输入 API Key: " api_key < /dev/tty
                api_key="${api_key:-}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                echo -e "${GREEN}✅ DeepSeek配置完成${RESET}"
                return 0
                ;;
            11)
                llm_provider_key="GeminiLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了谷歌 Gemini。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://aistudio.google.com/app/apikey${RESET}"
                read -r -p "请输入 API Key: " api_key < /dev/tty
                api_key="${api_key:-}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                echo -e "${GREEN}✅ Gemini配置完成${RESET}"
                return 0
                ;;
            12)
                llm_provider_key="DifyLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了 Dify。${RESET}"
                echo -e "${CYAN}ℹ️ 请确保您的 Dify 服务已正确配置${RESET}"
                read -r -p "请输入 Dify API URL: " dify_url < /dev/tty
                read -r -p "请输入 API Key: " api_key < /dev/tty
                api_key="${api_key:-}"
                dify_url="${dify_url:-}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ] && [ -n "$dify_url" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_url: .*/    api_url: \"$dify_url\"/" "$CONFIG_FILE"
                fi
                echo -e "${GREEN}✅ Dify配置完成${RESET}"
                return 0
                ;;
            13)
                llm_provider_key="OllamaLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了 Ollama 本地。${RESET}"
                echo -e "${CYAN}ℹ️ 请确保 Ollama 服务已在本地运行${RESET}"
                read -r -p "请输入 Ollama URL (默认 http://localhost:11434): " ollama_url < /dev/tty
                read -r -p "请输入模型名称 (如 llama2): " model_name < /dev/tty
                ollama_url="${ollama_url:-http://localhost:11434}"
                model_name="${model_name:-llama2}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$model_name" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_url: .*/    api_url: \"$ollama_url\"/" "$CONFIG_FILE"
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    model: .*/    model: \"$model_name\"/" "$CONFIG_FILE"
                fi
                echo -e "${GREEN}✅ Ollama配置完成${RESET}"
                return 0
                ;;
            14)
                llm_provider_key="XinferenceLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了 Xinference。${RESET}"
                echo -e "${CYAN}ℹ️ 请确保 Xinference 服务已正确配置${RESET}"
                read -r -p "请输入 Xinference URL (默认 http://localhost:9997): " xinference_url < /dev/tty
                read -r -p "请输入模型ID: " model_id < /dev/tty
                xinference_url="${xinference_url:-http://localhost:9997}"
                model_id="${model_id:-}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$model_id" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_url: .*/    api_url: \"$xinference_url\"/" "$CONFIG_FILE"
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    model: .*/    model: \"$model_id\"/" "$CONFIG_FILE"
                fi
                echo -e "${GREEN}✅ Xinference配置完成${RESET}"
                return 0
                ;;
            15)
                llm_provider_key="FastgptLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了 FastGPT。${RESET}"
                echo -e "${CYAN}ℹ️ 请确保 FastGPT 服务已正确配置${RESET}"
                read -r -p "请输入 FastGPT API URL: " fastgpt_url < /dev/tty
                read -r -p "请输入 API Key: " api_key < /dev/tty
                api_key="${api_key:-}"
                fastgpt_url="${fastgpt_url:-}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ] && [ -n "$fastgpt_url" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_url: .*/    api_url: \"$fastgpt_url\"/" "$CONFIG_FILE"
                fi
                echo -e "${GREEN}✅ FastGPT配置完成${RESET}"
                return 0
                ;;
            16)
                llm_provider_key="AliAppLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了阿里百炼应用型LLM。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://bailian.console.aliyun.com/apiKey${RESET}"
                read -r -p "App ID: " app_id < /dev/tty
                read -r -p "API Key: " api_key < /dev/tty
                api_key="${api_key:-}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$app_id" ] && [ -n "$api_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    app_id: .*/    app_id: \"$app_id\"/" "$CONFIG_FILE"
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                echo -e "${GREEN}✅ 阿里百炼应用型配置完成${RESET}"
                return 0
                ;;
            17)
                llm_provider_key="CozeLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了 Coze 个人令牌LLM。${RESET}"
                echo -e "${CYAN}🔑 令牌地址：https://www.coze.cn/open/oauth/pats${RESET}"
                read -r -p "Bot ID: " bot_id < /dev/tty
                read -r -p "User ID: " user_id < /dev/tty
                read -r -p "Personal Access Token: " pat < /dev/tty
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$bot_id" ] && [ -n "$user_id" ] && [ -n "$pat" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    bot_id: .*/    bot_id: \"$bot_id\"/" "$CONFIG_FILE"
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    user_id: .*/    user_id: \"$user_id\"/" "$CONFIG_FILE"
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    personal_access_token: .*/    personal_access_token: \"$pat\"/" "$CONFIG_FILE"
                fi
                echo -e "${GREEN}✅ Coze配置完成${RESET}"
                return 0
                ;;
            18)
                llm_provider_key="VolcesAiGatewayLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了火山引擎边缘大模型网关。${RESET}"
                echo -e "${CYAN}🔑 网关地址：https://console.volcengine.com/vei/aigateway/tokens-list${RESET}"
                read -r -p "Gateway Access Key: " api_key < /dev/tty
                api_key="${api_key:-}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                echo -e "${GREEN}✅ 火山网关配置完成${RESET}"
                return 0
                ;;
            19)
                llm_provider_key="LMStudioLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了 LM Studio 本地模型。${RESET}"
                echo -e "${CYAN}ℹ️ 请确保 LM Studio 服务已在本地运行${RESET}"
                read -r -p "服务地址 (默认 http://localhost:1234): " lm_url < /dev/tty
                read -r -p "模型名称: " model_name < /dev/tty
                lm_url="${lm_url:-http://localhost:1234}"
                model_name="${model_name:-}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$model_name" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    url: .*/    url: \"$lm_url\"/" "$CONFIG_FILE"
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    model_name: .*/    model_name: \"$model_name\"/" "$CONFIG_FILE"
                fi
                echo -e "${GREEN}✅ LM Studio配置完成${RESET}"
                return 0
                ;;
            20)
                llm_provider_key="HomeAssistant"
                echo -e "\n${YELLOW}⚠️ 您选择了 Home Assistant 集成。${RESET}"
                echo -e "${CYAN}ℹ️ 请确保 Home Assistant 服务已正确配置${RESET}"
                read -r -p "Home Assistant 地址 (默认 http://homeassistant.local:8123): " hass_url < /dev/tty
                read -r -p "API Key: " api_key < /dev/tty
                hass_url="${hass_url:-http://homeassistant.local:8123}"
                api_key="${api_key:-}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$api_key" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    base_url: .*/    base_url: \"$hass_url\"/" "$CONFIG_FILE"
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$CONFIG_FILE"
                fi
                echo -e "${GREEN}✅ Home Assistant配置完成${RESET}"
                return 0
                ;;
            21)
                llm_provider_key="XinferenceSmallLLM"
                echo -e "\n${YELLOW}⚠️ 您选择了轻量级 Xinference 模型。${RESET}"
                echo -e "${CYAN}ℹ️ 用于意图识别的小模型${RESET}"
                read -r -p "请输入 Xinference URL (默认 http://localhost:9997): " xinference_url < /dev/tty
                read -r -p "请输入小模型ID (默认 qwen2.5:3b-AWQ): " model_id < /dev/tty
                xinference_url="${xinference_url:-http://localhost:9997}"
                model_id="${model_id:-qwen2.5:3b-AWQ}"
                
                sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$CONFIG_FILE"
                if [ -n "$model_id" ]; then
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    base_url: .*/    base_url: \"$xinference_url\"/" "$CONFIG_FILE"
                    sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    model_name: .*/    model_name: \"$model_id\"/" "$CONFIG_FILE"
                fi
                echo -e "${GREEN}✅ 轻量级Xinference配置完成${RESET}"
                return 0
                ;;
            *)
                echo -e "${RED}❌ 无效选择，请重新选择${RESET}"
                ;;
        esac
    done
}

# 其他TTS服务配置（简化版本）
config_openai_tts() {
    echo -e "\n${CYAN}🤖 配置OpenAI TTS${RESET}"
    read -r -p "OpenAI API Key: " openai_key < /dev/tty
    
    echo -e "\n${CYAN}语音选择：${RESET}"
    echo "1) onyx (深沉男声)"
    echo "2) nova (年轻女声)"
    echo "3) alloy (中性声音)"
    echo "4) fable (英式口音)"
    echo "5) shimmer (温暖女声)"
    echo "6) echo (年轻男声)"
    
    read -r -p "选择语音 (1-6，默认1): " openai_voice_choice < /dev/tty
    openai_voice_choice=${openai_voice_choice:-1}
    
    case $openai_voice_choice in
        1) voice="onyx" ;;
        2) voice="nova" ;;
        3) voice="alloy" ;;
        4) voice="fable" ;;
        5) voice="shimmer" ;;
        6) voice="echo" ;;
        *) voice="onyx" ;;
    esac
    
    sed -i "s/selected_module:/selected_module:\n  VAD: SileroVAD\n  ASR: AliyunStreamASR\n  LLM: ChatGLMLLM\n  VLLM: ChatGLMVLLM\n  TTS: OpenAITTS\n  Memory: nomem\n  Intent: function_call/" "$CONFIG_FILE"
    
    cat >> "$CONFIG_FILE" << EOF

TTS:
  OpenAITTS:
    type: openai
    api_key: $openai_key
    api_url: https://api.openai.com/v1/audio/speech
    model: tts-1
    voice: $voice
    speed: 1
    output_dir: tmp/
EOF
    
    echo -e "${GREEN}✅ OpenAI TTS配置完成${RESET}"
}

# 简化的其他TTS配置函数
config_huoshan_tts() {
    echo -e "\n${CYAN}🔥 配置火山大模型TTS${RESET}"
    read -r -p "AppID: " huoshan_appid < /dev/tty
    read -r -p "Access Token: " huoshan_token < /dev/tty
    
    sed -i "s/selected_module:/selected_module:\n  VAD: SileroVAD\n  ASR: AliyunStreamASR\n  LLM: ChatGLMLLM\n  VLLM: ChatGLMVLLM\n  TTS: HuoshanDoubleStreamTTS\n  Memory: nomem\n  Intent: function_call/" "$CONFIG_FILE"
    
    cat >> "$CONFIG_FILE" << EOF

TTS:
  HuoshanDoubleStreamTTS:
    type: huoshan_double_stream
    ws_url: wss://openspeech.bytedance.com/api/v3/tts/bidirection
    appid: $huoshan_appid
    access_token: $huoshan_token
    resource_id: volc.service_type.10029
    speaker: zh_female_wanwanxiaohe_moon_bigtts
    speech_rate: 0
    loudness_rate: 0
    pitch: 0
EOF
    echo -e "${GREEN}✅ 火山大模型TTS配置完成${RESET}"
}

config_aliyun_tts() {
    echo -e "\n${CYAN}☁️ 配置阿里云TTS${RESET}"
    read -r -p "AppKey: " aliyun_appkey < /dev/tty
    read -r -p "Access Key ID: " aliyun_id < /dev/tty
    read -r -p "Access Key Secret: " aliyun_secret < /dev/tty
    
    sed -i "s/selected_module:/selected_module:\n  VAD: SileroVAD\n  ASR: AliyunStreamASR\n  LLM: ChatGLMLLM\n  VLLM: ChatGLMVLLM\n  TTS: AliyunTTS\n  Memory: nomem\n  Intent: function_call/" "$CONFIG_FILE"
    
    cat >> "$CONFIG_FILE" << EOF

TTS:
  AliyunTTS:
    type: aliyun
    output_dir: tmp/
    appkey: $aliyun_appkey
    voice: xiaoyun
    access_key_id: $aliyun_id
    access_key_secret: $aliyun_secret
EOF
    echo -e "${GREEN}✅ 阿里云TTS配置完成${RESET}"
}

# 讯飞ASR配置
config_funasr_server() {
    echo -e "\n${CYAN}🎤 配置 FunASR Server${RESET}"
    echo -e "${YELLOW}⚠️ 您选择了 FunASRServer（独立部署服务）${RESET}"
    echo -e "${CYAN}🔗 需要自行部署 FunASR Server 服务${RESET}"
    echo ""
    echo -e "${CYAN}📋 配置说明：${RESET}"
    echo "  - FunASRServer 是独立的 ASR 服务，需要您自行部署"
    echo "  - 默认端口：10095"
    echo "  - 服务地址格式：http://localhost:10095 或 http://your-server:10095"
    echo ""
    
    # 读取现有配置作为默认值
    local default_host=$(grep -A3 -B1 "FunASRServer:" "$CONFIG_FILE" 2>/dev/null | grep "host:" | awk '{print $2}' || echo "http://localhost:10095")
    
    read -r -p "请输入 FunASR Server 地址 (默认: $default_host): " server_url < /dev/tty
    server_url=${server_url:-$default_host}
    
    # 验证地址格式
    if [[ ! "$server_url" =~ ^https?:// ]]; then
        echo -e "${RED}❌ 地址格式错误，请使用 http:// 或 https:// 开头${RESET}"
        echo -e "${YELLOW}💡 示例：http://localhost:10095${RESET}"
        read -r -p "请重新输入: " server_url < /dev/tty
    fi
    
    # 提取主机部分用于校验
    local host_part=$(echo "$server_url" | sed 's|^https\?://||' | sed 's|/.*||' | sed 's|:.*||')
    
    echo -e "\n${GREEN}✅ 配置信息：${RESET}"
    echo "  - 服务地址: $server_url"
    echo "  - 主机: $host_part"
    echo ""
    
    # 确认配置
    read -r -p "确认配置此地址？(y/N): " confirm < /dev/tty
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}⚠️ 取消配置${RESET}"
        return 1
    fi
    
    # 更新配置文件
    sed -i "/^  ASR: /c\  ASR: FunASRServer" "$CONFIG_FILE"
    sed -i "/^  FunASRServer:/,/^  [A-Za-z]/ s/^    host: .*/    host: $server_url/" "$CONFIG_FILE"
    
    echo -e "\n${GREEN}✅ FunASR Server 配置完成${RESET}"
    echo -e "${CYAN}💡 提示：${RESET}"
    echo "  - 确保您的 FunASR Server 正在运行"
    echo "  - 如果是远程服务器，请确保防火墙允许访问"
    echo "  - 可以使用 curl -s '$server_url/ping' 测试连通性"
}

config_xunfei_stream_asr() {
    echo -e "\n${CYAN}🎤 配置讯飞流式ASR${RESET}"
    
    local app_id=""
    local api_secret=""
    local api_key=""
    
    # 使用默认值检查
    local default_app_id=$(grep -A5 -B1 "XunfeiStreamASR:" "$CONFIG_FILE" 2>/dev/null | grep "app_id:" | awk '{print $2}' || echo "")
    local default_api_secret=$(grep -A5 -B1 "XunfeiStreamASR:" "$CONFIG_FILE" 2>/dev/null | grep "api_secret:" | awk '{print $2}' || echo "")
    local default_api_key=$(grep -A5 -B1 "XunfeiStreamASR:" "$CONFIG_FILE" 2>/dev/null | grep "api_key:" | awk '{print $2}' || echo "")
    
    read -r -p "App ID ${default_app_id:+[默认: $default_app_id]}: " app_id < /dev/tty
    app_id=${app_id:-$default_app_id}
    
    read -r -p "API Secret ${default_api_secret:+[默认: $default_api_secret]}: " api_secret < /dev/tty
    api_secret=${api_secret:-$default_api_secret}
    
    read -r -p "API Key ${default_api_key:+[默认: $default_api_key]}: " api_key < /dev/tty
    api_key=${api_key:-$default_api_key}
    
    if [ -z "$app_id" ] || [ -z "$api_secret" ] || [ -z "$api_key" ]; then
        echo -e "${RED}❌ 缺少必要的参数，请重新配置${RESET}"
        return 1
    fi
    
    sed -i "s/selected_module:/selected_module:\n  VAD: SileroVAD\n  ASR: XunfeiStreamASR\n  LLM: ChatGLMLLM\n  VLLM: ChatGLMVLLM\n  TTS: LinkeraiTTS\n  Memory: nomem\n  Intent: function_call/" "$CONFIG_FILE"
    
    cat >> "$CONFIG_FILE" << EOF

ASR:
  XunfeiStreamASR:
    type: xunfei_stream
    api_url: wss://rtasr.xfyun.cn/v1/ws
    app_id: $app_id
    api_secret: $api_secret
    api_key: $api_key
    language: zh_cn
    domain: rtasr
    vinfo: 1
    vinfo_prompt: 
    vinfo_enable: 1
    voinfo_enable: 1
    voice_type: 
    voice_languages: 
    output_dir: tmp/
EOF
    echo -e "${GREEN}✅ 讯飞流式ASR配置完成${RESET}"
}

config_xunfei_tts() {
    echo -e "\n${CYAN}🗣️ 配置讯飞TTS${RESET}"
    read -r -p "App ID: " xunfei_appid < /dev/tty
    read -r -p "API Secret: " xunfei_secret < /dev/tty
    read -r -p "API Key: " xunfei_key < /dev/tty
    
    sed -i "s/selected_module:/selected_module:\n  VAD: SileroVAD\n  ASR: AliyunStreamASR\n  LLM: ChatGLMLLM\n  VLLM: ChatGLMVLLM\n  TTS: XunFeiTTS\n  Memory: nomem\n  Intent: function_call/" "$CONFIG_FILE"
    
    cat >> "$CONFIG_FILE" << EOF

TTS:
  XunFeiTTS:
    type: xunfei_stream
    api_url: wss://cbm01.cn-huabei-1.xf-yun.com/v1/private/mcd9m97e6
    app_id: $xunfei_appid
    api_secret: $xunfei_secret
    api_key: $xunfei_key
    voice: x5_lingxiaoxuan_flow
    output_dir: tmp/
EOF
    echo -e "${GREEN}✅ 讯飞TTS配置完成${RESET}"
}

config_fish_speech() {
    echo -e "\n${CYAN}🐟 配置FishSpeech (本地声音克隆)${RESET}"
    echo -e "${YELLOW}需要先独立部署FishSpeech服务${RESET}"
    
    read -r -p "服务地址 (默认http://127.0.0.1:8080): " fish_url < /dev/tty
    fish_url=${fish_url:-http://127.0.0.1:8080}
    
    read -r -p "参考音频路径: " fish_ref_audio < /dev/tty
    
    sed -i "s/selected_module:/selected_module:\n  VAD: SileroVAD\n  ASR: AliyunStreamASR\n  LLM: ChatGLMLLM\n  VLLM: ChatGLMVLLM\n  TTS: FishSpeech\n  Memory: nomem\n  Intent: function_call/" "$CONFIG_FILE"
    
    cat >> "$CONFIG_FILE" << EOF

TTS:
  FishSpeech:
    type: fishspeech
    output_dir: tmp/
    response_format: wav
    reference_id: null
    reference_audio: ["$fish_ref_audio"]
    reference_text: ["哈啰啊，我是小智啦，声音好听的中国台湾女孩一枚，超开心认识你耶"]
    normalize: true
    max_new_tokens: 1024
    chunk_length: 200
    top_p: 0.7
    repetition_penalty: 1.2
    temperature: 0.7
    streaming: false
    use_memory_cache: "on"
    seed: null
    channels: 1
    rate: 44100
    api_url: "$fish_url/v1/tts"
EOF
    echo -e "${GREEN}✅ FishSpeech配置完成${RESET}"
}

# 硅基流动CosyVoice配置
config_cosyvoice_siliconflow() {
    echo -e "\n${CYAN}🔧 配置硅基流动CosyVoice TTS${RESET}"
    echo -e "${YELLOW}硅基流动TTS服务，基于CosyVoice2-0.5B模型${RESET}"
    
    read -r -p "Access Token: " token < /dev/tty
    
    echo -e "\n${CYAN}音色选择：${RESET}"
    echo "1) FunAudioLLM/CosyVoice2-0.5B:alex (Alex音色)"
    echo "2) FunAudioLLM/CosyVoice2-0.5B (默认音色)"
    echo "3) 自定义音色"
    
    read -r -p "选择音色 (1-3，默认1): " voice_choice < /dev/tty
    voice_choice=${voice_choice:-1}
    
    case $voice_choice in
        1) voice="FunAudioLLM/CosyVoice2-0.5B:alex" ;;
        2) voice="FunAudioLLM/CosyVoice2-0.5B" ;;
        3)
            echo -e "${CYAN}请输入自定义音色：${RESET}"
            read -r voice < /dev/tty
            [ -z "$voice" ] && voice="FunAudioLLM/CosyVoice2-0.5B:alex"
            ;;
        *) voice="FunAudioLLM/CosyVoice2-0.5B:alex" ;;
    esac
    
    sed -i "s/selected_module:/selected_module:\n  VAD: SileroVAD\n  ASR: AliyunStreamASR\n  LLM: ChatGLMLLM\n  VLLM: ChatGLMVLLM\n  TTS: CosyVoiceSiliconflow\n  Memory: nomem\n  Intent: function_call/" "$CONFIG_FILE"
    
    cat >> "$CONFIG_FILE" << EOF

TTS:
  CosyVoiceSiliconflow:
    type: siliconflow
    model: FunAudioLLM/CosyVoice2-0.5B
    voice: $voice
    output_dir: tmp/
    access_token: $token
    response_format: wav
EOF
    echo -e "${GREEN}✅ 硅基流动CosyVoice配置完成${RESET}"
}

# Coze中国TTS配置
config_cozecn_tts() {
    echo -e "\n${CYAN}🇨🇳 配置Coze中国TTS${RESET}"
    echo -e "${YELLOW}Coze中国语音合成服务${RESET}"
    
    read -r -p "Access Token: " token < /dev/tty
    
    echo -e "\n${CYAN}音色选择：${RESET}"
    echo "1) 7426720361733046281 (默认音色)"
    echo "2) 自定义音色ID"
    
    read -r -p "选择音色 (1-2，默认1): " voice_choice < /dev/tty
    voice_choice=${voice_choice:-1}
    
    case $voice_choice in
        1) voice="7426720361733046281" ;;
        2)
            echo -e "${CYAN}请输入自定义音色ID：${RESET}"
            read -r voice < /dev/tty
            [ -z "$voice" ] && voice="7426720361733046281"
            ;;
        *) voice="7426720361733046281" ;;
    esac
    
    sed -i "s/selected_module:/selected_module:\n  VAD: SileroVAD\n  ASR: AliyunStreamASR\n  LLM: ChatGLMLLM\n  VLLM: ChatGLMVLLM\n  TTS: CozeCnTTS\n  Memory: nomem\n  Intent: function_call/" "$CONFIG_FILE"
    
    cat >> "$CONFIG_FILE" << EOF

TTS:
  CozeCnTTS:
    type: cozecn
    voice: $voice
    output_dir: tmp/
    access_token: $token
    response_format: wav
EOF
    echo -e "${GREEN}✅ Coze中国TTS配置完成${RESET}"
}

# 火山引擎AI网关TTS配置
config_volces_aigateway_tts() {
    echo -e "\n${CYAN}🌋 配置火山引擎AI网关TTS${RESET}"
    echo -e "${YELLOW}火山引擎边缘大模型网关TTS服务${RESET}"
    
    read -r -p "网关访问密钥: " api_key < /dev/tty
    
    echo -e "\n${CYAN}音色选择：${RESET}"
    echo "1) zh_male_shaonianzixin_moon_bigtts (少年子心 - 男声)"
    echo "2) zh_female_wanwanxiaohe_moon_bigtts (湾湾小何 - 女声)"
    echo "3) 自定义音色"
    
    read -r -p "选择音色 (1-3，默认1): " voice_choice < /dev/tty
    voice_choice=${voice_choice:-1}
    
    case $voice_choice in
        1) voice="zh_male_shaonianzixin_moon_bigtts" ;;
        2) voice="zh_female_wanwanxiaohe_moon_bigtts" ;;
        3)
            echo -e "${CYAN}请输入自定义音色：${RESET}"
            read -r voice < /dev/tty
            [ -z "$voice" ] && voice="zh_male_shaonianzixin_moon_bigtts"
            ;;
        *) voice="zh_male_shaonianzixin_moon_bigtts" ;;
    esac
    
    sed -i "s/selected_module:/selected_module:\n  VAD: SileroVAD\n  ASR: AliyunStreamASR\n  LLM: ChatGLMLLM\n  VLLM: ChatGLMVLLM\n  TTS: VolcesAiGatewayTTS\n  Memory: nomem\n  Intent: function_call/" "$CONFIG_FILE"
    
    cat >> "$CONFIG_FILE" << EOF

TTS:
  VolcesAiGatewayTTS:
    type: openai
    api_key: $api_key
    api_url: https://ai-gateway.vei.volces.com/v1/audio/speech
    model: doubao-tts
    voice: $voice
    speed: 1
    output_dir: tmp/
EOF
    echo -e "${GREEN}✅ 火山引擎AI网关TTS配置完成${RESET}"
}

# MiniMax流式TTS配置
config_minimax_tts() {
    echo -e "\n${CYAN}🧠 配置MiniMax流式TTS${RESET}"
    echo -e "${YELLOW}MiniMax流式语音合成服务${RESET}"
    
    read -r -p "Group ID: " group_id < /dev/tty
    read -r -p "API Key: " api_key < /dev/tty
    
    echo -e "\n${CYAN}音色选择：${RESET}"
    echo "1) female-shaonv (少女音)"
    echo "2) male-qn-qingse (男声)"
    echo "3) 自定义音色"
    
    read -r -p "选择音色 (1-3，默认1): " voice_choice < /dev/tty
    voice_choice=${voice_choice:-1}
    
    case $voice_choice in
        1) voice_id="female-shaonv" ;;
        2) voice_id="male-qn-qingse" ;;
        3)
            echo -e "${CYAN}请输入自定义音色ID：${RESET}"
            read -r voice_id < /dev/tty
            [ -z "$voice_id" ] && voice_id="female-shaonv"
            ;;
        *) voice_id="female-shaonv" ;;
    esac
    
    sed -i "s/selected_module:/selected_module:\n  VAD: SileroVAD\n  ASR: AliyunStreamASR\n  LLM: ChatGLMLLM\n  VLLM: ChatGLMVLLM\n  TTS: MinimaxTTSHTTPStream\n  Memory: nomem\n  Intent: function_call/" "$CONFIG_FILE"
    
    cat >> "$CONFIG_FILE" << EOF

TTS:
  MinimaxTTSHTTPStream:
    type: minimax_httpstream
    output_dir: tmp/
    group_id: $group_id
    api_key: $api_key
    model: "speech-01-turbo"
    voice_id: $voice_id
EOF
    echo -e "${GREEN}✅ MiniMax流式TTS配置完成${RESET}"
}

# ========================= 新增TTS配置函数 =========================

# 阿里云流式CosyVoice配置
config_aliyun_stream_tts() {
    echo -e "\n${CYAN}☁️ 配置阿里云流式CosyVoice TTS${RESET}"
    echo -e "${YELLOW}阿里云CosyVoice大模型流式文本语音合成${RESET}"
    
    # 使用默认配置检查
    local default_appkey=$(grep -A5 -B1 "AliyunStreamTTS:" "$CONFIG_FILE" 2>/dev/null | grep "appkey:" | awk '{print $2}' || echo "")
    local default_token=$(grep -A5 -B1 "AliyunStreamTTS:" "$CONFIG_FILE" 2>/dev/null | grep "token:" | awk '{print $2}' || echo "")
    local default_voice=$(grep -A10 -B2 "AliyunStreamTTS:" "$CONFIG_FILE" 2>/dev/null | grep "voice:" | awk '{print $2}' || echo "longxiaochun")
    
    echo -e "${CYAN}阿里云智能语音交互服务配置：${RESET}"
    echo -e "${YELLOW}请在阿里云控制台开通流式TTS服务${RESET}"
    
    read -r -p "App Key ${default_appkey:+[默认: $default_appkey]}: " appkey < /dev/tty
    appkey=${appkey:-$default_appkey}
    
    read -r -p "Access Token ${default_token:+[默认: $default_token]}: " token < /dev/tty
    token=${token:-$default_token}
    
    echo -e "\n${CYAN}音色选择：${RESET}"
    echo "1) longxiaochun (龙晓春，推荐)"
    echo "2) longyu (龙鱼)"
    echo "3) longchen (龙辰)"
    echo "4) 自定义音色"
    
    read -r -p "选择音色 (1-4，默认1): " voice_choice < /dev/tty
    voice_choice=${voice_choice:-1}
    
    case $voice_choice in
        1) voice="longxiaochun" ;;
        2) voice="longyu" ;;
        3) voice="longchen" ;;
        4)
            echo -e "${CYAN}请输入自定义音色：${RESET}"
            read -r voice < /dev/tty
            [ -z "$voice" ] && voice="longxiaochun"
            ;;
        *) voice="longxiaochun" ;;
    esac
    
    sed -i "s/selected_module:/selected_module:\n  VAD: SileroVAD\n  ASR: AliyunStreamASR\n  LLM: ChatGLMLLM\n  VLLM: ChatGLMVLLM\n  TTS: AliyunStreamTTS\n  Memory: nomem\n  Intent: function_call/" "$CONFIG_FILE"
    
    cat >> "$CONFIG_FILE" << EOF

TTS:
  AliyunStreamTTS:
    type: aliyun_stream
    output_dir: tmp/
    appkey: $appkey
    token: $token
    voice: $voice
    access_key_id: 你的阿里云账号access_key_id
    access_key_secret: 你的阿里云账号access_key_secret
    host: nls-gateway-cn-beijing.aliyuncs.com
    format: pcm
    sample_rate: 16000
    volume: 50
    speech_rate: 0
    pitch_rate: 0
EOF
    echo -e "${GREEN}✅ 阿里云流式CosyVoice配置完成${RESET}"
}

# 腾讯云TTS配置
config_tencent_tts() {
    echo -e "\n${CYAN}🐧 配置腾讯云智能语音交互服务${RESET}"
    echo -e "${YELLOW}需要先在腾讯云控制台开通TTS服务${RESET}"
    
    # 使用默认配置检查
    local default_appid=$(grep -A5 -B1 "TencentTTS:" "$CONFIG_FILE" 2>/dev/null | grep "appid:" | awk '{print $2}' || echo "")
    local default_secret_id=$(grep -A5 -B1 "TencentTTS:" "$CONFIG_FILE" 2>/dev/null | grep "secret_id:" | awk '{print $2}' || echo "")
    local default_secret_key=$(grep -A5 -B1 "TencentTTS:" "$CONFIG_FILE" 2>/dev/null | grep "secret_key:" | awk '{print $2}' || echo "")
    
    read -r -p "App ID ${default_appid:+[默认: $default_appid]}: " appid < /dev/tty
    appid=${appid:-$default_appid}
    
    read -r -p "Secret ID ${default_secret_id:+[默认: $default_secret_id]}: " secret_id < /dev/tty
    secret_id=${secret_id:-$default_secret_id}
    
    read -r -p "Secret Key ${default_secret_key:+[默认: $default_secret_key]}: " secret_key < /dev/tty
    secret_key=${secret_key:-$default_secret_key}
    
    echo -e "\n${CYAN}音色选择：${RESET}"
    echo "1) 101001 (女声1)"
    echo "2) 101002 (男声1)"
    echo "3) 101007 (童声)"
    echo "4) 自定义音色ID"
    
    read -r -p "选择音色 (1-4，默认1): " voice_choice < /dev/tty
    voice_choice=${voice_choice:-1}
    
    case $voice_choice in
        1) voice="101001" ;;
        2) voice="101002" ;;
        3) voice="101007" ;;
        4)
            echo -e "${CYAN}请输入自定义音色ID：${RESET}"
            read -r voice < /dev/tty
            [ -z "$voice" ] && voice="101001"
            ;;
        *) voice="101001" ;;
    esac
    
    sed -i "s/selected_module:/selected_module:\n  VAD: SileroVAD\n  ASR: AliyunStreamASR\n  LLM: ChatGLMLLM\n  VLLM: ChatGLMVLLM\n  TTS: TencentTTS\n  Memory: nomem\n  Intent: function_call/" "$CONFIG_FILE"
    
    cat >> "$CONFIG_FILE" << EOF

TTS:
  TencentTTS:
    type: tencent
    output_dir: tmp/
    appid: $appid
    secret_id: $secret_id
    secret_key: $secret_key
    region: ap-guangzhou
    voice: $voice
EOF
    echo -e "${GREEN}✅ 腾讯云TTS配置完成${RESET}"
}

# 302AI TTS配置
config_tts_302ai() {
    echo -e "\n${CYAN}💰 配置302AI语音合成服务${RESET}"
    echo -e "${YELLOW}302.ai提供高性价比的TTS服务${RESET}"
    
    # 使用默认配置检查
    local default_token=$(grep -A5 -B1 "TTS302AI:" "$CONFIG_FILE" 2>/dev/null | grep "access_token:" | awk '{print $2}' || echo "")
    
    read -r -p "302AI API Key ${default_token:+[默认: $default_token]}: " access_token < /dev/tty
    access_token=${access_token:-$default_token}
    
    echo -e "\n${CYAN}音色选择：${RESET}"
    echo "1) zh_female_wanwanxiaohe_moon_bigtts (湾湾小何音色)"
    echo "2) zh_male_gaoshengmingxing_moon_bigtts (男声)"
    echo "3) zh_female_yingyingyuwen_moon_bigtts (女声)"
    
    read -r -p "选择音色 (1-3，默认1): " voice_choice < /dev/tty
    voice_choice=${voice_choice:-1}
    
    case $voice_choice in
        1) voice="zh_female_wanwanxiaohe_moon_bigtts" ;;
        2) voice="zh_male_gaoshengmingxing_moon_bigtts" ;;
        3) voice="zh_female_yingyingyuwen_moon_bigtts" ;;
        *) voice="zh_female_wanwanxiaohe_moon_bigtts" ;;
    esac
    
    sed -i "s/selected_module:/selected_module:\n  VAD: SileroVAD\n  ASR: AliyunStreamASR\n  LLM: ChatGLMLLM\n  VLLM: ChatGLMVLLM\n  TTS: TTS302AI\n  Memory: nomem\n  Intent: function_call/" "$CONFIG_FILE"
    
    cat >> "$CONFIG_FILE" << EOF

TTS:
  TTS302AI:
    type: doubao
    api_url: https://api.302ai.cn/doubao/tts_hd
    authorization: "Bearer "
    voice: "$voice"
    output_dir: tmp/
    access_token: "$access_token"
EOF
    echo -e "${GREEN}✅ 302AI TTS配置完成${RESET}"
}

# 机智云TTS配置
config_gizwits_tts() {
    echo -e "\n${CYAN}📱 配置机智云TTS服务${RESET}"
    echo -e "${YELLOW}基于火山引擎的TTS服务${RESET}"
    
    # 使用默认配置检查
    local default_token=$(grep -A5 -B1 "GizwitsTTS:" "$CONFIG_FILE" 2>/dev/null | grep "access_token:" | awk '{print $2}' || echo "")
    
    read -r -p "机智云API Key ${default_token:+[默认: $default_token]}: " access_token < /dev/tty
    access_token=${access_token:-$default_token}
    
    echo -e "\n${CYAN}音色选择：${RESET}"
    echo "1) zh_female_wanwanxiaohe_moon_bigtts (湾湾小何音色)"
    echo "2) zh_male_gaoshengmingxing_moon_bigtts (男声)"
    echo "3) zh_female_yingyingyuwen_moon_bigtts (女声)"
    
    read -r -p "选择音色 (1-3，默认1): " voice_choice < /dev/tty
    voice_choice=${voice_choice:-1}
    
    case $voice_choice in
        1) voice="zh_female_wanwanxiaohe_moon_bigtts" ;;
        2) voice="zh_male_gaoshengmingxing_moon_bigtts" ;;
        3) voice="zh_female_yingyingyuwen_moon_bigtts" ;;
        *) voice="zh_female_wanwanxiaohe_moon_bigtts" ;;
    esac
    
    sed -i "s/selected_module:/selected_module:\n  VAD: SileroVAD\n  ASR: AliyunStreamASR\n  LLM: ChatGLMLLM\n  VLLM: ChatGLMVLLM\n  TTS: GizwitsTTS\n  Memory: nomem\n  Intent: function_call/" "$CONFIG_FILE"
    
    cat >> "$CONFIG_FILE" << EOF

TTS:
  GizwitsTTS:
    type: doubao
    api_url: https://bytedance.gizwitsapi.com/api/v1/tts
    authorization: "Bearer "
    voice: "$voice"
    output_dir: tmp/
    access_token: "$access_token"
EOF
    echo -e "${GREEN}✅ 机智云TTS配置完成${RESET}"
}

# 阿里百炼TTS配置
config_alibl_tts() {
    echo -e "\n${CYAN}🧠 配置阿里百炼CosyVoice流式TTS${RESET}"
    echo -e "${YELLOW}阿里百炼CosyVoice大模型流式文本语音合成${RESET}"
    
    # 使用默认配置检查
    local default_api_key=$(grep -A5 -B1 "AliBLTTS:" "$CONFIG_FILE" 2>/dev/null | grep "api_key:" | awk '{print $2}' || echo "")
    local default_model=$(grep -A5 -B1 "AliBLTTS:" "$CONFIG_FILE" 2>/dev/null | grep "model:" | awk '{print $2}' || echo "cosyvoice-v2")
    local default_voice=$(grep -A5 -B1 "AliBLTTS:" "$CONFIG_FILE" 2>/dev/null | grep "voice:" | awk '{print $2}' || echo "longcheng_v2")
    
    read -r -p "API Key ${default_api_key:+[默认: $default_api_key]}: " api_key < /dev/tty
    api_key=${api_key:-$default_api_key}
    
    echo -e "\n${CYAN}模型选择：${RESET}"
    echo "1) cosyvoice-v2 (CosyVoice v2，推荐)"
    echo "2) cosyvoice-v3 (CosyVoice v3)"
    
    read -r -p "选择模型 (1-2，默认1): " model_choice < /dev/tty
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="cosyvoice-v2" ;;
        2) model="cosyvoice-v3" ;;
        *) model="cosyvoice-v2" ;;
    esac
    
    echo -e "\n${CYAN}音色选择：${RESET}"
    echo "1) longcheng_v2 (龙城音色)"
    echo "2) longxiaochun_v2 (龙晓春音色)"
    echo "3) 自定义音色"
    
    read -r -p "选择音色 (1-3，默认1): " voice_choice < /dev/tty
    voice_choice=${voice_choice:-1}
    
    case $voice_choice in
        1) voice="longcheng_v2" ;;
        2) voice="longxiaochun_v2" ;;
        3)
            echo -e "${CYAN}请输入自定义音色：${RESET}"
            read -r voice < /dev/tty
            [ -z "$voice" ] && voice="longcheng_v2"
            ;;
        *) voice="longcheng_v2" ;;
    esac
    
    sed -i "s/selected_module:/selected_module:\n  VAD: SileroVAD\n  ASR: AliyunStreamASR\n  LLM: ChatGLMLLM\n  VLLM: ChatGLMVLLM\n  TTS: AliBLTTS\n  Memory: nomem\n  Intent: function_call/" "$CONFIG_FILE"
    
    cat >> "$CONFIG_FILE" << EOF

TTS:
  AliBLTTS:
    type: alibl_stream
    api_key: $api_key
    model: "$model"
    voice: "$voice"
    output_dir: tmp/
    format: pcm
    sample_rate: 24000
    volume: 50
    rate: 1
    pitch: 1
EOF
    echo -e "${GREEN}✅ 阿里百炼CosyVoice配置完成${RESET}"
}

# 自定义TTS配置
config_custom_tts() {
    echo -e "\n${CYAN}🔧 配置自定义TTS接口服务${RESET}"
    echo -e "${YELLOW}可接入众多TTS服务，如KokoroTTS等${RESET}"
    
    echo -e "${CYAN}服务地址配置：${RESET}"
    read -r -p "服务地址 (默认http://127.0.0.1:8880): " url < /dev/tty
    url=${url:-http://127.0.0.1:8880}
    
    echo -e "\n${CYAN}请求配置：${RESET}"
    read -r -p "请求方法 (POST/GET，默认POST): " method < /dev/tty
    method=${method:-POST}
    
    read -r -p "语音参数 (默认zf_xiaoxiao): " voice < /dev/tty
    voice=${voice:-zf_xiaoxiao}
    
    read -r -p "语言代码 (默认z): " lang_code < /dev/tty
    lang_code=${lang_code:-z}
    
    read -r -p "语速 (默认1): " speed < /dev/tty
    speed=${speed:-1}
    
    sed -i "s/selected_module:/selected_module:\n  VAD: SileroVAD\n  ASR: AliyunStreamASR\n  LLM: ChatGLMLLM\n  VLLM: ChatGLMVLLM\n  TTS: CustomTTS\n  Memory: nomem\n  Intent: function_call/" "$CONFIG_FILE"
    
    cat >> "$CONFIG_FILE" << EOF

TTS:
  CustomTTS:
    type: custom
    method: $method
    url: "$url/v1/audio/speech"
    params:
      input: "{prompt_text}"
      response_format: "mp3"
      download_format: "mp3"
      voice: "$voice"
      lang_code: "$lang_code"
      return_download_link: true
      speed: $speed
      stream: false
    headers:
      # Authorization: Bearer xxxx
    format: mp3
    output_dir: tmp/
EOF
    echo -e "${GREEN}✅ 自定义TTS配置完成${RESET}"
    echo -e "${YELLOW}💡 提示：请确保自定义TTS服务正常运行${RESET}"
}

# LinkerAI TTS配置
config_linkerai_tts() {
    echo -e "\n${CYAN}🔗 配置LinkerAI TTS服务${RESET}"
    echo -e "${YELLOW}支持声音克隆的TTS服务${RESET}"
    
    # 使用默认配置检查
    local default_token=$(grep -A5 -B1 "LinkeraiTTS:" "$CONFIG_FILE" 2>/dev/null | grep "access_token:" | awk '{print $2}' || echo "U4YdYXVfpwWnk2t5Gp822zWPCuORyeJL")
    local default_voice=$(grep -A5 -B1 "LinkeraiTTS:" "$CONFIG_FILE" 2>/dev/null | grep "voice:" | awk '{print $2}' || echo "OUeAo1mhq6IBExi")
    
    echo -e "${CYAN}Linker AI配置：${RESET}"
    echo -e "${YELLOW}默认token供测试使用，商业用途请申请正式token${RESET}"
    
    read -r -p "Access Token ${default_token:+[默认: $default_token]}: " access_token < /dev/tty
    access_token=${access_token:-$default_token}
    
    echo -e "\n${CYAN}音色选择：${RESET}"
    echo "1) OUeAo1mhq6IBExi (默认音色)"
    echo "2) 自定义音色"
    
    read -r -p "选择音色 (1-2，默认1): " voice_choice < /dev/tty
    voice_choice=${voice_choice:-1}
    
    case $voice_choice in
        1) voice="OUeAo1mhq6IBExi" ;;
        2)
            echo -e "${CYAN}请输入自定义音色ID：${RESET}"
            read -r voice < /dev/tty
            [ -z "$voice" ] && voice="OUeAo1mhq6IBExi"
            ;;
        *) voice="OUeAo1mhq6IBExi" ;;
    esac
    
    sed -i "s/selected_module:/selected_module:\n  VAD: SileroVAD\n  ASR: AliyunStreamASR\n  LLM: ChatGLMLLM\n  VLLM: ChatGLMVLLM\n  TTS: LinkeraiTTS\n  Memory: nomem\n  Intent: function_call/" "$CONFIG_FILE"
    
    cat >> "$CONFIG_FILE" << EOF

TTS:
  LinkeraiTTS:
    type: linkerai
    api_url: https://tts.linkerai.cn/tts
    audio_format: "pcm"
    access_token: "$access_token"
    voice: "$voice"
    output_dir: tmp/
EOF
    echo -e "${GREEN}✅ LinkerAI TTS配置完成${RESET}"
}

# 百度飞桨TTS配置
config_paddle_speech_tts() {
    echo -e "\n${CYAN}🦆 配置百度飞桨PaddleSpeech本地TTS${RESET}"
    echo -e "${YELLOW}支持本地离线部署的TTS服务${RESET}"
    
    echo -e "${CYAN}PaddleSpeech服务配置：${RESET}"
    read -r -p "协议 (websocket/http，默认websocket): " protocol < /dev/tty
    protocol=${protocol:-websocket}
    
    read -r -p "服务地址 (默认ws://127.0.0.1:8092): " url < /dev/tty
    url=${url:-ws://127.0.0.1:8092}
    
    echo -e "\n${CYAN}音频参数：${RESET}"
    echo "1) 24000 (高音质，推荐)"
    echo "2) 16000 (标准音质)"
    echo "3) 8000 (低音质)"
    
    read -r -p "采样率 (1-3，默认1): " sample_choice < /dev/tty
    sample_choice=${sample_choice:-1}
    
    case $sample_choice in
        1) sample_rate=24000 ;;
        2) sample_rate=16000 ;;
        3) sample_rate=8000 ;;
        *) sample_rate=24000 ;;
    esac
    
    read -r -p "语速 (默认1.0): " speed < /dev/tty
    speed=${speed:-1.0}
    
    read -r -p "音量 (默认1.0): " volume < /dev/tty
    volume=${volume:-1.0}
    
    sed -i "s/selected_module:/selected_module:\n  VAD: SileroVAD\n  ASR: AliyunStreamASR\n  LLM: ChatGLMLLM\n  VLLM: ChatGLMVLLM\n  TTS: PaddleSpeechTTS\n  Memory: nomem\n  Intent: function_call/" "$CONFIG_FILE"
    
    cat >> "$CONFIG_FILE" << EOF

TTS:
  PaddleSpeechTTS:
    type: paddle_speech
    protocol: $protocol
    url: $url/paddlespeech/tts/streaming
    spk_id: 0
    sample_rate: $sample_rate
    speed: $speed
    volume: $volume
    save_path: 
EOF
    echo -e "${GREEN}✅ 百度飞桨PaddleSpeech配置完成${RESET}"
    echo -e "${YELLOW}💡 提示：请先部署PaddleSpeech服务${RESET}"
}

# Index Stream TTS配置
config_index_stream_tts() {
    echo -e "\n${CYAN}📊 配置Index-TTS-vLLM流式TTS${RESET}"
    echo -e "${YELLOW}基于Index-TTS-vLLM项目的TTS接口服务${RESET}"
    
    echo -e "${CYAN}Index-TTS配置：${RESET}"
    read -r -p "服务地址 (默认http://127.0.0.1:11996): " api_url < /dev/tty
    api_url=${api_url:-http://127.0.0.1:11996}
    
    read -r -p "音频格式 (默认pcm): " audio_format < /dev/tty
    audio_format=${audio_format:-pcm}
    
    echo -e "\n${CYAN}音色选择：${RESET}"
    echo "1) jay_klee (默认音色)"
    echo "2) 自定义音色"
    
    read -r -p "选择音色 (1-2，默认1): " voice_choice < /dev/tty
    voice_choice=${voice_choice:-1}
    
    case $voice_choice in
        1) voice="jay_klee" ;;
        2)
            echo -e "${CYAN}请输入自定义音色：${RESET}"
            read -r voice < /dev/tty
            [ -z "$voice" ] && voice="jay_klee"
            ;;
        *) voice="jay_klee" ;;
    esac
    
    sed -i "s/selected_module:/selected_module:\n  VAD: SileroVAD\n  ASR: AliyunStreamASR\n  LLM: ChatGLMLLM\n  VLLM: ChatGLMVLLM\n  TTS: IndexStreamTTS\n  Memory: nomem\n  Intent: function_call/" "$CONFIG_FILE"
    
    cat >> "$CONFIG_FILE" << EOF

TTS:
  IndexStreamTTS:
    type: index_stream
    api_url: $api_url/tts
    audio_format: "$audio_format"
    voice: "$voice"
    output_dir: tmp/
EOF
    echo -e "${GREEN}✅ Index-TTS配置完成${RESET}"
    echo -e "${YELLOW}💡 提示：请先部署Index-TTS-vLLM服务${RESET}"
}

# ACGN TTS配置
config_acgn_tts() {
    echo -e "\n${CYAN}🎭 配置ACGN角色TTS服务${RESET}"
    echo -e "${YELLOW}专为ACGN角色设计的TTS服务${RESET}"
    
    # 使用默认配置检查
    local default_token=$(grep -A5 -B1 "ACGNTTS:" "$CONFIG_FILE" 2>/dev/null | grep "token:" | awk '{print $2}' || echo "")
    local default_voice=$(grep -A5 -B1 "ACGNTTS:" "$CONFIG_FILE" 2>/dev/null | grep "voice_id:" | awk '{print $2}' || echo "1695")
    
    echo -e "${CYAN}ACGN TTS配置：${RESET}"
    echo -e "${YELLOW}角色ID获取地址请咨询网站管理者${RESET}"
    
    read -r -p "Token ${default_token:+[默认: $default_token]}: " token < /dev/tty
    token=${token:-$default_token}
    
    read -r -p "角色ID ${default_voice:+[默认: $default_voice]}: " voice_id < /dev/tty
    voice_id=${voice_id:-$default_voice}
    
    echo -e "\n${CYAN}参数配置：${RESET}"
    read -r -p "语速 (默认1): " speed_factor < /dev/tty
    speed_factor=${speed_factor:-1}
    
    read -r -p "语调 (默认0): " pitch_factor < /dev/tty
    pitch_factor=${pitch_factor:-0}
    
    read -r -p "音量 (默认0): " volume_change_dB < /dev/tty
    volume_change_dB=${volume_change_dB:-0}
    
    echo -e "\n${CYAN}语言设置：${RESET}"
    read -r -p "目标语言 (默认ZH): " to_lang < /dev/tty
    to_lang=${to_lang:-ZH}
    
    read -r -p "情感 (默认1): " emotion < /dev/tty
    emotion=${emotion:-1}
    
    sed -i "s/selected_module:/selected_module:\n  VAD: SileroVAD\n  ASR: AliyunStreamASR\n  LLM: ChatGLMLLM\n  VLLM: ChatGLMVLLM\n  TTS: ACGNTTS\n  Memory: nomem\n  Intent: function_call/" "$CONFIG_FILE"
    
    cat >> "$CONFIG_FILE" << EOF

TTS:
  ACGNTTS:
    type: ttson
    token: $token
    voice_id: $voice_id
    speed_factor: $speed_factor
    pitch_factor: $pitch_factor
    volume_change_dB: $volume_change_dB
    to_lang: $to_lang
    url: https://u95167-bd74-2aef8085.westx.seetacloud.com:8443/flashsummary/tts?token=
    format: mp3
    output_dir: tmp/
    emotion: $emotion
EOF
    echo -e "${GREEN}✅ ACGN TTS配置完成${RESET}"
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
    # 移除重复下载，只在必要的时候调用
    if [ "$CONFIG_DOWNLOAD_NEEDED" = "true" ]; then
        download_files "true"
    else
        echo -e "${GREEN}✅ 使用现有配置文件，跳过下载${RESET}"
    fi
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
    
read -r -p "按回车键返回主菜单..." < /dev/tty
    return  
}

# 重新部署（完全删除并重新开始）
redeploy_server() {
    echo -e "${RED}⚠️ 警告：重新部署将完全删除现有服务器数据和配置！${RESET}"
    echo -e "${YELLOW}这将删除：${RESET}"
    echo "  - 所有Docker容器和镜像"
    echo "  - 服务器目录和配置文件"
    echo "  - 所有用户数据"
    
read -r -p "确认继续？(输入 'YES' 确认，其他任意键取消): " confirm < /dev/tty
    if [ "$confirm" != "YES" ]; then
        echo -e "${CYAN}✅ 已取消重新部署${RESET}"
read -r -p "按回车键返回主菜单..." < /dev/tty
        return  
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
    
read -r -p "确认继续更新？(y/n，默认y): " confirm < /dev/tty
    confirm=${confirm:-y}
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${CYAN}✅ 已取消更新${RESET}"
read -r -p "按回车键返回主菜单..." < /dev/tty
        return 
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
    
read -r -p "按回车键返回主菜单..." < /dev/tty
    return  
}

# 仅修改配置文件
config_only() {
    echo -e "${CYAN}⚙️ 进入配置文件修改模式${RESET}"
    echo -e "${YELLOW}这将：${RESET}"
    echo "1. 保留现有的服务器文件和容器"
    echo "2. 只修改配置文件"
    echo "3. 重启服务以应用新配置"
    
read -r -p "确认继续？(y/n，默认y): " confirm < /dev/tty
    confirm=${confirm:-y}
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${CYAN}✅ 已取消配置修改${RESET}"
read -r -p "按回车键返回主菜单..." < /dev/tty
        return  
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
    
read -r -p "按回车键返回主菜单..." < /dev/tty
    return 
}

# 连接信息展示
show_connection_info() {
  # 等待Docker服务完全启动
  echo -e "\n${YELLOW}⏳ 正在测试中预计10秒完成...${RESET}"
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
  echo -e "${GREEN}Websocket接口（内网）：${BOLD}ws://$INTERNAL_IP:8000/xiaozhi/v1/${RESET}"
  echo -e "${GREEN}Websocket接口（公网）：${BOLD}ws://$EXTERNAL_IP:8000/xiaozhi/v1/${RESET}"
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
    
read -r -p "确认开始测试？(y/n，默认y): " confirm < /dev/tty
    confirm=${confirm:-y}
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${CYAN}✅ 已取消测试${RESET}"
read -r -p "按回车键返回主菜单..." < /dev/tty
        return  
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
    
read -r -p "按回车键返回主菜单..." < /dev/tty
    return 
}

# 测试服务器端口（新的详细端口测试）
test_ports() {
    echo -e "${CYAN}🧪 测试服务器端口连通性${RESET}"
    echo -e "${YELLOW}这将进行详细的端口检查：${RESET}"
    echo "1. OTA端口(8003)HTTP连接测试"
    echo "2. WebSocket端口(8000)TCP连接测试"
    echo "3. 详细诊断信息显示"
    echo "4. 故障排除建议"
    
read -r -p "确认开始端口测试？(y/n，默认y): " confirm < /dev/tty
    confirm=${confirm:-y}
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${CYAN}✅ 已取消测试${RESET}"
read -r -p "按回车键返回主菜单..." < /dev/tty
        return
    fi
    
    # 检查Docker容器状态
    echo -e "\n${YELLOW}🔍 检查Docker容器状态${RESET}"
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${GREEN}✅ 容器 $CONTAINER_NAME 正在运行${RESET}"
    else
        echo -e "${RED}❌ 容器 $CONTAINER_NAME 未运行${RESET}"
        echo -e "${YELLOW}💡 请先启动服务器再进行端口测试${RESET}"
read -r -p "按回车键返回主菜单..." < /dev/tty
        return
    fi
    
    # 调用连接信息展示函数
    show_connection_info
    
read -r -p "按回车键返回主菜单..." < /dev/tty
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
read -r -p "按回车键继续..." < /dev/tty < /dev/tty
        return
    fi
    
    # 检查Docker是否安装
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker未安装${RESET}"
read -r -p "按回车键返回主菜单..." < /dev/tty
        return
    fi
    
    # 检查容器是否存在
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${YELLOW}⚠️ 未找到小智服务器容器${RESET}"
read -r -p "按回车键返回主菜单..." < /dev/tty
        return
    fi
    
    echo -e "${CYAN}选择日志查看方式：${RESET}"
    echo "1) 查看最新50行日志"
    echo "2) 查看最新100行日志"
    echo "3) 查看全部日志"
    echo "4) 实时跟踪日志 (按Ctrl+C退出)"
    echo "5) 查看特定时间段日志"
    echo "0) 返回主菜单"
    
read -r -p "请选择日志查看方式 (0-5): " log_choice < /dev/tty
    
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
read -r -p "开始时间 (YYYY-MM-DD HH:MM:SS): " start_time < /dev/tty
read -r -p "结束时间 (YYYY-MM-DD HH:MM:SS): " end_time < /dev/tty
            
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
    
read -r -p "按回车键返回主菜单..." < /dev/tty
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
    
read -r -p "确认完全删除？(输入 'DELETE' 确认，其他任意键取消): " confirm < /dev/tty
    if [ "$confirm" != "DELETE" ]; then
        echo -e "${CYAN}✅ 已取消删除操作${RESET}"
read -r -p "按回车键返回主菜单..." < /dev/tty
        return  
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
    
read -r -p "按回车键返回主菜单..." < /dev/tty
    return 
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
        
read -r -p "❓ 是否强制执行？(Y/N，默认N): " choice < /dev/tty
        choice=${choice:-N}
        
        if [[ "$choice" != "Y" && "$choice" != "y" ]]; then
            echo -e "${GREEN}👋 已取消执行，脚本退出${RESET}"
            exit 0
        fi
    fi
    
    echo -e "${GREEN}✅ 系统检测通过，继续执行脚本...${RESET}"
}

# ========================= Docker操作工具菜单 =========================

docker_operation_tool_menu() {
    while true; do
        clear
        echo -e "\n${PURPLE}==================================================${RESET}"
        echo -e "${CYAN}🐳 Docker操作工具菜单 🐳${RESET}"
        echo -e "${PURPLE}==================================================${RESET}"
        
        # 显示Docker状态
        if command -v docker &> /dev/null; then
            echo -e "${GREEN}🐳 Docker状态: 已安装${RESET}"
            docker_version=$(docker --version 2>/dev/null | head -n1 || echo "未知版本")
            echo -e "${CYAN}📋 版本信息: $docker_version${RESET}"
            
            # 检查容器状态
            if docker ps | grep -q "$CONTAINER_NAME"; then
                echo -e "${GREEN}🟢 小智服务器容器: 运行中${RESET}"
            else
                echo -e "${YELLOW}🟡 小智服务器容器: 未运行${RESET}"
            fi
        else
            echo -e "${RED}❌ Docker状态: 未安装${RESET}"
        fi
        
        echo -e "\n${WHITE_RED}可用操作:${RESET}"
        echo "1) Docker服务管理 (启动/停止/重启/查看状态)"
        echo "2) Docker镜像管理 (查看/清理/重新拉取镜像)"
        echo "3) Docker容器管理 (查看/清理/重置容器)"
        echo "4) Docker系统信息 (版本/资源使用情况)"
        echo "5) Docker深度清理 (清理所有Docker资源)"
        echo "6) Docker网络和端口管理"
        echo "7) Docker日志管理 (查看/实时跟踪)"
        echo "0) 返回主菜单"
        echo -e "${PURPLE}==================================================${RESET}"
        
        read -r -p "请选择Docker操作 (0-7): " docker_tool_choice < /dev/tty
        
        case $docker_tool_choice in
            1)
                docker_service_management
                ;;
            2)
                docker_image_management
                ;;
            3)
                docker_container_management_advanced
                ;;
            4)
                docker_system_info
                ;;
            5)
                docker_deep_cleanup
                ;;
            6)
                docker_network_port_management
                ;;
            7)
                docker_log_management
                ;;
            0)
                echo -e "${CYAN}🔙 返回主菜单${RESET}"
                return 0
                ;;
            *)
                echo -e "${RED}❌ 无效选项，请输入0-7${RESET}"
                sleep 2
                ;;
        esac
    done
}

# Docker服务管理
docker_service_management() {
    while true; do
        clear
        echo -e "\n${PURPLE}==================================================${RESET}"
        echo -e "${CYAN}🔧 Docker服务管理 🔧${RESET}"
        echo -e "${PURPLE}==================================================${RESET}"
        
        echo "1) 启动小智服务器服务"
        echo "2) 停止小智服务器服务"
        echo "3) 重启小智服务器服务"
        echo "4) 查看服务状态"
        echo "5) 查看服务资源使用情况"
        echo "0) 返回Docker工具主页"
        
        read -r -p "请选择操作 (0-5): " service_choice < /dev/tty
        
        case $service_choice in
            1)
                echo -e "\n${GREEN}🚀 启动小智服务器服务...${RESET}"
                if [ -d "$MAIN_DIR" ] && [ -f "$MAIN_DIR/docker-compose.yml" ]; then
                    cd "$MAIN_DIR" || return 1
                    if docker compose up -d; then
                        sleep 5
                        if docker ps | grep -q "$CONTAINER_NAME"; then
                            echo -e "${GREEN}✅ 服务启动成功${RESET}"
                            docker_service_status_display
                        else
                            echo -e "${RED}❌ 服务启动失败${RESET}"
                        fi
                    else
                        echo -e "${RED}❌ Docker Compose启动失败${RESET}"
                    fi
                else
                    echo -e "${RED}❌ 服务器目录或配置文件不存在${RESET}"
                fi
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            2)
                echo -e "\n${RED}🛑 停止小智服务器服务...${RESET}"
                if docker ps | grep -q "$CONTAINER_NAME"; then
                    docker stop "$CONTAINER_NAME"
                    echo -e "${GREEN}✅ 服务已停止${RESET}"
                else
                    echo -e "${YELLOW}⚠️ 服务未运行${RESET}"
                fi
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            3)
                echo -e "\n${CYAN}🔄 重启小智服务器服务...${RESET}"
                if docker ps | grep -q "$CONTAINER_NAME"; then
                    docker restart "$CONTAINER_NAME"
                    sleep 5
                    if docker ps | grep -q "$CONTAINER_NAME"; then
                        echo -e "${GREEN}✅ 服务重启成功${RESET}"
                        docker_service_status_display
                    else
                        echo -e "${RED}❌ 服务重启失败${RESET}"
                    fi
                else
                    echo -e "${YELLOW}⚠️ 服务未运行，无法重启${RESET}"
                fi
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            4)
                docker_service_status_display
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            5)
                if docker ps | grep -q "$CONTAINER_NAME"; then
                    echo -e "\n${CYAN}📊 服务资源使用情况:${RESET}"
                    docker stats "$CONTAINER_NAME" --no-stream
                else
                    echo -e "${YELLOW}⚠️ 服务未运行${RESET}"
                fi
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            0)
                echo -e "${CYAN}🔙 返回Docker工具主页${RESET}"
                return 0
                ;;
            *)
                echo -e "${RED}❌ 无效选项${RESET}"
                sleep 1
                ;;
        esac
    done
}

# Docker镜像管理
docker_image_management() {
    while true; do
        clear
        echo -e "\n${PURPLE}==================================================${RESET}"
        echo -e "${CYAN}🖼️ Docker镜像管理 🖼️${RESET}"
        echo -e "${PURPLE}==================================================${RESET}"
        
        echo "1) 查看所有镜像"
        echo "2) 查看小智服务器镜像信息"
        echo "3) 清理未使用的镜像"
        echo "4) 强制清理所有镜像"
        echo "5) 重新拉取小智服务器镜像"
        echo "0) 返回Docker工具主页"
        
        read -r -p "请选择操作 (0-5): " image_choice < /dev/tty
        
        case $image_choice in
            1)
                echo -e "\n${CYAN}📋 所有Docker镜像:${RESET}"
                docker images
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            2)
                echo -e "\n${CYAN}📋 小智服务器镜像信息:${RESET}"
                if docker images | grep -q "xiaozhi"; then
                    docker images | grep "xiaozhi"
                else
                    echo -e "${YELLOW}⚠️ 未找到小智服务器相关镜像${RESET}"
                fi
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            3)
                echo -e "\n${YELLOW}🧹 清理未使用的镜像...${RESET}"
                read -r -p "确认清理未使用的镜像？(y/N): " confirm < /dev/tty
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    docker image prune -f
                    echo -e "${GREEN}✅ 清理完成${RESET}"
                else
                    echo -e "${CYAN}🔙 已取消清理${RESET}"
                fi
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            4)
                echo -e "\n${RED}⚠️ 强制清理所有镜像${RESET}"
                echo -e "${RED}⚠️ 此操作将删除所有Docker镜像，危险！${RESET}"
                read -r -p "确认删除所有镜像？(输入YES确认): " confirm < /dev/tty
                if [ "$confirm" = "YES" ]; then
                    docker rmi $(docker images -q) -f 2>/dev/null || true
                    echo -e "${GREEN}✅ 所有镜像已清理${RESET}"
                else
                    echo -e "${CYAN}🔙 已取消清理${RESET}"
                fi
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            5)
                echo -e "\n${CYAN}📥 重新拉取小智服务器镜像...${RESET}"
                if [ -f "$MAIN_DIR/docker-compose.yml" ]; then
                    cd "$MAIN_DIR"
                    docker compose pull
                    echo -e "${GREEN}✅ 镜像拉取完成${RESET}"
                else
                    echo -e "${RED}❌ 未找到docker-compose.yml文件${RESET}"
                fi
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            0)
                echo -e "${CYAN}🔙 返回Docker工具主页${RESET}"
                return 0
                ;;
            *)
                echo -e "${RED}❌ 无效选项${RESET}"
                sleep 1
                ;;
        esac
    done
}

# Docker容器管理(高级)
docker_container_management_advanced() {
    while true; do
        clear
        echo -e "\n${PURPLE}==================================================${RESET}"
        echo -e "${CYAN}📦 Docker容器管理 (高级) 📦${RESET}"
        echo -e "${PURPLE}==================================================${RESET}"
        
        echo "1) 查看所有容器"
        echo "2) 查看小智服务器容器详情"
        echo "3) 进入小智服务器容器"
        echo "4) 清理已停止的容器"
        echo "5) 重置小智服务器容器"
        echo "0) 返回Docker工具主页"
        
        read -r -p "请选择操作 (0-5): " container_choice < /dev/tty
        
        case $container_choice in
            1)
                echo -e "\n${CYAN}📋 所有Docker容器:${RESET}"
                docker ps -a
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            2)
                echo -e "\n${CYAN}📋 小智服务器容器详情:${RESET}"
                if docker ps -a | grep -q "$CONTAINER_NAME"; then
                    docker inspect "$CONTAINER_NAME"
                else
                    echo -e "${YELLOW}⚠️ 未找到小智服务器容器${RESET}"
                fi
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            3)
                if docker ps | grep -q "$CONTAINER_NAME"; then
                    echo -e "\n${CYAN}🔗 进入容器...${RESET}"
                    echo -e "${YELLOW}⚠️ 使用 'exit' 命令退出容器${RESET}"
                    docker exec -it "$CONTAINER_NAME" /bin/bash
                else
                    echo -e "${RED}❌ 容器未运行${RESET}"
                fi
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            4)
                echo -e "\n${YELLOW}🧹 清理已停止的容器...${RESET}"
                read -r -p "确认清理？(y/N): " confirm < /dev/tty
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    docker container prune -f
                    echo -e "${GREEN}✅ 清理完成${RESET}"
                else
                    echo -e "${CYAN}🔙 已取消清理${RESET}"
                fi
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            5)
                echo -e "\n${RED}⚠️ 重置小智服务器容器${RESET}"
                read -r -p "确认重置？(y/N): " confirm < /dev/tty
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    if docker ps | grep -q "$CONTAINER_NAME"; then
                        docker stop "$CONTAINER_NAME"
                    fi
                    if docker ps -a | grep -q "$CONTAINER_NAME"; then
                        docker rm "$CONTAINER_NAME"
                    fi
                    echo -e "${GREEN}✅ 容器已重置${RESET}"
                else
                    echo -e "${CYAN}🔙 已取消重置${RESET}"
                fi
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            0)
                echo -e "${CYAN}🔙 返回Docker工具主页${RESET}"
                return 0
                ;;
            *)
                echo -e "${RED}❌ 无效选项${RESET}"
                sleep 1
                ;;
        esac
    done
}

# Docker系统信息
docker_system_info() {
    while true; do
        clear
        echo -e "\n${PURPLE}==================================================${RESET}"
        echo -e "${CYAN}ℹ️ Docker系统信息 ℹ️${RESET}"
        echo -e "${PURPLE}==================================================${RESET}"
        
        echo "1) 查看Docker版本信息"
        echo "2) 查看Docker系统信息"
        echo "3) 查看Docker磁盘使用情况"
        echo "4) 查看Docker事件信息"
        echo "0) 返回Docker工具主页"
        
        read -r -p "请选择操作 (0-4): " info_choice < /dev/tty
        
        case $info_choice in
            1)
                echo -e "\n${CYAN}🐳 Docker版本信息:${RESET}"
                docker version
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            2)
                echo -e "\n${CYAN}📊 Docker系统信息:${RESET}"
                docker system info
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            3)
                echo -e "\n${CYAN}💾 Docker磁盘使用情况:${RESET}"
                docker system df
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            4)
                echo -e "\n${CYAN}🔍 Docker事件信息:${RESET}"
                docker system events --since "1h" --until "0s" 2>/dev/null | head -20 || echo "无法获取事件信息"
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            0)
                echo -e "${CYAN}🔙 返回Docker工具主页${RESET}"
                return 0
                ;;
            *)
                echo -e "${RED}❌ 无效选项${RESET}"
                sleep 1
                ;;
        esac
    done
}

# Docker深度清理
docker_deep_cleanup() {
    while true; do
        clear
        echo -e "\n${PURPLE}==================================================${RESET}"
        echo -e "${RED}⚠️ Docker深度清理 ⚠️${RESET}"
        echo -e "${PURPLE}==================================================${RESET}"
        
        echo -e "${RED}⚠️ 警告：此操作将清理所有Docker资源${RESET}"
        echo -e "${RED}⚠️ 包括：容器、镜像、卷、网络、构建缓存${RESET}"
        echo -e "${RED}⚠️ 此操作不可恢复！${RESET}"
        echo ""
        
        echo "1) 清理未使用的资源"
        echo "2) 清理所有未运行的容器"
        echo "3) 清理所有未使用的镜像"
        echo "4) 清理所有未使用的卷"
        echo "5) 清理所有未使用的网络"
        echo "6) 清理构建缓存"
        echo "7) 完全重置Docker (所有数据)"
        echo "0) 返回Docker工具主页"
        
        read -r -p "请选择清理操作 (0-7): " cleanup_choice < /dev/tty
        
        case $cleanup_choice in
            1)
                echo -e "\n${YELLOW}🧹 清理未使用的资源...${RESET}"
                docker system prune -f
                echo -e "${GREEN}✅ 清理完成${RESET}"
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            2)
                echo -e "\n${YELLOW}🧹 清理未运行的容器...${RESET}"
                docker container prune -f
                echo -e "${GREEN}✅ 清理完成${RESET}"
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            3)
                echo -e "\n${YELLOW}🧹 清理未使用的镜像...${RESET}"
                docker image prune -a -f
                echo -e "${GREEN}✅ 清理完成${RESET}"
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            4)
                echo -e "\n${YELLOW}🧹 清理未使用的卷...${RESET}"
                docker volume prune -f
                echo -e "${GREEN}✅ 清理完成${RESET}"
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            5)
                echo -e "\n${YELLOW}🧹 清理未使用的网络...${RESET}"
                docker network prune -f
                echo -e "${GREEN}✅ 清理完成${RESET}"
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            6)
                echo -e "\n${YELLOW}🧹 清理构建缓存...${RESET}"
                docker builder prune -f
                echo -e "${GREEN}✅ 清理完成${RESET}"
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            7)
                echo -e "\n${RED}☠️ 完全重置Docker${RESET}"
                echo -e "${RED}⚠️ 此操作将删除所有Docker数据，不可恢复！${RESET}"
                read -r -p "输入 'DELETE ALL' 确认: " confirm < /dev/tty
                if [ "$confirm" = "DELETE ALL" ]; then
                    docker system prune -a --volumes -f
                    echo -e "${GREEN}✅ Docker已完全重置${RESET}"
                else
                    echo -e "${CYAN}🔙 已取消重置${RESET}"
                fi
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            0)
                echo -e "${CYAN}🔙 返回Docker工具主页${RESET}"
                return 0
                ;;
            *)
                echo -e "${RED}❌ 无效选项${RESET}"
                sleep 1
                ;;
        esac
    done
}

# Docker网络和端口管理
docker_network_port_management() {
    while true; do
        clear
        echo -e "\n${PURPLE}==================================================${RESET}"
        echo -e "${CYAN}🌐 Docker网络和端口管理 🌐${RESET}"
        echo -e "${PURPLE}==================================================${RESET}"
        
        echo "1) 查看Docker网络"
        echo "2) 查看端口映射"
        echo "3) 检查端口占用"
        echo "4) 网络连接测试"
        echo "5) 查看容器网络详情"
        echo "0) 返回Docker工具主页"
        
        read -r -p "请选择操作 (0-5): " network_choice < /dev/tty
        
        case $network_choice in
            1)
                echo -e "\n${CYAN}🌐 Docker网络列表:${RESET}"
                docker network ls
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            2)
                echo -e "\n${CYAN}🔗 端口映射列表:${RESET}"
                docker ps --format "table {{.Names}}\t{{.Ports}}" | head -20
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            3)
                echo -e "\n${CYAN}🔍 检查端口占用:${RESET}"
                echo -e "${YELLOW}常用端口: 8000 (API), 8003 (OTA), 8080 (Web)${RESET}"
                ports=(8000 8003 8080 3000 5000)
                for port in "${ports[@]}"; do
                    if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
                        echo -e "${GREEN}✅ 端口 $port: 已被占用${RESET}"
                    else
                        echo -e "${YELLOW}⚠️ 端口 $port: 可用${RESET}"
                    fi
                done
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            4)
                echo -e "\n${CYAN}🌍 网络连接测试:${RESET}"
                if docker ps | grep -q "$CONTAINER_NAME"; then
                    echo "测试容器内部连接..."
                    docker exec "$CONTAINER_NAME" ping -c 3 8.8.8.8 2>/dev/null || echo "容器网络测试失败"
                else
                    echo -e "${YELLOW}⚠️ 容器未运行${RESET}"
                fi
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            5)
                if docker ps | grep -q "$CONTAINER_NAME"; then
                    echo -e "\n${CYAN}🔍 容器网络详情:${RESET}"
                    docker inspect "$CONTAINER_NAME" | grep -A 20 "Networks"
                else
                    echo -e "${YELLOW}⚠️ 容器未运行${RESET}"
                fi
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            0)
                echo -e "${CYAN}🔙 返回Docker工具主页${RESET}"
                return 0
                ;;
            *)
                echo -e "${RED}❌ 无效选项${RESET}"
                sleep 1
                ;;
        esac
    done
}

# Docker日志管理
docker_log_management() {
    while true; do
        clear
        echo -e "\n${PURPLE}==================================================${RESET}"
        echo -e "${CYAN}📝 Docker日志管理 📝${RESET}"
        echo -e "${PURPLE}==================================================${RESET}"
        
        echo "1) 查看最新50行日志"
        echo "2) 查看最新100行日志"
        echo "3) 查看指定时间段日志"
        echo "4) 实时跟踪日志 (Ctrl+C退出)"
        echo "5) 搜索日志关键词"
        echo "6) 导出日志到文件"
        echo "0) 返回Docker工具主页"
        
        read -r -p "请选择操作 (0-6): " log_choice < /dev/tty
        
        case $log_choice in
            1)
                echo -e "\n${CYAN}📋 最新50行日志:${RESET}"
                if docker ps | grep -q "$CONTAINER_NAME"; then
                    docker logs --tail 50 "$CONTAINER_NAME"
                else
                    echo -e "${RED}❌ 容器未运行${RESET}"
                fi
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            2)
                echo -e "\n${CYAN}📋 最新100行日志:${RESET}"
                if docker ps | grep -q "$CONTAINER_NAME"; then
                    docker logs --tail 100 "$CONTAINER_NAME"
                else
                    echo -e "${RED}❌ 容器未运行${RESET}"
                fi
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            3)
                echo -e "\n${CYAN}⏰ 指定时间段日志:${RESET}"
                read -r -p "开始时间 (格式: 2024-01-01 12:00): " start_time < /dev/tty
                read -r -p "结束时间 (格式: 2024-01-01 13:00): " end_time < /dev/tty
                if docker ps | grep -q "$CONTAINER_NAME"; then
                    docker logs --since "$start_time" --until "$end_time" "$CONTAINER_NAME" 2>/dev/null || echo "无法获取指定时间段日志"
                else
                    echo -e "${RED}❌ 容器未运行${RESET}"
                fi
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            4)
                echo -e "\n${CYAN}📡 实时日志跟踪 (按Ctrl+C退出):${RESET}"
                if docker ps | grep -q "$CONTAINER_NAME"; then
                    docker logs -f "$CONTAINER_NAME"
                else
                    echo -e "${RED}❌ 容器未运行${RESET}"
                    read -r -p "按回车键继续..." < /dev/tty
                fi
                ;;
            5)
                echo -e "\n${CYAN}🔍 搜索日志关键词:${RESET}"
                read -r -p "输入搜索关键词: " keyword < /dev/tty
                if docker ps | grep -q "$CONTAINER_NAME"; then
                    docker logs "$CONTAINER_NAME" 2>/dev/null | grep -i "$keyword" || echo "未找到匹配内容"
                else
                    echo -e "${RED}❌ 容器未运行${RESET}"
                fi
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            6)
                echo -e "\n${CYAN}💾 导出日志到文件:${RESET}"
                log_file="$HOME/xiaozhi-logs-$(date +%Y%m%d_%H%M%S).txt"
                if docker ps | grep -q "$CONTAINER_NAME"; then
                    docker logs "$CONTAINER_NAME" > "$log_file" 2>/dev/null
                    echo -e "${GREEN}✅ 日志已导出到: $log_file${RESET}"
                else
                    echo -e "${RED}❌ 容器未运行${RESET}"
                fi
                read -r -p "按回车键继续..." < /dev/tty
                ;;
            0)
                echo -e "${CYAN}🔙 返回Docker工具主页${RESET}"
                return 0
                ;;
            *)
                echo -e "${RED}❌ 无效选项${RESET}"
                sleep 1
                ;;
        esac
    done
}

# 显示服务状态详细信息
docker_service_status_display() {
    echo -e "\n${PURPLE}==================================================${RESET}"
    echo -e "${GREEN}📊 小智服务器状态详情${RESET}"
    echo -e "${PURPLE}==================================================${RESET}"
    
    if docker ps | grep -q "$CONTAINER_NAME"; then
        echo -e "${GREEN}🟢 服务状态: 运行中${RESET}"
        echo -e "\n${CYAN}📋 容器信息:${RESET}"
        docker ps --filter "name=$CONTAINER_NAME" --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"
        
        echo -e "\n${CYAN}🔗 访问地址:${RESET}"
        INTERNAL_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
        EXTERNAL_IP=$(curl -s --max-time 5 https://api.ip.sb/ip 2>/dev/null || echo "$INTERNAL_IP")
        
        echo -e "内网地址: $INTERNAL_IP"
        echo -e "公网地址: $EXTERNAL_IP"
        echo -e "${GREEN}API接口: http://$INTERNAL_IP:8000${RESET}"
        echo -e "${GREEN}OTA接口: http://$INTERNAL_IP:8003/xiaozhi/ota/${RESET}"
        echo -e "${GREEN}WebSocket: ws://$INTERNAL_IP:8000/xiaozhi/v1/${RESET}"
        
        echo -e "\n${CYAN}💻 资源使用:${RESET}"
        docker stats "$CONTAINER_NAME" --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
        
    else
        echo -e "${RED}🔴 服务状态: 未运行${RESET}"
    fi
    
    echo -e "${PURPLE}==================================================${RESET}"
}

# ========================= 系统监控工具 =========================
system_monitor_tool() {
    clear
    echo -e "\n${PURPLE}==================================================${RESET}"
    echo -e "${GREEN}🖥️ 系统监控工具 - 高科技监控仪表盘 🖥️${RESET}"
    echo -e "${PURPLE}==================================================${RESET}"
    echo -e "${YELLOW}📊 固定显示模式 - 按 R 键刷新数据 | 按 Q 返回主菜单${RESET}"
    echo -e "${CYAN}💡 提示: 数据每按R键更新一次，确保精确监控${RESET}"
    echo -e "${PURPLE}==================================================${RESET}"
    
    # 终端大小检测
    if [ "$(tput cols)" -lt 80 ] || [ "$(tput lines)" -lt 25 ]; then
        echo -e "${RED}⚠️ 检测到终端窗口太小，建议调整为至少80x25${RESET}"
        echo -e "${CYAN}当前尺寸: $(tput cols) x $(tput lines)${RESET}"
        echo -e "${YELLOW}按任意键继续...${RESET}"
        read -r
        return 0
    fi
    
    while true; do
        clear
        
        # 计算时间戳
        CURRENT_TIME=$(date "+%Y-%m-%d %H:%M:%S")
        CURRENT_UPTIME=$(uptime -p 2>/dev/null || echo "未知")
        
        # ======================= 标题栏 =======================
        echo -e "\033[1;36m╔════════════════════════════════════════════════════════════════════════════════════════╗\033[0m"
        echo -e "\033[1;36m║\033[1;32m                        🖥️  系 统 监 控 中 心  -  HACKER DASHBOARD  🖥️                      \033[1;36m║\033[0m"
        echo -e "\033[1;36m╠════════════════════════════════════════════════════════════════════════════════════════╣\033[0m"
        echo -e "\033[1;36m║\033[1;33m 当前时间: \033[1;37m$CURRENT_TIME\033[1;33m                    运行时间: \033[1;37m$CURRENT_UPTIME\033[1;36m║\033[0m"
        echo -e "\033[1;36m╚════════════════════════════════════════════════════════════════════════════════════════╝\033[0m"
        
        # ======================= 系统信息 =======================
        if command -v hostnamectl &> /dev/null; then
            SYSTEM_INFO=$(hostnamectl | grep -E "Static hostname|Operating System|Kernel|Architecture" | head -4)
        else
            SYSTEM_INFO=$(uname -a)
        fi
        
        # ======================= CPU信息 =======================
        CPU_INFO=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^ *//' || echo "CPU信息不可用")
        CPU_CORES=$(nproc --all 2>/dev/null || echo "0")
        CPU_LOAD=$(uptime | awk -F'load average:' '{print $2}' | sed 's/,/ /g' || echo "0.00 0.00 0.00")
        
        # CPU温度检测（多方式检测）
        CPU_TEMP=""
        if [ -f "/sys/class/thermal/thermal_zone0/temp" ]; then
            TEMP_VALUE=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
            if [ -n "$TEMP_VALUE" ]; then
                CPU_TEMP=$((TEMP_VALUE / 1000))°C
            fi
        elif command -v vcgencmd &> /dev/null; then
            CPU_TEMP=$(vcgencmd measure_temp 2>/dev/null | cut -d'=' -f2 | sed 's/[^0-9.]*//g' 2>/dev/null)
            if [ -n "$CPU_TEMP" ]; then
                CPU_TEMP="${CPU_TEMP}°C"
            fi
        fi
        
        # ======================= 内存信息 =======================
        MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}' 2>/dev/null || echo "N/A")
        MEM_USED=$(free -h | awk '/^Mem:/ {print $3}' 2>/dev/null || echo "N/A")
        MEM_FREE=$(free -h | awk '/^Mem:/ {print $4}' 2>/dev/null || echo "N/A")
        MEM_PERCENT=$(free | awk '/^Mem:/ {printf "%.1f%%", $3/$2 * 100}' 2>/dev/null || echo "N/A")
        
        # ======================= 磁盘信息 =======================
        DISK_USAGE=$(df -h / 2>/dev/null | tail -1)
        DISK_TOTAL=$(echo $DISK_USAGE | awk '{print $2}')
        DISK_USED=$(echo $DISK_USAGE | awk '{print $3}')
        DISK_AVAIL=$(echo $DISK_USAGE | awk '{print $4}')
        DISK_PERCENT=$(echo $DISK_USAGE | awk '{print $5}')
        
        # ======================= 网络信息 =======================
        INTERNAL_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
        EXTERNAL_IP=$(curl -s --max-time 3 https://api.ip.sb/ip 2>/dev/null || echo "$INTERNAL_IP")
        
        # 网络接口统计
        INTERFACE=$(ip route | head -1 | awk '{print $5}' 2>/dev/null || echo "eth0")
        if [ -f "/sys/class/net/$INTERFACE/statistics/rx_bytes" ]; then
            RX_BYTES=$(cat "/sys/class/net/$INTERFACE/statistics/rx_bytes" 2>/dev/null || echo "0")
            TX_BYTES=$(cat "/sys/class/net/$INTERFACE/statistics/tx_bytes" 2>/dev/null || echo "0")
        else
            RX_BYTES=$(cat /proc/net/dev 2>/dev/null | grep -E "(eth0|enp|ens)" | head -1 | awk '{print $2}' 2>/dev/null || echo "0")
            TX_BYTES=$(cat /proc/net/dev 2>/dev/null | grep -E "(eth0|enp|ens)" | head -1 | awk '{print $10}' 2>/dev/null || echo "0")
        fi
        
        # 实时网络流量计算
        if [ -f "/tmp/net_rx_prev" ] && [ -f "/tmp/net_tx_prev" ]; then
            RX_PREV=$(cat /tmp/net_rx_prev)
            TX_PREV=$(cat /tmp/net_tx_prev)
            RX_RATE=$(((RX_BYTES - RX_PREV) / 2))  # 每秒字节数
            TX_RATE=$(((TX_BYTES - TX_PREV) / 2))
            RX_RATE_HUMAN=$(echo "$RX_RATE" | numfmt --to=iec-i --suffix=B/s 2>/dev/null || echo "0 B/s")
            TX_RATE_HUMAN=$(echo "$TX_RATE" | numfmt --to=iec-i --suffix=B/s 2>/dev/null || echo "0 B/s")
        else
            RX_RATE_HUMAN="计算中..."
            TX_RATE_HUMAN="计算中..."
        fi
        
        # 保存当前值供下次计算
        echo "$RX_BYTES" > /tmp/net_rx_prev
        echo "$TX_BYTES" > /tmp/net_tx_prev
        
        # 网络连接信息
        # 监听端口
        LISTEN_PORTS=$(netstat -tlnp 2>/dev/null | grep LISTEN | head -5 | awk '{print $4}' | sed 's/.*://' || echo "无")
        
        # 活跃连接数
        ESTABLISHED_COUNT=$(netstat -an 2>/dev/null | grep ESTABLISHED | wc -l || echo "0")
        
        # 获取一些连接详情（最多显示3个）
        CONNECTION_DETAILS=$(netstat -an 2>/dev/null | grep ESTABLISHED | head -3 | awk '{print $4, $5}' | while read local remote; do
            local_port=$(echo "$local" | sed 's/.*://')
            remote_ip=$(echo "$remote" | sed 's/.*://' | cut -d: -f1)
            remote_port=$(echo "$remote" | sed 's/.*://' | cut -d: -f2)
            echo "本地:$local_port -> 远程:$remote_ip:$remote_port"
        done || echo "无活跃连接")
        
        # ======================= Docker状态 =======================
        DOCKER_STATUS="未安装"
        DOCKER_CONTAINER_STATUS="无"
        if command -v docker &> /dev/null; then
            DOCKER_VERSION=$(docker --version 2>/dev/null | head -n1 || echo "未知版本")
            DOCKER_STATUS="已安装"
            if docker ps 2>/dev/null | grep -q "$CONTAINER_NAME"; then
                DOCKER_CONTAINER_STATUS="运行中"
            elif docker ps -a 2>/dev/null | grep -q "$CONTAINER_NAME"; then
                DOCKER_CONTAINER_STATUS="已停止"
            else
                DOCKER_CONTAINER_STATUS="不存在"
            fi
        fi
        
        # ======================= CPU核心使用率 =======================
        # 获取每个CPU核心的使用率
        CPU_CORE_USAGE=()
        if [ -f /proc/stat ]; then
            for i in $(seq 0 $((CPU_CORES - 1))); do
                if [ -f /sys/devices/system/cpu/cpu$i/cpufreq/scaling_cur_freq ]; then
                    CORE_USAGE=$(awk -v core=$i '
                    BEGIN {
                        # 读取CPU使用率
                        while ((getline line) > 0) {
                            if (line ~ /^cpu[0-9]+/) {
                                if (core == 0 && line ~ /^cpu0/) {
                                    split(line, fields)
                                    idle = fields[5]
                                    total = 0
                                    for (j=1; j<=4; j++) total += fields[j]
                                    total += idle
                                    idle_percent = (idle / total) * 100
                                    printf "%.1f", idle_percent
                                    break
                                }
                            }
                        }
                    }' /proc/stat 2>/dev/null || echo "0")
                    
                    if [ "$CORE_USAGE" != "0" ]; then
                        CPU_USAGE=$(echo "100 - $CORE_USAGE" | bc -l 2>/dev/null || echo "0")
                        CPU_CORE_USAGE+=("$CPU_USAGE")
                    else
                        CPU_CORE_USAGE+=("0.0")
                    fi
                else
                    CPU_CORE_USAGE+=("0.0")
                fi
            done
        fi
        
        # ======================= 显示监控界面 =======================
        echo -e "\033[1;32m┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐\033[0m"
        echo -e "\033[1;32m│\033[1;36m  🖥️  系统信息              🏠 主机名: $(hostname)                           \033[1;36m│\033[0m"
        echo -e "\033[1;32m│\033[1;36m  🔧 架构: $(uname -m | sed 's/x86_64/x64/' | sed 's/aarch64/arm64/')    🌍 内网IP: $INTERNAL_IP                    \033[1;36m│\033[0m"
        echo -e "\033[1;32m│\033[1;36m  🌐 公网IP: $EXTERNAL_IP                   \033[1;36m│\033[0m"
        echo -e "\033[1;32m└────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘\033[0m"
        
        echo -e "\033[1;34m┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐\033[0m"
        echo -e "\033[1;34m│\033[1;33m  🖥️  CPU监控 ($(nproc --all 2>/dev/null || echo '0')核心)                                                     \033[1;34m│\033[0m"
        echo -e "\033[1;34m│\033[1;37m  型号: $CPU_INFO\033[1;34m│\033[0m"
        echo -e "\033[1;34m│\033[1;36m  🚀 负载: $CPU_LOAD                                                 \033[1;34m│\033[0m"
        echo -e "\033[1;34m│\033[1;36m  🌡️  温度: ${CPU_TEMP:-"不可用"}                                           \033[1;34m│\033[0m"
        echo -e "\033[1;34m│\033[1;36m  📊 核心使用率:                                                     \033[1;34m│\033[0m"
        
        # 显示CPU核心使用率
        CORE_COUNT=0
        for usage in "${CPU_CORE_USAGE[@]}"; do
            if [ $((CORE_COUNT % 4)) -eq 0 ]; then
                echo -n "\033[1;34m│\033[1;36m  "
            fi
            printf "CPU%d: %5.1f%%" $CORE_COUNT $usage
            if [ $((CORE_COUNT % 4)) -eq 3 ]; then
                echo -e "\033[1;34m│\033[0m"
            else
                echo -n "  "
            fi
            ((CORE_COUNT++))
        done
        
        # 如果不是4的倍数，补齐剩余空间
        while [ $((CORE_COUNT % 4)) -ne 0 ]; do
            echo -n "          "
            if [ $((CORE_COUNT % 4)) -eq 3 ]; then
                echo -e "\033[1;34m│\033[0m"
            else
                echo -n "  "
            fi
            ((CORE_COUNT++))
        done
        
        echo -e "\033[1;34m└────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘\033[0m"
        
        echo -e "\033[1;35m┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐\033[0m"
        echo -e "\033[1;35m│\033[1;33m  💾 内存监控                                                           \033[1;35m│\033[0m"
        echo -e "\033[1;35m│\033[1;36m  📈 总内存: $MEM_TOTAL  使用: $MEM_USED ($MEM_PERCENT)  可用: $MEM_FREE                         \033[1;35m│\033[0m"
        
        # 内存使用率进度条 - 使用awk替代bc，避免依赖问题
        MEM_PERCENT_NUM=$(echo $MEM_PERCENT | sed 's/%//' 2>/dev/null || echo "0")
        BAR_LENGTH=50
        # 使用awk进行精确计算，支持小数
        FILLED=$(awk -v percent="$MEM_PERCENT_NUM" -v length="$BAR_LENGTH" 'BEGIN {printf "%.0f", percent * length / 100}' 2>/dev/null || echo "0")
        
        echo -e "\033[1;35m│\033[1;36m  ████ 使用情况: [\033[1;32m"
        for i in $(seq 1 $FILLED); do echo -n "█"; done
        echo -n "\033[1;31m"
        for i in $(seq $((FILLED + 1)) $BAR_LENGTH); do echo -n "█"; done
        echo -e "\033[1;36m] $MEM_PERCENT\033[1;35m│\033[0m"
        
        echo -e "\033[1;35m└────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘\033[0m"
        
        echo -e "\033[1;31m┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐\033[0m"
        echo -e "\033[1;31m│\033[1;33m  💽 磁盘监控 (/ 根目录)                                               \033[1;31m│\033[0m"
        echo -e "\033[1;31m│\033[1;36m  📈 总容量: $DISK_TOTAL  使用: $DISK_USED  可用: $DISK_AVAIL  使用率: $DISK_PERCENT                     \033[1;31m│\033[0m"
        
        # 磁盘使用率进度条 - 使用awk替代bash算术扩展，支持小数
        DISK_PERCENT_NUM=$(echo $DISK_PERCENT | sed 's/%//' 2>/dev/null || echo "0")
        # 使用awk进行精确计算，支持小数
        FILLED=$(awk -v percent="$DISK_PERCENT_NUM" -v length="$BAR_LENGTH" 'BEGIN {printf "%.0f", percent * length / 100}' 2>/dev/null || echo "0")
        
        echo -e "\033[1;31m│\033[1;36m  ████ 使用情况: [\033[1;32m"
        for i in $(seq 1 $FILLED); do echo -n "█"; done
        echo -n "\033[1;31m"
        for i in $(seq $((FILLED + 1)) $BAR_LENGTH); do echo -n "█"; done
        echo -e "\033[1;36m] $DISK_PERCENT\033[1;31m│\033[0m"
        
        echo -e "\033[1;31m└────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘\033[0m"
        
        echo -e "\033[1;33m┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐\033[0m"
        echo -e "\033[1;33m│\033[1;33m  🌐 网络监控                                                           \033[1;33m│\033[0m"
        echo -e "\033[1;33m│\033[1;36m  🔗 接口: $INTERFACE    接收: $(echo $RX_BYTES | numfmt --to=iec-i --suffix=B 2>/dev/null || echo "N/A")  发送: $(echo $TX_BYTES | numfmt --to=iec-i --suffix=B 2>/dev/null || echo "N/A")          \033[1;33m│\033[0m"
        echo -e "\033[1;33m│\033[1;36m  📈 实时流量: ↓ $RX_RATE_HUMAN  ↑ $TX_RATE_HUMAN                              \033[1;33m│\033[0m"
        echo -e "\033[1;33m│\033[1;36m  🌍 内网IP: $INTERNAL_IP  公网IP: $EXTERNAL_IP                           \033[1;33m│\033[0m"
        echo -e "\033[1;33m│\033[1;36m  🔌 活跃连接: $ESTABLISHED_COUNT 个  监听端口: $LISTEN_PORTS                          \033[1;33m│\033[0m"
        echo -e "\033[1;33m│\033[1;36m  🔗 连接详情:                                                           \033[1;33m│\033[0m"
        
        # 显示连接详情
        CONN_COUNT=0
        while IFS= read -r conn_line; do
            if [ $CONN_COUNT -lt 2 ]; then
                printf "\033[1;33m│\033[1;36m    %-70s\033[1;33m│\n" "$conn_line"
                ((CONN_COUNT++))
            fi
        done <<< "$CONNECTION_DETAILS"
        
        # 如果连接数少于2行，补齐剩余空间
        while [ $CONN_COUNT -lt 2 ]; do
            printf "\033[1;33m│\033[1;36m    %-70s\033[1;33m│\n" ""
            ((CONN_COUNT++))
        done
        
        echo -e "\033[1;33m└────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘\033[0m"
        
        echo -e "\033[1;30m┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐\033[0m"
        echo -e "\033[1;30m│\033[1;33m  🐳 Docker状态                                                          \033[1;30m│\033[0m"
        echo -e "\033[1;30m│\033[1;36m  📦 状态: $DOCKER_STATUS  版本: $(echo $DOCKER_VERSION | cut -d' ' -f2 | head -1 2>/dev/null || echo "N/A")                  \033[1;30m│\033[0m"
        echo -e "\033[1;30m│\033[1;36m  🔧 容器: $DOCKER_CONTAINER_STATUS                                               \033[1;30m│\033[0m"
        echo -e "\033[1;30m└────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘\033[0m"
        
        # ======================= 进程信息 =======================
        echo -e "\033[1;36m┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐\033[0m"
        echo -e "\033[1;36m│\033[1;33m  🔄 实时进程 (TOP 5 CPU使用)                                             \033[1;36m│\033[0m"
        echo -e "\033[1;36m│\033[1;36m  PID    CPU%    MEM%    进程名                                         \033[1;36m│\033[0m"
        echo -e "\033[1;36m├────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤\033[0m"
        
        # 获取TOP 5进程
        TOP_PROCESSES=$(ps aux --sort=-%cpu | head -6 | tail -5)
        while IFS= read -r line; do
            PID=$(echo $line | awk '{print $2}')
            CPU=$(echo $line | awk '{print $3}' | sed 's/%//')
            MEM=$(echo $line | awk '{print $4}' | sed 's/%//')
            COMM=$(echo $line | awk '{print $11}')
            printf "\033[1;36m│\033[1;37m  %-6s %5.1f%%   %5.1f%%   %-30s\033[1;36m│\n" "$PID" "$CPU" "$MEM" "$COMM"
        done <<< "$TOP_PROCESSES"
        
        echo -e "\033[1;36m└────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘\033[0m"
        
        # ======================= 控制信息 =======================
        echo -e "\033[1;32m┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐\033[0m"
        echo -e "\033[1;32m│\033[1;37m  ⌨️  控制台: Ctrl+C 退出  |  Enter 返回菜单  |  自动刷新: 每2秒                 \033[1;32m│\033[0m"
        echo -e "\033[1;32m└────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘\033[0m"
        
        # 显示操作提示
        echo -e "\n\033[1;36m╔════════════════════════════════════════════════════════════════════════════════════════╗\033[0m"
        echo -e "\033[1;36m║\033[1;33m 操作提示: [R] 刷新数据  [Q] 退出监控  [Ctrl+C] 强制退出  \033[1;36m║\033[0m"
        echo -e "\033[1;36m╚════════════════════════════════════════════════════════════════════════════════════════╝\033[0m"
        echo -e "\033[1;35m🔄 等待操作... 请按 R 键刷新数据\033[0m"
        
        # 等待用户输入
        read -r -p "" input
        
        # 处理用户输入
        case "$input" in
            r|R)
                continue  # 重新显示数据
                ;;
            q|Q)
                echo -e "\n\033[1;32m🔚 退出监控模式...\033[0m"
                sleep 1
                return 0
                ;;
            *)
                if [ -z "$input" ]; then
                    echo -e "\n\033[1;32m🔙 返回主菜单...\033[0m"
                    sleep 1
                    return 0
                fi
                ;;
        esac
        
    done
}

# ========================= 主执行函数 =========================
main() {
    check_working_directory
    
    check_root_permission
    check_system
    install_dependencies
    check_server_config 
    show_start_ui        
    show_server_config 
    
    while true; do
        main_menu
    done
}

# 启动脚本执行
main "$@"# ========================= ASR 配置（15个服务商） =========================
config_asr() {
    while true; do
        echo -e "\n${GREEN}【1/5】配置 ASR (语音识别) 服务${RESET}"
        echo "请选择ASR服务商（共15个）："
        
        if [ "$IS_MEMORY_SUFFICIENT" = true ]; then
            echo " 1) ${GREEN}FunASR (本地)${RESET}"
            echo -e "    ${CYAN}✅ 内存充足 (${MEM_TOTAL}GB ≥ 4GB) - 可选择${RESET}"
            echo " 2) FunASRServer (独立部署)"
            echo " 3) ${GREEN}SherpaASR (本地，多语言)${RESET}"
            echo -e "    ${CYAN}✅ 内存充足 - 可选择${RESET}"
            echo " 4) ${GREEN}SherpaParaformerASR (本地，中文专用)${RESET}"
            echo -e "    ${CYAN}✅ 内存充足 (${MEM_TOTAL}GB ≥ 4GB) - 可选择${RESET}"
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
            echo "14) Qwen3ASRFlash (通义千问)"
            echo "15) XunfeiStreamASR (讯飞，流式)"
            echo " 0) ${YELLOW} 返回上一步 ${RESET}"
        elif [ "$IS_SHERPA_PARAFORMER_AVAILABLE" = true ]; then
            echo " 1) ${RED}FunASR (本地)${RESET} ${RED}❌ 内存不足 (${MEM_TOTAL}GB < 4GB)${RESET}"
            echo " 2) FunASRServer (独立部署)"
            echo -e " 3) ${RED}SherpaASR (本地，多语言)${RESET} ${RED}❌ 内存不足${RESET}"
            echo " 4) ${YELLOW}SherpaParaformerASR (本地，中文专用)${RESET}"
            echo -e "    ${CYAN}💡 可用 (${MEM_TOTAL}GB ≥ 2GB) - 轻量级模型${RESET}"
            echo " 5) DoubaoASR (火山引擎，按次收费)"
            echo " 6) DoubaoStreamASR (火山引擎，按时收费)"
            echo " 7) TencentASR (腾讯云)"
            echo " 8) AliyunASR (阿里云，批量处理)"
            echo " 9) AliyunStreamASR (阿里云，实时流式) [推荐]"
            echo "10) BaiduASR (百度智能云)"
            echo "11) OpenaiASR (OpenAI)"
            echo "12) GroqASR (Groq)"
            echo "13) ${GREEN}VoskASR (本地，完全离线)${RESET}"
            echo -e "    ${CYAN}✅ 内存占用较小 (建议≥2GB)${RESET}"
            echo "14) Qwen3ASRFlash (通义千问)"
            echo "15) XunfeiStreamASR (讯飞，流式)"
            echo " 0) ${YELLOW} 返回上一步 ${RESET}"
        else
            echo " 1) ${RED}FunASR (本地)${RESET} ${RED}❌ 内存不足 (${MEM_TOTAL}GB < 4GB)${RESET}"
            echo " 2) FunASRServer (独立部署)"
            echo -e " 3) ${RED}SherpaASR (本地，多语言)${RESET} ${RED}❌ 内存不足${RESET}"
            echo -e " 4) ${RED}SherpaParaformerASR (本地，中文专用)${RESET} ${RED}❌ 内存不足 (${MEM_TOTAL}GB < 2GB)${RESET}"
            echo " 5) DoubaoASR (火山引擎，按次收费)"
            echo " 6) DoubaoStreamASR (火山引擎，按时收费)"
            echo " 7) TencentASR (腾讯云)"
            echo " 8) AliyunASR (阿里云，批量处理)"
            echo " 9) AliyunStreamASR (阿里云，实时流式) [推荐]"
            echo "10) BaiduASR (百度智能云)"
            echo "11) OpenaiASR (OpenAI)"
            echo "12) GroqASR (Groq)"
            echo "13) ${GREEN}VoskASR (本地，完全离线)${RESET}"
            echo -e "    ${CYAN}✅ 内存占用较小 (建议≥2GB)${RESET}"
            echo "14) Qwen3ASRFlash (通义千问)"
            echo "15) XunfeiStreamASR (讯飞，流式)"
            echo " 0) ${YELLOW} 返回上一步 ${RESET}"
        fi
        
        read -r -p "请输入序号 (默认推荐 9，输入0返回上一步): " asr_choice < /dev/tty
        asr_choice=${asr_choice:-9}
        
        # ASR是第一步，输入0直接返回主菜单
        if [ "$asr_choice" = "0" ]; then
            echo -e "${CYAN}🔄 取消配置，返回主菜单${RESET}"
            return 1
        fi
        
        local asr_provider_key
        case $asr_choice in
            1)
                asr_provider_key="FunASR"
                if [ "$IS_MEMORY_SUFFICIENT" = false ]; then
                    echo -e "\n${RED}❌ 内存不足 (${MEM_TOTAL}GB < 4GB)，无法选择FunASR本地模型${RESET}"
                    echo -e "${YELLOW}💡 请重新选择其他ASR服务商...${RESET}"
                    sleep 1
                    continue
                fi
                echo -e "\n${GREEN}✅ 已选择本地模型 FunASR。${RESET}"
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
                ;;
            2)
                asr_provider_key="FunASRServer"
                echo -e "\n${YELLOW}⚠️ 您选择了 FunASRServer。${RESET}"
                echo -e "${CYAN}🔗 需要自行部署 FunASR Server 服务${RESET}"
                read -r -p "请输入 FunASR Server 地址 (默认 http://localhost:10095): " server_url < /dev/tty
                server_url=${server_url:-"http://localhost:10095"}
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
                sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    host: .*/    host: $server_url/" "$CONFIG_FILE"
                ;;
            3)
                asr_provider_key="SherpaASR"
                if [ "$IS_MEMORY_SUFFICIENT" = false ]; then
                    echo -e "\n${RED}❌ 内存不足 (${MEM_TOTAL}GB < 4GB)，无法选择SherpaASR本地模型${RESET}"
                    echo -e "${YELLOW}💡 请重新选择其他ASR服务商...${RESET}"
                    sleep 1
                    continue
                fi
                echo -e "\n${GREEN}✅ 已选择本地模型 SherpaASR。${RESET}"
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
                ;;
            4)
                asr_provider_key="SherpaParaformerASR"
                if [ "$IS_SHERPA_PARAFORMER_AVAILABLE" = false ]; then
                    echo -e "\n${RED}❌ 内存不足 (${MEM_TOTAL}GB < 2GB)，无法选择SherpaParaformerASR本地模型${RESET}"
                    echo -e "${YELLOW}💡 请重新选择其他ASR服务商...${RESET}"
                    sleep 1
                    continue
                fi
                echo -e "\n${GREEN}✅ 已选择本地模型 SherpaParaformerASR。${RESET}"
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
                ;;
            5)
                asr_provider_key="DoubaoASR"
                echo -e "\n${YELLOW}⚠️ 您选择了火山引擎 DoubaoASR。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://www.volcengine.com/products/voice-interaction${RESET}"
                read -r -p "请输入 AppID: " appid < /dev/tty
                read -r -p "请输入 Access Token: " access_token < /dev/tty
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
                ;;
            6)
                asr_provider_key="DoubaoStreamASR"
                echo -e "\n${YELLOW}⚠️ 您选择了火山引擎 DoubaoStreamASR。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://www.volcengine.com/products/voice-interaction${RESET}"
                read -r -p "请输入 AppID: " appid < /dev/tty
                read -r -p "请输入 Access Token: " access_token < /dev/tty
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
                ;;
            7)
                asr_provider_key="TencentASR"
                echo -e "\n${YELLOW}⚠️ 您选择了腾讯云 TencentASR。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://console.cloud.tencent.com/asr${RESET}"
                read -r -p "请输入 APPID: " appid < /dev/tty
                read -r -p "请输入 SecretID: " secret_id < /dev/tty
                read -r -p "请输入 SecretKey: " secret_key < /dev/tty
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
                ;;
            8)
                asr_provider_key="AliyunASR"
                echo -e "\n${YELLOW}⚠️ 您选择了阿里云 AliyunASR。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://dashscope.console.aliyun.com${RESET}"
                read -r -p "请输入 Appkey: " appkey < /dev/tty
                read -r -p "请输入 Token: " token < /dev/tty
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
                ;;
            9)
                asr_provider_key="AliyunStreamASR"
                echo -e "\n${YELLOW}⚠️ 您选择了阿里云 AliyunStreamASR。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://nls-portal.console.aliyun.com/${RESET}"
                read -r -p "请输入 Appkey: " appkey < /dev/tty
                read -r -p "请输入 Token: " token < /dev/tty
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
                ;;
            10)
                asr_provider_key="BaiduASR"
                echo -e "\n${YELLOW}⚠️ 您选择了百度智能云 BaiduASR。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://console.bce.baidu.com/ai/${RESET}"
                read -r -p "请输入 APP ID: " app_id < /dev/tty
                read -r -p "请输入 API Key: " api_key < /dev/tty
                read -r -p "请输入 Secret Key: " secret_key < /dev/tty
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
                ;;
            11)
                asr_provider_key="OpenaiASR"
                echo -e "\n${YELLOW}⚠️ 您选择了 OpenAI ASR。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://platform.openai.com/${RESET}"
                read -r -p "请输入 API Key: " api_key < /dev/tty
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
                ;;
            12)
                asr_provider_key="GroqASR"
                echo -e "\n${YELLOW}⚠️ 您选择了 Groq ASR。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://console.groq.com/${RESET}"
                read -r -p "请输入 API Key: " api_key < /dev/tty
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
                ;;
            13)
                asr_provider_key="VoskASR"
                if [ "$IS_MEMORY_SUFFICIENT" = false ]; then
                    echo -e "\n${RED}❌ 内存不足，无法选择VoskASR本地模型${RESET}"
                    echo -e "${YELLOW}💡 请重新选择其他ASR服务商...${RESET}"
                    sleep 1
                    continue
                fi
                echo -e "\n${GREEN}✅ 已选择本地模型 VoskASR。${RESET}"
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
                ;;
            14)
                asr_provider_key="Qwen3ASRFlash"
                echo -e "\n${YELLOW}⚠️ 您选择了通义千问 Qwen3ASRFlash。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://dashscope.console.aliyun.com${RESET}"
                read -r -p "请输入 API Key: " api_key < /dev/tty
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
                ;;
            15)
                asr_provider_key="XunfeiStreamASR"
                echo -e "\n${YELLOW}⚠️ 您选择了讯飞 XunfeiStreamASR。${RESET}"
                echo -e "${CYAN}🔑 开通地址：https://www.xfyun.cn${RESET}"
                read -r -p "请输入 APP ID: " app_id < /dev/tty
                read -r -p "请输入 API Secret: " api_secret < /dev/tty
                read -r -p "请输入 API Key: " api_key < /dev/tty
                
                sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$CONFIG_FILE"
                ;;
            *)
                echo -e "\n${RED}❌ 输入无效，请选择1-15范围内的数字，或输入0返回上一步${RESET}"
                echo -e "${YELLOW}💡 提示：默认推荐选项9（阿里云流式ASR）${RESET}"
                read -r -p "按回车键重新选择..." < /dev/tty
                continue
                ;;
        esac
        
        # 配置完成，返回0表示成功
        return 0
    done
}
