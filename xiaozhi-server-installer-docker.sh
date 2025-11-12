#!/bin/bash
set -uo pipefail
trap exit_confirm SIGINT

# ========================= 基础配置 =========================
# 作者@昊天兽王
# 因为看到很多新手都不会手动部署小智的服务器，所以通宵了一个晚上写了第一个版本。
# 第一次写脚本，使用了minimax和豆包来写的，可能写的不是很好，请见谅。（minimax和豆包是mvp）
#我只在Ubuntu上测试过这个脚本，没有在其他系统上测试过，也没有测试大于4G使用本地模型的选项，也没有大规模测试，如果遇到了bug，请及时联系我！ QQ 1484475153 GitHub https://github.com/haotianshouwnag 邮箱 1484475153@qq.com

AUTHOR="昊天兽王"
SCRIPT_DESC="小智服务器一键部署脚本：自动安装Docker、配置ASR/LLM/VLLM/TTS、启动服务"
CONFIG_FILE_URL="https://gh-proxy.com/https://raw.githubusercontent.com/xinnan-tech/xiaozhi-esp32-server/refs/heads/main/main/xiaozhi-server/config.yaml"
DOCKER_COMPOSE_URL="https://gh-proxy.com/https://raw.githubusercontent.com/xinnan-tech/xiaozhi-esp32-server/refs/heads/main/main/xiaozhi-server/docker-compose.yml"
MAIN_DIR="$HOME/xiaozhi-server"
CONTAINER_NAME="xiaozhi-esp32-server"
CONFIG_FILE="$MAIN_DIR/config.yaml"
OVERRIDE_CONFIG_FILE="$MAIN_DIR/data/.config.yaml"
LOCAL_ASR_MODEL_URL="https://modelscope.cn/models/iic/SenseVoiceSmall/resolve/master/model.pt"
RETRY_MAX=3
RETRY_DELAY=3

# 颜色定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
PURPLE="\033[35m"
CYAN="\033[36m"
RESET="\033[0m"
BOLD="\033[1m"

# 全局变量
CHATGLM_API_KEY=""
IS_MEMORY_SUFFICIENT=false
CPU_MODEL=""
CPU_CORES=""
MEM_TOTAL=""
DISK_AVAIL=""
NET_INTERFACE=""
NET_SPEED=""
INTERNAL_IP=""
EXTERNAL_IP=""
OS_VERSION=""
CURRENT_DEPLOY_TYPE=""

# ========================= 工具函数 =========================
check_dependencies() {
    echo -e "\n${CYAN}🔍 正在检查必要的系统工具...${RESET}"
    local dependencies=("curl" "jq" "sed" "awk")
    local missing=()

    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠️  检测到缺少必要工具：${missing[*]}，正在尝试安装...${RESET}"
        if ! sudo apt-get update; then
            echo -e "${RED}❌ 更新软件源失败，请检查网络连接。${RESET}"
            exit 1
        fi
        if ! sudo apt-get install -y "${missing[@]}"; then
            echo -e "${RED}❌ 安装工具 ${missing[*]} 失败，请手动安装后重试。${RESET}"
            exit 1
        fi
        echo -e "${GREEN}✅ 工具 ${missing[*]} 安装成功。${RESET}"
    else
        echo -e "${GREEN}✅ 所有必要工具均已安装。${RESET}"
    fi
}

exit_confirm() {
  echo -e "\n${YELLOW}⚠️  检测到退出信号，是否确认退出？(y/n)${RESET}"
  read -r -n 1 choice
  echo
  [[ "$choice" == "y" || "$choice" == "Y" ]] && { echo -e "${PURPLE}👋 感谢使用，脚本已退出${RESET}"; exit 0; }
  echo -e "${GREEN}✅ 继续执行脚本...${RESET}"
}

retry_exec() {
  local cmd="$1"
  local desc="$2"
  local count=0
  echo -e "${CYAN}🔄 正在执行：$desc${RESET}"
  while true; do
    if eval "$cmd"; then
      echo -e "${GREEN}✅ $desc 成功${RESET}"
      return 0
    else
      count=$((count+1))
      if (( count < RETRY_MAX )); then
        echo -e "${YELLOW}❌ $desc 失败，将在 $RETRY_DELAY 秒后进行第 $((count+1)) 次重试...${RESET}"
        sleep $RETRY_DELAY
      else
        echo -e "${RED}❌ $desc 已失败 $RETRY_MAX 次，无法继续。请检查相关配置或网络连接后重试。${RESET}"
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
  echo -e "${BLUE}版本：v1.0.0"
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
    EXTERNAL_IP=$(curl -s https://api.ip.sb/ip || curl -s https://ifconfig.me || curl -s https://ipinfo.io/ip || echo "$INTERNAL_IP")

    # 获取硬件信息
    MEM_TOTAL=$(free -g | awk '/Mem:/ {print $2}')
    if [ -z "$MEM_TOTAL" ] || [ "$MEM_TOTAL" = "0" ]; then
        MEM_TOTAL=$(free -m | awk '/Mem:/ {print int($2/1024)}')
    fi
    CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//')
    CPU_CORES=$(grep -c '^processor' /proc/cpuinfo)
    DISK_AVAIL=$(df -h / | awk '/\// {print $4}')
    NET_INTERFACE=$(ip -br link | grep -v 'LOOPBACK' | grep -v 'DOWN' | awk '{print $1}' | head -n1)
    
    # 获取GPU信息
    GPU_INFO="未检测到GPU"
    GPU_MEMORY=""
    GPU_COUNT=0
    
    # 检查NVIDIA GPU
    if command -v nvidia-smi &> /dev/null; then
        GPU_INFO=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits 2>/dev/null | head -1)
        if [ -n "$GPU_INFO" ]; then
            GPU_MODEL=$(echo "$GPU_INFO" | cut -d',' -f1 | sed 's/^ *//;s/ *$//')
            GPU_MEMORY=$(echo "$GPU_INFO" | cut -d',' -f2 | sed 's/^ *//;s/ *$//')
            GPU_COUNT=$(nvidia-smi --list-gpus | grep -c "GPU" || echo "1")
        fi
    fi
    
    # 检查AMD GPU
    if [ "$GPU_INFO" = "未检测到GPU" ] && command -v lspci &> /dev/null; then
        AMD_GPU=$(lspci | grep -i "VGA\|3D controller" | grep -i "AMD\|ATI" | head -1)
        if [ -n "$AMD_GPU" ]; then
            GPU_INFO=$(echo "$AMD_GPU" | sed 's/.*VGA.*: //; s/.*3D controller.*: //')
            GPU_COUNT=$(lspci | grep -i "VGA\|3D controller" | grep -c "AMD\|ATI")
        fi
    fi
    
    # 检查Intel GPU
    if [ "$GPU_INFO" = "未检测到GPU" ] && command -v lspci &> /dev/null; then
        INTEL_GPU=$(lspci | grep -i "VGA\|3D controller" | grep -i "Intel" | head -1)
        if [ -n "$INTEL_GPU" ]; then
            GPU_INFO=$(echo "$INTEL_GPU" | sed 's/.*VGA.*: //; s/.*3D controller.*: //')
            GPU_COUNT=$(lspci | grep -i "VGA\|3D controller" | grep -c "Intel")
        fi
    fi
    
    # 获取系统版本
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_VERSION="$PRETTY_NAME"
    elif command -v lsb_release &> /dev/null; then
        OS_VERSION=$(lsb_release -d | cut -f2)
    elif [ -f /etc/issue ]; then
        OS_VERSION=$(head -n1 /etc/issue | sed 's/\\n//g; s/\\l//g')
    else
        OS_VERSION="未知版本"
    fi
    
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
    if [ "$GPU_COUNT" -gt 1 ]; then
        echo -e "  - ${BOLD}GPU数量${RESET}：$GPU_COUNT 个"
    fi
    if [ -n "$GPU_MEMORY" ] && [ "$GPU_MEMORY" != "" ]; then
        echo -e "  - ${BOLD}GPU显存${RESET}：${GPU_MEMORY} MB"
    fi
    echo -e "  - ${BOLD}根目录可用空间${RESET}：$DISK_AVAIL"
    echo -e "  - ${BOLD}网卡${RESET}：$NET_INTERFACE（速率：$NET_SPEED）"
    echo -e "  - ${BOLD}内网IP${RESET}：$INTERNAL_IP"
    echo -e "  - ${BOLD}公网IP${RESET}：$EXTERNAL_IP"
    echo -e "${PURPLE}==================================================${RESET}"
    echo

    if [ "$MEM_TOTAL" -ge 4 ]; then
        echo -e "${GREEN}✅ 内存检查通过（${MEM_TOTAL} GB ≥ 4 GB），可以选择本地ASR模型（如FunASR）${RESET}"
        IS_MEMORY_SUFFICIENT=true
    else
        echo -e "${RED}❌ 内存检查失败（${MEM_TOTAL} GB < 4 GB）${RESET}"
        echo -e "${RED}⚠️⚠️⚠️  警告：本地ASR模型（FunASR）需要服务器内存≥4GB，当前配置不足！${RESET}"
        echo -e "${RED}⚠️  若强行使用，可能导致服务器卡死或服务崩溃，请选择其他在线ASR模型${RESET}"
        IS_MEMORY_SUFFICIENT=false
    fi
    echo
}

choose_docker_mirror() {
  echo -e "${GREEN}📦 请选择Docker镜像源（加速后续下载）：${RESET}"
  echo "1) 阿里云"
  echo "2) 腾讯云"
  echo "3) 华为云"
  echo "4) DaoCloud"
  echo "5) 网易云"
  echo "6) 清华大学源"
  echo "7) 中国科学技术大学源"
  echo "8) 官方源（不推荐国内用户）"
  read -r -p "请输入序号（默认1）：" mirror_choice
  mirror_choice=${mirror_choice:-1}

  local mirror_url
  case $mirror_choice in
    1) mirror_url="https://registry.cn-hangzhou.aliyuncs.com" ;;
    2) mirror_url="https://mirror.ccs.tencentyun.com" ;;
    3) mirror_url="https://repo.huaweicloud.com" ;;
    4) mirror_url="https://f1361db2.m.daocloud.io" ;;
    5) mirror_url="https://hub-mirror.c.163.com" ;;
    6) mirror_url="https://mirrors.tuna.tsinghua.edu.cn/docker-registry" ;;
    7) mirror_url="https://docker.mirrors.ustc.edu.cn" ;;
    8) mirror_url="https://registry-1.docker.io" ;;
    *) mirror_url="https://registry.cn-hangzhou.aliyuncs.com" ;;
  esac

  sudo mkdir -p /etc/docker
  sudo tee /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": ["$mirror_url"]
}
EOF
  sudo systemctl daemon-reload
  sudo systemctl restart docker
  echo -e "${GREEN}✅ 已配置Docker镜像源：$mirror_url${RESET}"
}

check_and_install_docker() {
  echo -e "\n${BLUE}🔍 检测Docker是否安装...${RESET}"
  if command -v docker &> /dev/null && docker --version &> /dev/null; then
    echo -e "${GREEN}✅ Docker 已安装${RESET}"
  else
    echo -e "${YELLOW}❌ Docker 未安装，开始安装...${RESET}"
    retry_exec "sudo apt-get update && sudo apt-get install -y ca-certificates curl gnupg lsb-release" "安装Docker依赖"
    retry_exec "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg" "添加Docker密钥"
    retry_exec "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null" "添加Docker源"
    retry_exec "sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin" "安装Docker核心组件"
    
    sudo usermod -aG docker $USER
    newgrp docker &> /dev/null
    echo -e "${GREEN}✅ Docker 安装完成${RESET}"
    choose_docker_mirror
  fi

  if ! docker compose version &> /dev/null; then
    echo -e "${YELLOW}❌ Docker Compose 未安装，开始安装...${RESET}"
    retry_exec "sudo curl -SL \"https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose" "安装Docker Compose"
  fi
}

clean_container() {
  echo -e "\n${BLUE}🔍 检测容器 $CONTAINER_NAME 是否存在...${RESET}"
  if docker ps -a --filter "name=^/${CONTAINER_NAME}$" --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
    echo -e "${YELLOW}⚠️  容器 $CONTAINER_NAME 已存在，正在删除...${RESET}"
    retry_exec "docker rm -f $CONTAINER_NAME" "删除容器 $CONTAINER_NAME"
  else
    echo -e "${GREEN}✅ 容器 $CONTAINER_NAME 不存在，继续执行${RESET}"
  fi
}

create_dirs() {
  echo -e "\n${BLUE}📂 开始创建目录结构...${RESET}"
  local dirs=("$MAIN_DIR/data" "$MAIN_DIR/models/SenseVoiceSmall" "$MAIN_DIR/models/vosk" "$MAIN_DIR/models/sherpa-onnx" "$MAIN_DIR/music")
  for dir in "${dirs[@]}"; do
    if [ ! -d "$dir" ]; then
      retry_exec "mkdir -p $dir" "创建目录 $dir"
    else
      echo -e "${GREEN}✅ 目录 $dir 已存在，跳过${RESET}"
    fi
  done
}

download_files() {
  echo -e "\n${BLUE}📥 开始下载配置文件...${RESET}"
  # 直接下载到 data/.config.yaml，避免卡死问题
  mkdir -p "$MAIN_DIR/data"
  retry_exec "curl -fSL $CONFIG_FILE_URL -o $OVERRIDE_CONFIG_FILE" "下载配置文件到 data/.config.yaml"
  retry_exec "curl -fSL $DOCKER_COMPOSE_URL -o $MAIN_DIR/docker-compose.yml" "下载 docker-compose.yml"
}

# ========================= 配置文件设置函数 =========================
setup_config_file() {
    echo -e "\n${CYAN}📁 配置小智服务器配置文件...${RESET}"
    
    # 创建data目录
    mkdir -p "$MAIN_DIR/data"
    echo -e "${GREEN}✅ 已创建 data 目录: $MAIN_DIR/data${RESET}"
    
    # 检查是否已存在配置文件
    if [ -f "$OVERRIDE_CONFIG_FILE" ]; then
        echo -e "${YELLOW}📋 发现 data 目录中已有配置文件${RESET}"
        echo "当前配置文件: $OVERRIDE_CONFIG_FILE"
        echo ""
        echo "请选择配置文件处理方式："
        echo "1) 使用现有配置文件"
        echo "2) 重新下载新的配置文件模板（会覆盖现有文件）"
        read -p "请输入选择 (1-2，默认1): " config_choice
        config_choice=${config_choice:-1}
        
        case $config_choice in
            2)
                echo -e "\n${BLUE}📥 重新下载新的配置文件模板...${RESET}"
                retry_exec "curl -fSL $CONFIG_FILE_URL -o $OVERRIDE_CONFIG_FILE" "下载配置文件到 data/.config.yaml"
                ;;
        esac
        
    else
        echo -e "${BLUE}📥 未发现配置文件，正在下载模板...${RESET}"
        retry_exec "curl -fSL $CONFIG_FILE_URL -o $OVERRIDE_CONFIG_FILE" "下载配置文件到 data/.config.yaml"
        echo -e "${GREEN}✅ 已下载并设置配置文件: $OVERRIDE_CONFIG_FILE${RESET}"
    fi
    
    # 显示配置文件信息
    echo ""
    echo -e "${CYAN}📊 配置文件状态:${RESET}"
    echo "配置文件: $OVERRIDE_CONFIG_FILE"
    echo "文件大小: $(du -h $OVERRIDE_CONFIG_FILE 2>/dev/null | cut -f1 || echo '未知')"
    echo "修改时间: $(stat -c %y $OVERRIDE_CONFIG_FILE 2>/dev/null | cut -d'.' -f1 || echo '未知')"
    
    echo ""
    echo -e "${YELLOW}💡 提示: 所有配置修改将应用到 $OVERRIDE_CONFIG_FILE${RESET}"
    echo "建议编辑内容:"
    echo "- LLM配置 (ChatGLM等API密钥)"
    echo "- ASR配置 (阿里云等语音识别服务)"
    echo "- TTS配置 (EdgeTTS等语音合成服务)"
}

# ========================= ASR 配置（15个服务商） =========================
config_asr() {
    local return_to_main=false
    
    while [ "$return_to_main" = false ]; do
        echo -e "\n${GREEN}【1/5】配置 ASR (语音识别) 服务${RESET}"
        echo "请选择ASR服务商（共15个）："
        echo " 0) ${YELLOW} 返回上一步 ${RESET}"
        
        # 根据内存状态显示本地ASR模型的颜色提示
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
            echo -e " 1) ${RED}FunASR (本地)${RESET} ${RED}❌ 内存不足 (${MEM_TOTAL}GB < 4GB) - 无法部署${RESET}"
            echo " 2) FunASRServer (独立部署)"
            echo -e " 3) ${RED}SherpaASR (本地，多语言)${RESET} ${RED}❌ 内存不足 - 无法部署${RESET}"
            echo -e " 4) ${RED}SherpaParaformerASR (本地，中文专用)${RESET} ${RED}❌ 内存不足 - 无法部署${RESET}"
            echo " 5) DoubaoASR (火山引擎，按次收费)"
            echo " 6) DoubaoStreamASR (火山引擎，按时收费)"
            echo " 7) TencentASR (腾讯云)"
            echo " 8) AliyunASR (阿里云，批量处理)"
            echo " 9) AliyunStreamASR (阿里云，实时流式) [推荐]"
            echo "10) BaiduASR (百度智能云)"
            echo "11) OpenaiASR (OpenAI)"
            echo "12) GroqASR (Groq)"
            echo -e "13) ${GREEN}VoskASR (本地，完全离线)${RESET} ${GREEN}✅ 内存占用较小 (建议≥2GB)，可选择${RESET}"
        fi
        echo " 14) Qwen3ASRFlash (通义千问)"
        echo " 15) XunfeiStreamASR (讯飞，流式)"
        
        read -r -p "请输入序号 (默认推荐 9，输入0返回上一步): " asr_choice
        asr_choice=${asr_choice:-9}
        
        # 处理返回上一步
        if [ "$asr_choice" = "0" ]; then
            return_to_main=true
            continue
        fi

    local asr_provider_key
    case $asr_choice in
        1)
            asr_provider_key="FunASR"
            if [ "$IS_MEMORY_SUFFICIENT" = false ]; then
                echo -e "\n${RED}❌ 由于内存不足，无法选择FunASR本地模型，请重新选择其他ASR服务商${RESET}"
                config_asr
                return
            fi
            echo -e "\n${GREEN}✅ 已选择本地模型 FunASR。${RESET}"
            echo -e "${CYAN}ℹ️  系统将自动配置 model_dir 为 models/SenseVoiceSmall。${RESET}"
            echo -e "\n${CYAN}📥 正在下载 SenseVoiceSmall ASR 模型... 这可能需要几分钟。${RESET}"
            retry_exec "curl -fSL $LOCAL_ASR_MODEL_URL -o $MAIN_DIR/models/SenseVoiceSmall/model.pt" "下载 ASR 模型"
            
            sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    model_dir: .*/    model_dir: models/SenseVoiceSmall/" "$OVERRIDE_CONFIG_FILE"
            ;;
        2)
            asr_provider_key="FunASRServer"
            echo -e "\n${YELLOW}⚠️  您选择了独立部署 FunASRServer。${RESET}"
            echo -e "${CYAN}ℹ️  请先按照以下步骤部署FunASR服务：${RESET}"
            echo -e "  1. mkdir -p ./funasr-runtime-resources/models"
            echo -e "  2. sudo docker run -p 10096:10095 -it --privileged=true -v \$PWD/funasr-runtime-resources/models:/workspace/models registry.cn-hangzhou.aliyuncs.com/funasr_repo/funasr:funasr-runtime-sdk-online-cpu-0.1.12"
            echo -e "  3. 进入容器后：cd FunASR/runtime"
            echo -e "  4. nohup bash run_server_2pass.sh --download-model-dir /workspace/models --vad-dir damo/speech_fsmn_vad_zh-cn-16k-common-onnx --model-dir damo/speech_paraformer-large-vad-punc_asr_nat-zh-cn-16k-common-vocab8404-onnx --online-model-dir damo/speech_paraformer-large_asr_nat-zh-cn-16k-common-vocab8404-online-onnx --punc-dir damo/punc_ct-transformer_zh-cn-common-vad_realtime-vocab272727-onnx --lm-dir damo/speech_ngram_lm_zh-cn-ai-wesp-fst --itn-dir thuduj12/fst_itn_zh > log.txt 2>&1 &"
            read -r -p "请输入 FunASRServer 服务地址 (默认 127.0.0.1:10096): " host_port
            host_port=${host_port:-"127.0.0.1:10096"}
            host=$(echo "$host_port" | cut -d':' -f1)
            port=$(echo "$host_port" | cut -d':' -f2)
            
            sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    type: .*/    type: fun_server/" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    host: .*/    host: $host/" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    port: .*/    port: $port/" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    is_ssl: .*/    is_ssl: true/" "$OVERRIDE_CONFIG_FILE"
            ;;
        3)
            asr_provider_key="SherpaASR"
            if [ "$IS_MEMORY_SUFFICIENT" = false ]; then
                echo -e "\n${RED}❌ 由于内存不足，无法选择SherpaASR本地模型，请重新选择其他ASR服务商${RESET}"
                config_asr
                return
            fi
            echo -e "\n${YELLOW}⚠️  您选择了 SherpaASR (本地多语言)。${RESET}"
            echo -e "${CYAN}ℹ️  请手动下载模型：https://github.com/k2-fsa/sherpa-onnx/releases${RESET}"
            echo -e "${CYAN}ℹ️  推荐模型：sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17${RESET}"
            read -r -p "请输入模型路径 (默认 models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17): " model_path
            model_path=${model_path:-"models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17"}
            
            sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    type: .*/    type: sherpa_onnx_local/" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s|^    model_dir: .*|    model_dir: $model_path|" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    model_type: .*/    model_type: sense_voice/" "$OVERRIDE_CONFIG_FILE"
            ;;
        4)
            asr_provider_key="SherpaParaformerASR"
            if [ "$IS_MEMORY_SUFFICIENT" = false ]; then
                echo -e "\n${RED}❌ 由于内存不足，无法选择SherpaParaformerASR本地模型，请重新选择其他ASR服务商${RESET}"
                config_asr
                return
            fi
            echo -e "\n${YELLOW}⚠️  您选择了 SherpaParaformerASR (本地中文专用)。${RESET}"
            echo -e "${CYAN}ℹ️  请手动下载模型：https://github.com/k2-fsa/sherpa-onnx/releases${RESET}"
            echo -e "${CYAN}ℹ️  推荐模型：sherpa-onnx-paraformer-zh-small-2024-03-09${RESET}"
            read -r -p "请输入模型路径 (默认 models/sherpa-onnx-paraformer-zh-small-2024-03-09): " model_path
            model_path=${model_path:-"models/sherpa-onnx-paraformer-zh-small-2024-03-09"}
            
            sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    type: .*/    type: sherpa_onnx_local/" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s|^    model_dir: .*|    model_dir: $model_path|" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    model_type: .*/    model_type: paraformer/" "$OVERRIDE_CONFIG_FILE"
            ;;
        5)
            asr_provider_key="DoubaoASR"
            echo -e "\n${YELLOW}⚠️  您选择了火山引擎 DoubaoASR (按次收费)。${RESET}"
            echo -e "${CYAN}🔑 密钥获取地址：https://console.volcengine.com/speech/app${RESET}"
            read -r -p "请输入 AppID: " appid
            read -r -p "请输入 Access Token: " access_token
            
            sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    type: .*/    type: doubao/" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    appid: .*/    appid: $appid/" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    access_token: .*/    access_token: $access_token/" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    cluster: .*/    cluster: volcengine_input_common/" "$OVERRIDE_CONFIG_FILE"
            ;;
        6)
            asr_provider_key="DoubaoStreamASR"
            echo -e "\n${YELLOW}⚠️  您选择了火山引擎 DoubaoStreamASR (按时收费)。${RESET}"
            echo -e "${CYAN}🔑 密钥获取地址：https://console.volcengine.com/speech/app${RESET}"
            echo -e "${CYAN}ℹ️  开通地址：https://console.volcengine.com/speech/service/10011${RESET}"
            read -r -p "请输入 AppID: " appid
            read -r -p "请输入 Access Token: " access_token
            
            sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    type: .*/    type: doubao_stream/" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    appid: .*/    appid: $appid/" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    access_token: .*/    access_token: $access_token/" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    cluster: .*/    cluster: volcengine_input_common/" "$OVERRIDE_CONFIG_FILE"
            ;;
        7)
            asr_provider_key="TencentASR"
            echo -e "\n${YELLOW}⚠️  您选择了腾讯云 ASR。${RESET}"
            echo -e "${CYAN}🔑 密钥获取地址：https://console.cloud.tencent.com/cam/capi${RESET}"
            echo -e "${CYAN}ℹ️  免费领取资源：https://console.cloud.tencent.com/asr/resourcebundle${RESET}"
            read -r -p "请输入 Secret ID: " secret_id
            read -r -p "请输入 Secret Key: " secret_key
            
            sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    secret_id: .*/    secret_id: $secret_id/" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    secret_key: .*/    secret_key: $secret_key/" "$OVERRIDE_CONFIG_FILE"
            ;;
        8)
            asr_provider_key="AliyunASR"
            echo -e "\n${YELLOW}⚠️  您选择了阿里云 ASR (批量处理)。${RESET}"
            echo -e "${CYAN}🔑 平台地址：https://nls-portal.console.aliyun.com/${RESET}"
            echo -e "${CYAN}🔑 Appkey地址：https://nls-portal.console.aliyun.com/applist${RESET}"
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
            echo -e "\n${YELLOW}⚠️  您选择了阿里云实时流式 ASR。${RESET}"
            echo -e "${CYAN}🔑 平台地址：https://nls-portal.console.aliyun.com/${RESET}"
            echo -e "${CYAN}🔑 Appkey地址：https://nls-portal.console.aliyun.com/applist${RESET}"
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
            echo -e "\n${YELLOW}⚠️  您选择了百度智能云 ASR。${RESET}"
            echo -e "${CYAN}🔑 密钥获取地址：https://console.bce.baidu.com/ai-engine/old/#/ai/speech/app/list${RESET}"
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
        11)
            asr_provider_key="OpenaiASR"
            echo -e "\n${YELLOW}⚠️  您选择了 OpenAI ASR。${RESET}"
            echo -e "${CYAN}🔑 密钥获取地址：https://platform.openai.com/settings/organization/api-keys${RESET}"
            read -r -p "请输入 API Key: " api_key
            read -r -p "请输入 代理地址 (选填，例如 http://127.0.0.1:10808): " http_proxy
            
            sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: $api_key/" "$OVERRIDE_CONFIG_FILE"
            [ -n "$http_proxy" ] && sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    http_proxy: .*/    http_proxy: $http_proxy/" "$OVERRIDE_CONFIG_FILE"
            ;;
        12)
            asr_provider_key="GroqASR"
            echo -e "\n${YELLOW}⚠️  您选择了 Groq ASR。${RESET}"
            echo -e "${CYAN}🔑 密钥获取地址：https://console.groq.com/keys${RESET}"
            read -r -p "请输入 API Key: " api_key
            read -r -p "请输入 代理地址 (选填，例如 http://127.0.0.1:10808): " http_proxy
            
            sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: $api_key/" "$OVERRIDE_CONFIG_FILE"
            [ -n "$http_proxy" ] && sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    http_proxy: .*/    http_proxy: $http_proxy/" "$OVERRIDE_CONFIG_FILE"
            ;;
        13)
            asr_provider_key="VoskASR"
            echo -e "\n${YELLOW}⚠️  您选择了 Vosk ASR (完全离线)。${RESET}"
            echo -e "${CYAN}ℹ️  模型下载地址：https://alphacephei.com/vosk/models${RESET}"
            echo -e "${CYAN}ℹ️  推荐中文模型：vosk-model-small-cn-0.22${RESET}"
            read -r -p "请输入模型路径 (默认 models/vosk/vosk-model-small-cn-0.22): " model_path
            model_path=${model_path:-"models/vosk/vosk-model-small-cn-0.22"}
            
            sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s|^    model_path: .*|    model_path: $model_path|" "$OVERRIDE_CONFIG_FILE"
            ;;
        14)
            asr_provider_key="Qwen3ASRFlash"
            echo -e "\n${YELLOW}⚠️  您选择了通义千问 Qwen3ASRFlash。${RESET}"
            echo -e "${CYAN}🔑 密钥获取地址：https://bailian.console.aliyun.com/#/api-key${RESET}"
            read -r -p "请输入 API Key: " api_key
            api_key="${api_key:-}"
            
            sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$OVERRIDE_CONFIG_FILE"
            if [ -n "$api_key" ]; then
                sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
            fi
            ;;
        15)
            asr_provider_key="XunfeiStreamASR"
            echo -e "\n${YELLOW}⚠️  您选择了讯飞流式 ASR。${RESET}"
            echo -e "${CYAN}🔑 平台地址：https://www.xfyun.cn/${RESET}"
            read -r -p "请输入 APPID: " appid
            appid="${appid:-}"
            read -r -p "请输入 APIKey: " api_key
            api_key="${api_key:-}"
            read -r -p "请输入 APISecret: " api_secret
            api_secret="${api_secret:-}"
            
            sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$OVERRIDE_CONFIG_FILE"
            if [ -n "$appid" ]; then
                sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    appid: .*/    appid: \"$appid\"/" "$OVERRIDE_CONFIG_FILE"
            fi
            if [ -n "$api_key" ]; then
                sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
            fi
            if [ -n "$api_secret" ]; then
                sed -i "/^  $asr_provider_key:/,/^  [A-Za-z]/ s/^    api_secret: .*/    api_secret: \"$api_secret\"/" "$OVERRIDE_CONFIG_FILE"
            fi
            ;;
        *)
            asr_provider_key="AliyunStreamASR"
            echo -e "\n${YELLOW}⚠️  输入无效，默认选择推荐的 AliyunStreamASR。${RESET}"
            sed -i "/^  ASR: /c\  ASR: $asr_provider_key" "$OVERRIDE_CONFIG_FILE"
            ;;
    esac
    
    # 完成选择后退出循环
    return_to_main=true
    done
}

# ========================= LLM 配置（19个服务商） =========================
config_llm() {
    local return_to_main=false
    
    while [ "$return_to_main" = false ]; do
        echo -e "\n\n${GREEN}【2/5】配置 LLM (大语言模型) 服务${RESET}"
    echo "请选择LLM服务商（共19个）："
    echo " 0) ${YELLOW} 返回上一步 ${RESET}"
    echo " 1) AliLLM (通义千问)"
    echo " 2) AliAppLLM (阿里云百炼)"
    echo " 3) DoubaoLLM (火山引擎)"
    echo " 4) DeepSeekLLM (DeepSeek)"
    echo " 5) ChatGLMLLM (智谱清言) [推荐]"
    echo " 6) OllamaLLM (本地部署)"
    echo " 7) DifyLLM (Dify)"
    echo " 8) GeminiLLM (谷歌)"
    echo " 9) CozeLLM (Coze)"
    echo "10) VolcesAiGatewayLLM (火山引擎边缘网关)"
    echo "11) LMStudioLLM (LM Studio)"
    echo "12) HomeAssistant (Home Assistant)"
    echo "13) FastgptLLM (FastGPT)"
    echo "14) XinferenceLLM (Xinference)"
    echo "15) XinferenceSmallLLM (Xinference轻量版)"
    echo "16) QwenVLVLLM (通义千问视觉)"
    echo "17) XunfeiSparkLLM (讯飞星火)"
    echo "18) XunfeiSparkLLM (讯飞星火Lite)"
    echo "19) CustomLLM (自定义接口)"
    
    read -r -p "请输入序号 (默认推荐 5，输入0返回上一步): " llm_choice
    llm_choice=${llm_choice:-5}
    
    # 处理返回上一步
    if [ "$llm_choice" = "0" ]; then
        config_asr
        continue
    fi

    local llm_provider_key
    case $llm_choice in
        1)
            llm_provider_key="AliLLM"
            echo -e "\n${YELLOW}⚠️  您选择了通义千问 AliLLM。${RESET}"
            echo -e "${CYAN}🔑 密钥获取地址：https://bailian.console.aliyun.com/#/api-key${RESET}"
            read -r -p "请输入 API Key: " api_key
            api_key="${api_key:-}"
            
            sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$OVERRIDE_CONFIG_FILE"
            if [ -n "$api_key" ]; then
                sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
            fi
            ;;
        2)
            llm_provider_key="AliAppLLM"
            echo -e "\n${YELLOW}⚠️  您选择了阿里云百炼 AliAppLLM。${RESET}"
            echo -e "${CYAN}🔑 密钥获取地址：https://bailian.console.aliyun.com/#/api-key${RESET}"
            read -r -p "请输入 App ID: " app_id
            app_id="${app_id:-}"
            read -r -p "请输入 API Key: " api_key
            api_key="${api_key:-}"
            
            sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$OVERRIDE_CONFIG_FILE"
            if [ -n "$app_id" ]; then
                sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    app_id: .*/    app_id: \"$app_id\"/" "$OVERRIDE_CONFIG_FILE"
            fi
            if [ -n "$api_key" ]; then
                sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
            fi
            ;;
        3)
            llm_provider_key="DoubaoLLM"
            echo -e "\n${YELLOW}⚠️  您选择了火山引擎 DoubaoLLM。${RESET}"
            echo -e "${CYAN}🔑 开通地址：https://console.volcengine.com/ark/region:ark+cn-beijing/openManagement${RESET}"
            echo -e "${CYAN}🔑 密钥获取地址：https://console.volcengine.com/ark/region:ark+cn-beijing/apiKey${RESET}"
            read -r -p "请输入 API Key: " api_key
            api_key="${api_key:-}"
            
            sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$OVERRIDE_CONFIG_FILE"
            if [ -n "$api_key" ]; then
                sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
            fi
            ;;
        4)
            llm_provider_key="DeepSeekLLM"
            echo -e "\n${YELLOW}⚠️  您选择了 DeepSeekLLM。${RESET}"
            echo -e "${CYAN}🔑 密钥获取地址：https://platform.deepseek.com/${RESET}"
            read -r -p "请输入 API Key: " api_key
            api_key="${api_key:-}"
            
            sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$OVERRIDE_CONFIG_FILE"
            if [ -n "$api_key" ]; then
                sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
            fi
            ;;
        5)
            llm_provider_key="ChatGLMLLM"
            echo -e "\n${YELLOW}⚠️  您选择了智谱清言 ChatGLMLLM。${RESET}"
            echo -e "${CYAN}🔑 密钥获取地址：https://bigmodel.cn/usercenter/proj-mgmt/apikeys${RESET}"
            read -r -p "请输入 API Key: " api_key
            api_key="${api_key:-}"
            
            CHATGLM_API_KEY="$api_key"
            
            sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$OVERRIDE_CONFIG_FILE"
            if [ -n "$api_key" ]; then
                sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
            fi
            ;;
        6)
            llm_provider_key="OllamaLLM"
            echo -e "\n${YELLOW}⚠️  您选择了 OllamaLLM (本地部署)。${RESET}"
            echo -e "${CYAN}ℹ️  请先使用 ollama pull 下载模型${RESET}"
            read -r -p "请输入模型名称 (默认 qwen2.5): " model_name
            model_name=${model_name:-"qwen2.5"}
            read -r -p "请输入 Ollama 服务地址 (默认 http://localhost:11434): " base_url
            base_url=${base_url:-"http://localhost:11434"}
            
            sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    model_name: .*/    model_name: $model_name/" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s|^    base_url: .*|    base_url: $base_url|" "$OVERRIDE_CONFIG_FILE"
            ;;
        7)
            llm_provider_key="DifyLLM"
            echo -e "\n${YELLOW}⚠️  您选择了 DifyLLM。${RESET}"
            echo -e "${CYAN}🔑 密钥获取地址：https://cloud.tryfastgpt.ai/account/apikey${RESET}"
            read -r -p "请输入 API Key: " api_key
            api_key="${api_key:-}"
            
            sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$OVERRIDE_CONFIG_FILE"
            if [ -n "$api_key" ]; then
                sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
            fi
            ;;
        8)
            llm_provider_key="GeminiLLM"
            echo -e "\n${YELLOW}⚠️  您选择了谷歌 GeminiLLM。${RESET}"
            echo -e "${YELLOW}⚠️  国内用户需配置代理才能访问。${RESET}"
            echo -e "${CYAN}🔑 密钥获取地址：https://aistudio.google.com/apikey${RESET}"
            read -r -p "请输入 API Key: " api_key
            read -r -p "请输入 代理地址 (例如 http://127.0.0.1:10808, 直接回车可留空): " http_proxy
            
            sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$OVERRIDE_CONFIG_FILE"
            if [ -n "$api_key" ]; then
                sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
            fi
            [ -n "$http_proxy" ] && sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    http_proxy: .*/    http_proxy: $http_proxy/" "$OVERRIDE_CONFIG_FILE"
            ;;
        9)
            llm_provider_key="CozeLLM"
            echo -e "\n${YELLOW}⚠️  您选择了 CozeLLM。${RESET}"
            echo -e "${CYAN}🔑 密钥获取地址：https://www.coze.cn/open/oauth/pats${RESET}"
            read -r -p "请输入 API Key: " api_key
            read -r -p "请输入 Bot ID: " bot_id
            
            sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$OVERRIDE_CONFIG_FILE"
            if [ -n "$api_key" ]; then
                sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
            fi
            [ -n "$bot_id" ] && sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    bot_id: .*/    bot_id: $bot_id/" "$OVERRIDE_CONFIG_FILE"
            ;;
        10)
            llm_provider_key="VolcesAiGatewayLLM"
            echo -e "\n${YELLOW}⚠️  您选择了火山引擎边缘网关。${RESET}"
            echo -e "${CYAN}🔑 开通地址：https://console.volcengine.com/vei/aigateway/${RESET}"
            echo -e "${CYAN}🔑 密钥获取地址：https://console.volcengine.com/vei/aigateway/tokens-list${RESET}"
            read -r -p "请输入 API Key: " api_key
            api_key="${api_key:-}"
            
            sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$OVERRIDE_CONFIG_FILE"
            if [ -n "$api_key" ]; then
                sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
            fi
            ;;
        11)
            llm_provider_key="LMStudioLLM"
            echo -e "\n${YELLOW}⚠️  您选择了 LMStudioLLM。${RESET}"
            echo -e "${CYAN}ℹ️  请先在LM Studio下载模型${RESET}"
            read -r -p "请输入模型名称 (默认 TheBloke/Mistral-7B-Instruct-v0.2-GGUF): " model_name
            model_name=${model_name:-"TheBloke/Mistral-7B-Instruct-v0.2-GGUF"}
            read -r -p "请输入 LM Studio 服务地址 (默认 http://localhost:1234): " base_url
            base_url=${base_url:-"http://localhost:1234"}
            
            sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    model_name: .*/    model_name: $model_name/" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s|^    base_url: .*|    base_url: $base_url|" "$OVERRIDE_CONFIG_FILE"
            ;;
        12)
            llm_provider_key="HomeAssistant"
            echo -e "\n${YELLOW}⚠️  您选择了 HomeAssistant。${RESET}"
            read -r -p "请输入 Home Assistant 地址 (默认 http://homeassistant.local:8123): " base_url
            base_url=${base_url:-"http://homeassistant.local:8123"}
            read -r -p "请输入 Agent ID (默认 conversation.chatgpt): " agent_id
            agent_id=${agent_id:-"conversation.chatgpt"}
            read -r -p "请输入 API 令牌: " api_key
            api_key="${api_key:-}"
            
            sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s|^    base_url: .*|    base_url: $base_url|" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    agent_id: .*/    agent_id: $agent_id/" "$OVERRIDE_CONFIG_FILE"
            if [ -n "$api_key" ]; then
                sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
            fi
            ;;
        13)
            llm_provider_key="FastgptLLM"
            echo -e "\n${YELLOW}⚠️  您选择了 FastgptLLM。${RESET}"
            echo -e "${CYAN}🔑 密钥获取地址：https://cloud.tryfastgpt.ai/account/apikey${RESET}"
            read -r -p "请输入 API Key: " api_key
            read -r -p "请输入 服务地址 (默认 https://host/api/v1): " base_url
            base_url=${base_url:-"https://host/api/v1"}
            
            sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s|^    base_url: .*|    base_url: $base_url|" "$OVERRIDE_CONFIG_FILE"
            if [ -n "$api_key" ]; then
                sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
            fi
            ;;
        14)
            llm_provider_key="XinferenceLLM"
            echo -e "\n${YELLOW}⚠️  您选择了 XinferenceLLM。${RESET}"
            echo -e "${CYAN}ℹ️  请先在Xinference启动对应模型${RESET}"
            read -r -p "请输入模型名称 (默认 qwen2.5:72b-AWQ): " model_name
            model_name=${model_name:-"qwen2.5:72b-AWQ"}
            read -r -p "请输入服务地址 (默认 http://localhost:9997): " base_url
            base_url=${base_url:-"http://localhost:9997"}
            
            sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    model_name: .*/    model_name: $model_name/" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s|^    base_url: .*|    base_url: $base_url|" "$OVERRIDE_CONFIG_FILE"
            ;;
        15)
            llm_provider_key="XinferenceSmallLLM"
            echo -e "\n${YELLOW}⚠️  您选择了 XinferenceSmallLLM (轻量版)。${RESET}"
            echo -e "${CYAN}ℹ️  请先在Xinference启动对应模型${RESET}"
            read -r -p "请输入模型名称 (默认 qwen2.5:3b-AWQ): " model_name
            model_name=${model_name:-"qwen2.5:3b-AWQ"}
            read -r -p "请输入服务地址 (默认 http://localhost:9997): " base_url
            base_url=${base_url:-"http://localhost:9997"}
            
            sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    model_name: .*/    model_name: $model_name/" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s|^    base_url: .*|    base_url: $base_url|" "$OVERRIDE_CONFIG_FILE"
            ;;
        16)
            llm_provider_key="QwenVLVLLM"
            echo -e "\n${YELLOW}⚠️  您选择了通义千问 QwenVLVLLM (视觉)。${RESET}"
            echo -e "${CYAN}🔑 密钥获取地址：https://bailian.console.aliyun.com/#/api-key${RESET}"
            read -r -p "请输入 API Key: " api_key
            api_key="${api_key:-}"
            
            sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$OVERRIDE_CONFIG_FILE"
            if [ -n "$api_key" ]; then
                sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
            fi
            ;;
        17)
            llm_provider_key="XunfeiSparkLLM"
            echo -e "\n${YELLOW}⚠️  您选择了讯飞星火 XunfeiSparkLLM。${RESET}"
            echo -e "${CYAN}🔑 开通地址：https://console.xfyun.cn/app/myapp${RESET}"
            read -r -p "请输入 API Key: " api_key
            api_key="${api_key:-}"
            
            sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$OVERRIDE_CONFIG_FILE"
            if [ -n "$api_key" ]; then
                sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
            fi
            ;;
        18)
            llm_provider_key="XunfeiSparkLLM"
            echo -e "\n${YELLOW}⚠️  您选择了讯飞星火 Lite。${RESET}"
            echo -e "${CYAN}🔑 开通地址：https://console.xfyun.cn/services/cbm${RESET}"
            read -r -p "请输入 API Key: " api_key
            api_key="${api_key:-}"
            
            sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$OVERRIDE_CONFIG_FILE"
            if [ -n "$api_key" ]; then
                sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
            fi
            ;;
        19)
            llm_provider_key="CustomLLM"
            echo -e "\n${YELLOW}⚠️  您选择了自定义 LLM。${RESET}"
            read -r -p "请输入类型 (openai/ollama/dify，默认 openai): " type
            type=${type:-"openai"}
            read -r -p "请输入服务地址: " base_url
            read -r -p "请输入 API Key: " api_key
            read -r -p "请输入模型名称: " model_name
            
            sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    type: .*/    type: $type/" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s|^    base_url: .*|    base_url: $base_url|" "$OVERRIDE_CONFIG_FILE"
            if [ -n "$api_key" ]; then
                sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
            fi
            [ -n "$model_name" ] && sed -i "/^  $llm_provider_key:/,/^  [A-Za-z]/ s/^    model_name: .*/    model_name: $model_name/" "$OVERRIDE_CONFIG_FILE"
            ;;
        *)
            llm_provider_key="ChatGLMLLM"
            echo -e "\n${YELLOW}⚠️  输入无效，默认选择推荐的 ChatGLMLLM。${RESET}"
            sed -i "/^  LLM: /c\  LLM: $llm_provider_key" "$OVERRIDE_CONFIG_FILE"
            ;;
    esac
    
    # 完成选择后退出循环
    return_to_main=true
    done
}

# ========================= VLLM 配置（2个服务商） =========================
config_vllm() {
    local return_to_main=false
    
    while [ "$return_to_main" = false ]; do
        echo -e "\n\n${GREEN}【3/5】配置 VLLM (视觉语言大模型) 服务${RESET}"
        echo "请选择VLLM服务商（共2个）："
        echo " 0) ${YELLOW} 返回上一步 ${RESET}"
        echo " 1) ChatGLMVLLM (智谱清言) [推荐]"
        echo " 2) QwenVLVLLM (通义千问)"
        
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
            echo -e "\n${YELLOW}⚠️  您选择了智谱清言 ChatGLMVLLM。${RESET}"
            
            if [ -n "$CHATGLM_API_KEY" ]; then
                echo -e "${GREEN}✅ 检测到您已在LLM配置中输入了智谱清言API Key，将自动应用到VLLM配置中，无需重复输入。${RESET}"
                api_key="$CHATGLM_API_KEY"
            else
                echo -e "${CYAN}🔑 密钥获取地址：https://bigmodel.cn/usercenter/proj-mgmt/apikeys${RESET}"
                read -r -p "请输入 API Key: " api_key
            fi
            
            sed -i "/^  VLLM: /c\  VLLM: $vllm_provider_key" "$OVERRIDE_CONFIG_FILE"
            [ -n "$api_key" ] && sed -i "/^  $vllm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: $api_key/" "$OVERRIDE_CONFIG_FILE"
            ;;
        2)
            vllm_provider_key="QwenVLVLLM"
            echo -e "\n${YELLOW}⚠️  您选择了通义千问 QwenVLVLLM。${RESET}"
            echo -e "${CYAN}🔑 密钥获取地址：https://bailian.console.aliyun.com/#/api-key${RESET}"
            read -r -p "请输入 API Key: " api_key
            api_key="${api_key:-}"
            
            sed -i "/^  VLLM: /c\  VLLM: $vllm_provider_key" "$OVERRIDE_CONFIG_FILE"
            if [ -n "$api_key" ]; then
                sed -i "/^  $vllm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
            fi
            ;;
        *)
            vllm_provider_key="ChatGLMVLLM"
            echo -e "\n${YELLOW}⚠️  输入无效，默认选择推荐的 ChatGLMVLLM。${RESET}"
            
            if [ -n "$CHATGLM_API_KEY" ]; then
                echo -e "${GREEN}✅ 检测到您已在LLM配置中输入了智谱清言API Key，将自动应用到VLLM配置中。${RESET}"
                api_key="$CHATGLM_API_KEY"
            else
                echo -e "${CYAN}🔑 密钥获取地址：https://bigmodel.cn/usercenter/proj-mgmt/apikeys${RESET}"
                read -r -p "请输入 API Key: " api_key
            fi
            
            sed -i "/^  VLLM: /c\  VLLM: $vllm_provider_key" "$OVERRIDE_CONFIG_FILE"
            [ -n "$api_key" ] && sed -i "/^  $vllm_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: $api_key/" "$OVERRIDE_CONFIG_FILE"
            ;;
    esac
    
    # 完成选择后退出循环
    return_to_main=true
    done
}

# ========================= TTS 配置（23个服务商） =========================
config_tts() {
    local return_to_main=false
    
    while [ "$return_to_main" = false ]; do
        echo -e "\n\n${GREEN}【4/5】配置 TTS (文本转语音) 服务${RESET}"
        echo "请选择TTS服务商（共23个）："
        echo " 0) ${YELLOW} 返回上一步 ${RESET}"
        echo " 1) EdgeTTS (微软) [推荐]"
    echo " 2) DoubaoTTS (火山引擎)"
    echo " 3) HuoshanDoubleStreamTTS (火山双向流式)"
    echo " 4) CosyVoiceSiliconflow (硅基流动)"
    echo " 5) CozeCnTTS (Coze)"
    echo " 6) VolcesAiGatewayTTS (火山边缘网关)"
    echo " 7) FishSpeech (FishSpeech)"
    echo " 8) GPT_SOVITS_V2 (GPT-SoVITS V2)"
    echo " 9) GPT_SOVITS_V3 (GPT-SoVITS V3)"
    echo "10) MinimaxTTSHTTPStream (Minimax)"
    echo "11) AliyunTTS (阿里云)"
    echo "12) AliyunStreamTTS (阿里云流式)"
    echo "13) TencentTTS (腾讯云)"
    echo "14) TTS302AI (302AI)"
    echo "15) GizwitsTTS (机智云)"
    echo "16) ACGNTTS (ACGN)"
    echo "17) OpenAITTS (OpenAI)"
    echo "18) CustomTTS (自定义接口)"
    echo "19) LinkeraiTTS (LinkerAI)"
    echo "20) PaddleSpeechTTS (百度飞桨)"
    echo "21) IndexStreamTTS (Index-TTS-vLLM)"
    echo "22) AliBLTTS (阿里云百炼)"
    echo "23) XunFeiTTS (讯飞)"
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
            echo -e "${CYAN}ℹ️  支持多种语音，默认使用 zh-CN-XiaoxiaoNeural${RESET}"
            read -r -p "请输入语音名称 (默认 zh-CN-XiaoxiaoNeural): " voice
            voice=${voice:-"zh-CN-XiaoxiaoNeural"}
            
            sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    voice: .*/    voice: $voice/" "$OVERRIDE_CONFIG_FILE"
            ;;
        2)
            tts_provider_key="DoubaoTTS"
            echo -e "\n${YELLOW}⚠️  您选择了火山引擎 DoubaoTTS。${RESET}"
            echo -e "${CYAN}🔑 开通地址：https://console.volcengine.com/speech/service/8${RESET}"
            read -r -p "请输入 AppID: " appid
            read -r -p "请输入 Access Token: " access_token
            
            sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    appid: .*/    appid: $appid/" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    access_token: .*/    access_token: $access_token/" "$OVERRIDE_CONFIG_FILE"
            ;;
        3)
            tts_provider_key="HuoshanDoubleStreamTTS"
            echo -e "\n${YELLOW}⚠️  您选择了火山双向流式 TTS。${RESET}"
            echo -e "${CYAN}🔑 开通地址：https://console.volcengine.com/speech/service/10007${RESET}"
            read -r -p "请输入 AppID: " appid
            read -r -p "请输入 Access Token: " access_token
            
            sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    appid: .*/    appid: $appid/" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    access_token: .*/    access_token: $access_token/" "$OVERRIDE_CONFIG_FILE"
            ;;
        4)
            tts_provider_key="CosyVoiceSiliconflow"
            echo -e "\n${YELLOW}⚠️  您选择了硅基流动 CosyVoice。${RESET}"
            echo -e "${CYAN}🔑 密钥获取地址：https://cloud.siliconflow.cn/account/ak${RESET}"
            echo -e "${CYAN}ℹ️  将使用配置文件默认的模型和音色配置${RESET}"
            read -r -p "请输入 Access Key: " access_key
            
            sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    access_token: .*/    access_token: $access_key/" "$OVERRIDE_CONFIG_FILE"
            ;;
        5)
            tts_provider_key="CozeCnTTS"
            echo -e "\n${YELLOW}⚠️  您选择了 CozeCnTTS。${RESET}"
            echo -e "${CYAN}🔑 密钥获取地址：https://www.coze.cn/open/oauth/pats${RESET}"
            read -r -p "请输入 个人访问令牌: " access_token
            
            sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    access_token: .*/    access_token: $access_token/" "$OVERRIDE_CONFIG_FILE"
            ;;
        6)
            tts_provider_key="VolcesAiGatewayTTS"
            echo -e "\n${YELLOW}⚠️  您选择了火山边缘网关 TTS。${RESET}"
            echo -e "${CYAN}🔑 开通地址：https://console.volcengine.com/vei/aigateway/${RESET}"
            read -r -p "请输入 API Key: " api_key
            
            sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: $api_key/" "$OVERRIDE_CONFIG_FILE"
            ;;
        7)
            tts_provider_key="FishSpeech"
            echo -e "\n${YELLOW}⚠️  您选择了 FishSpeech。${RESET}"
            echo -e "${CYAN}ℹ️  需自行部署 FishSpeech 服务${RESET}"
            read -r -p "请输入服务地址 (默认 http://localhost:8000): " base_url
            base_url=${base_url:-"http://localhost:8000"}
            
            sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s|^    base_url: .*|    base_url: $base_url|" "$OVERRIDE_CONFIG_FILE"
            ;;
        8)
            tts_provider_key="GPT_SOVITS_V2"
            echo -e "\n${YELLOW}⚠️  您选择了 GPT-SoVITS V2。${RESET}"
            echo -e "${CYAN}ℹ️  需自行部署 GPT-SoVITS V2 服务${RESET}"
            read -r -p "请输入服务地址 (默认 http://localhost:9880): " base_url
            base_url=${base_url:-"http://localhost:9880"}
            
            sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s|^    base_url: .*|    base_url: $base_url|" "$OVERRIDE_CONFIG_FILE"
            ;;
        9)
            tts_provider_key="GPT_SOVITS_V3"
            echo -e "\n${YELLOW}⚠️  您选择了 GPT-SoVITS V3。${RESET}"
            echo -e "${CYAN}ℹ️  需自行部署 GPT-SoVITS V3 服务${RESET}"
            read -r -p "请输入服务地址 (默认 http://localhost:9881): " base_url
            base_url=${base_url:-"http://localhost:9881"}
            
            sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s|^    base_url: .*|    base_url: $base_url|" "$OVERRIDE_CONFIG_FILE"
            ;;
        10)
            tts_provider_key="MinimaxTTSHTTPStream"
            echo -e "\n${YELLOW}⚠️  您选择了 Minimax TTS。${RESET}"
            echo -e "${CYAN}🔑 密钥获取地址：https://minimax.chat/${RESET}"
            read -r -p "请输入 Group ID: " group_id
            group_id="${group_id:-}"
            read -r -p "请输入 API Key: " api_key
            api_key="${api_key:-}"
            
            sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
            if [ -n "$group_id" ]; then
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    group_id: .*/    group_id: \"$group_id\"/" "$OVERRIDE_CONFIG_FILE"
            fi
            if [ -n "$api_key" ]; then
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
            fi
            ;;
        11)
            tts_provider_key="AliyunTTS"
            echo -e "\n${YELLOW}⚠️  您选择了阿里云 TTS。${RESET}"
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
            echo -e "\n${YELLOW}⚠️  您选择了阿里云流式 TTS。${RESET}"
            echo -e "${CYAN}🔑 开通地址：https://nls-portal.console.aliyun.com/${RESET}"
            read -r -p "请输入 Appkey: " appkey
            read -r -p "请输入 Access Key ID: " access_key_id
            read -r -p "请输入 Access Key Secret: " access_key_secret
            
            sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    appkey: .*/    appkey: $appkey/" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    access_key_id: .*/    access_key_id: $access_key_id/" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    access_key_secret: .*/    access_key_secret: $access_key_secret/" "$OVERRIDE_CONFIG_FILE"
            ;;
        13)
            tts_provider_key="TencentTTS"
            echo -e "\n${YELLOW}⚠️  您选择了腾讯云 TTS。${RESET}"
            echo -e "${CYAN}🔑 开通地址：https://console.cloud.tencent.com/tts${RESET}"
            read -r -p "请输入 Secret ID: " secret_id
            read -r -p "请输入 Secret Key: " secret_key
            
            sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    secret_id: .*/    secret_id: $secret_id/" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    secret_key: .*/    secret_key: $secret_key/" "$OVERRIDE_CONFIG_FILE"
            ;;
        14)
            tts_provider_key="TTS302AI"
            echo -e "\n${YELLOW}⚠️  您选择了 302AI TTS。${RESET}"
            echo -e "${CYAN}🔑 密钥获取地址：https://www.302ai.com/${RESET}"
            read -r -p "请输入 Access Token: " access_token
            
            sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    access_token: .*/    access_token: $access_token/" "$OVERRIDE_CONFIG_FILE"
            ;;
        15)
            tts_provider_key="GizwitsTTS"
            echo -e "\n${YELLOW}⚠️  您选择了机智云 TTS。${RESET}"
            echo -e "${CYAN}🔑 开通地址：https://www.gizwits.com/${RESET}"
            read -r -p "请输入 Access Token: " access_token
            
            sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    access_token: .*/    access_token: $access_token/" "$OVERRIDE_CONFIG_FILE"
            ;;
        16)
            tts_provider_key="ACGNTTS"
            echo -e "\n${YELLOW}⚠️  您选择了 ACGN TTS。${RESET}"
            echo -e "${CYAN}ℹ️  需自行部署 ACGN TTS 服务${RESET}"
            read -r -p "请输入服务地址 (默认 http://localhost:8080): " base_url
            base_url=${base_url:-"http://localhost:8080"}
            
            sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s|^    base_url: .*|    base_url: $base_url|" "$OVERRIDE_CONFIG_FILE"
            ;;
        17)
            tts_provider_key="OpenAITTS"
            echo -e "\n${YELLOW}⚠️  您选择了 OpenAI TTS。${RESET}"
            echo -e "${CYAN}🔑 密钥获取地址：https://platform.openai.com/settings/organization/api-keys${RESET}"
            read -r -p "请输入 API Key: " api_key
            api_key="${api_key:-}"
            read -r -p "请输入 代理地址 (选填): " http_proxy
            http_proxy="${http_proxy:-}"
            
            sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
            if [ -n "$api_key" ]; then
                sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: \"$api_key\"/" "$OVERRIDE_CONFIG_FILE"
            fi
            [ -n "$http_proxy" ] && sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    http_proxy: .*/    http_proxy: \"$http_proxy\"/" "$OVERRIDE_CONFIG_FILE"
            ;;
        18)
            tts_provider_key="CustomTTS"
            echo -e "\n${YELLOW}⚠️  您选择了自定义 TTS。${RESET}"
            read -r -p "请输入类型 (edge/doubao/aliyun 等): " type
            read -r -p "请输入服务地址: " base_url
            read -r -p "请输入 API Key (选填): " api_key
            read -r -p "请输入 音色 (选填): " voice
            
            sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    type: .*/    type: $type/" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s|^    base_url: .*|    base_url: $base_url|" "$OVERRIDE_CONFIG_FILE"
            [ -n "$api_key" ] && sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: $api_key/" "$OVERRIDE_CONFIG_FILE"
            [ -n "$voice" ] && sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    voice: .*/    voice: $voice/" "$OVERRIDE_CONFIG_FILE"
            ;;
        19)
            tts_provider_key="LinkeraiTTS"
            echo -e "\n${YELLOW}⚠️  您选择了 LinkerAI TTS。${RESET}"
            echo -e "${CYAN}🔑 密钥获取地址：https://www.linkerai.com/${RESET}"
            read -r -p "请输入 Access Token: " access_token
            
            sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    access_token: .*/    access_token: $access_token/" "$OVERRIDE_CONFIG_FILE"
            ;;
        20)
            tts_provider_key="PaddleSpeechTTS"
            echo -e "\n${YELLOW}⚠️  您选择了百度飞桨 PaddleSpeech TTS。${RESET}"
            echo -e "${CYAN}ℹ️  需自行部署 PaddleSpeech 服务${RESET}"
            read -r -p "请输入服务地址 (默认 http://localhost:8001): " base_url
            base_url=${base_url:-"http://localhost:8001"}
            
            sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s|^    base_url: .*|    base_url: $base_url|" "$OVERRIDE_CONFIG_FILE"
            ;;
        21)
            tts_provider_key="IndexStreamTTS"
            echo -e "\n${YELLOW}⚠️  您选择了 Index-TTS-vLLM。${RESET}"
            echo -e "${CYAN}ℹ️  需自行部署 Index-TTS-vLLM 服务${RESET}"
            read -r -p "请输入服务地址 (默认 http://localhost:7860): " base_url
            base_url=${base_url:-"http://localhost:7860"}
            
            sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s|^    base_url: .*|    base_url: $base_url|" "$OVERRIDE_CONFIG_FILE"
            ;;
        22)
            tts_provider_key="AliBLTTS"
            echo -e "\n${YELLOW}⚠️  您选择了阿里云百炼 TTS。${RESET}"
            echo -e "${CYAN}🔑 密钥获取地址：https://bailian.console.aliyun.com/#/api-key${RESET}"
            read -r -p "请输入 API Key: " api_key
            
            sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
            sed -i "/^  $tts_provider_key:/,/^  [A-Za-z]/ s/^    api_key: .*/    api_key: $api_key/" "$OVERRIDE_CONFIG_FILE"
            ;;
        23)
            tts_provider_key="XunFeiTTS"
            echo -e "\n${YELLOW}⚠️  您选择了讯飞 TTS。${RESET}"
            echo -e "${CYAN}🔑 开通地址：https://www.xfyun.cn/services/tts${RESET}"
            read -r -p "请输入 APP ID: " app_id
            app_id="${app_id:-}"
            read -r -p "请输入 API Secret: " api_secret
            api_secret="${api_secret:-}"
            read -r -p "请输入 API Key: " api_key
            api_key="${api_key:-}"
            
            sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
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
            echo -e "\n${YELLOW}⚠️  输入无效，默认选择微软 EdgeTTS。${RESET}"
            sed -i "/^  TTS: /c\  TTS: $tts_provider_key" "$OVERRIDE_CONFIG_FILE"
            ;;
    esac
    
    # 完成选择后退出循环
    return_to_main=true
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
            echo -e "\n${YELLOW}⚠️  您选择了本地短记忆。${RESET}"
            sed -i "/^  Memory: /c\  Memory: $memory_provider_key" "$OVERRIDE_CONFIG_FILE"
            ;;
        3)
            memory_provider_key="mem0ai"
            echo -e "\n${YELLOW}⚠️  您选择了 Mem0AI。${RESET}"
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
            echo -e "\n${YELLOW}⚠️  输入无效，默认选择不开启记忆功能。${RESET}"
            sed -i "/^  Memory: /c\  Memory: $memory_provider_key" "$OVERRIDE_CONFIG_FILE"
            ;;
    esac
    
    # 完成选择后退出循环
    return_to_main=true
    done
}

config_server() {
    echo -e "\n\n${GREEN}【6/6】配置服务器地址 (自动生成，无需手动填写)${RESET}"

    echo -e "${CYAN}ℹ️  检测到您的服务器地址：${RESET}"
    echo -e "  - 内网IP：$INTERNAL_IP"
    echo -e "  - 公网IP：$EXTERNAL_IP"

    echo -e "\n${YELLOW}⚠️  请选择部署场景（影响地址生成）：${RESET}"
    echo "1) Docker部署（仅内网访问，用内网IP）"
    echo "2) 公网部署（外网访问，用公网IP，需提前配置端口映射）"
    read -r -p "请输入序号 (默认1): " deploy_choice
    deploy_choice=${deploy_choice:-1}

    local ws_ip
    local vision_ip
    local deploy_type_color
    local deploy_type_icon
    local deploy_description
    local ota_url
    
    case $deploy_choice in
        1)
            ws_ip="$INTERNAL_IP"
            vision_ip="$INTERNAL_IP"
            deploy_type_color="${GREEN}"
            deploy_type_icon="✅"
            deploy_description="Docker内网部署"
            ota_url="http://$INTERNAL_IP:8003/xiaozhi/ota/"
            CURRENT_DEPLOY_TYPE="internal"
            echo -e "${GREEN}✅ 已选择Docker内网部署，将使用内网IP生成地址${RESET}"
            ;;
        2)
            ws_ip="$EXTERNAL_IP"
            vision_ip="$EXTERNAL_IP"
            deploy_type_color="${YELLOW}"
            deploy_type_icon="⚠️"
            deploy_description="公网部署"
            ota_url="http://$EXTERNAL_IP:8003/xiaozhi/ota/"
            CURRENT_DEPLOY_TYPE="public"
            echo -e "${GREEN}✅ 已选择公网部署，将使用公网IP生成地址${RESET}"
            echo -e "${YELLOW}⚠️  注意：请确保路由器已配置端口映射（8000端口用于WebSocket，8003端口用于OTA/视觉接口）${RESET}"
            ;;
        *)
            ws_ip="$INTERNAL_IP"
            vision_ip="$INTERNAL_IP"
            deploy_type_color="${RED}"
            deploy_type_icon="❌"
            deploy_description="默认Docker内网部署"
            ota_url="http://$INTERNAL_IP:8003/xiaozhi/ota/"
            CURRENT_DEPLOY_TYPE="internal"
            echo -e "${YELLOW}⚠️  输入无效，默认选择Docker内网部署${RESET}"
            ;;
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
    
    while [ "$return_to_main" = false ]; do
        echo -e "\n${PURPLE}==================================================${RESET}"
        echo -e "${CYAN}🔧  开始进行核心服务配置  🔧${RESET}"
        echo -e "${PURPLE}==================================================${RESET}"

        echo -e "\n${YELLOW}⚠️  注意：若您计划使用本地ASR模型（如FunASR），请确保服务器内存≥4G。${RESET}"
        echo "1) 现在通过脚本配置密钥和服务商"
        echo "2) 稍后手动填写所有配置（脚本将预设在线服务商以避免启动报错）"
        echo "0) 退出配置（将使用默认配置）"
        read -r -p "请选择（默认1，输入0退出配置）：" key_choice
        key_choice=${key_choice:-1}
        
        # 处理退出配置
        if [ "$key_choice" = "0" ]; then
            echo -e "\n${YELLOW}⚠️  确认退出详细配置流程？${RESET}"
            echo -e "${CYAN}ℹ️  退出后将使用以下默认配置：${RESET}"
            echo -e "${CYAN}  - ASR: AliyunStreamASR (阿里云流式)${RESET}"
            echo -e "${CYAN}  - LLM: ChatGLMLLM (智谱清言)${RESET}"
            echo -e "${CYAN}  - VLLM: ChatGLMVLLM (智谱清言)${RESET}"
            echo -e "${CYAN}  - TTS: EdgeTTS (微软)${RESET}"
            echo -e "${CYAN}  - Memory: nomem (无记忆)${RESET}"
            echo -e "${CYAN}ℹ️  默认配置路径：$OVERRIDE_CONFIG_FILE${RESET}"
            echo ""
            read -r -p "确认退出详细配置流程？(y/n，默认y): " confirm_exit
            confirm_exit=${confirm_exit:-y}
            
            if [[ "$confirm_exit" == "y" || "$confirm_exit" == "Y" ]]; then
                echo -e "${GREEN}✅ 已使用默认配置，脚本将继续执行...${RESET}"
                
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
            else
                echo -e "${GREEN}✅ 继续详细配置流程...${RESET}"
                continue
            fi
        fi

        if [[ "$key_choice" == "2" ]]; then
            echo -e "\n${YELLOW}⚠️  已选择稍后手动填写。${RESET}"
            echo -e "${CYAN}ℹ️  为防止服务启动失败，脚本将自动将服务商预设为 \"AliyunStreamASR\" 和 \"ChatGLMLLM\"。${RESET}"
            echo -e "${CYAN}ℹ️  您可以稍后在配置文件中修改为您喜欢的服务商。配置文件路径：$OVERRIDE_CONFIG_FILE${RESET}"
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

        config_asr
        config_llm
        config_vllm
        config_tts
        config_memory
        config_server

        echo -e "\n${PURPLE}==================================================${RESET}"
        echo -e "${GREEN}🎉 核心服务配置完成！${RESET}"
        echo -e "${CYAN}ℹ️  详细配置文件已保存至: $OVERRIDE_CONFIG_FILE${RESET}"
        echo -e "${PURPLE}==================================================${RESET}"
        export KEY_CONFIG_MODE="auto"
        
        # 完成配置后退出循环
        return_to_main=true
    done
}

# ========================= 服务启动 =========================
start_service() {
  echo -e "\n${BLUE}🚀 开始启动服务...${RESET}"
  cd "$MAIN_DIR" || { echo -e "${RED}❌ 进入目录 $MAIN_DIR 失败${RESET}"; exit 1; }
  retry_exec "docker compose up -d" "启动Docker服务"
  
  echo -e "${CYAN}🔍 正在检查服务状态...${RESET}"
  sleep 5

  if docker ps --filter "name=^/${CONTAINER_NAME}$" --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
    echo -e "\n${GREEN}🎉 小智服务器启动成功！${RESET}"
    [[ "${KEY_CONFIG_MODE:-manual}" == "manual" ]] && {
      echo -e "${YELLOW}⚠️  您选择了手动配置，请尽快编辑配置文件：$OVERRIDE_CONFIG_FILE${RESET}"
      echo -e "${YELLOW}⚠️  配置完成后，请重启服务：docker restart $CONTAINER_NAME${RESET}"
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
    echo -e "${GREEN}OTA接口（当前部署类型 - 内网访问）：${BOLD}http://$INTERNAL_IP:8003/xiaozhi/ota/${RESET}"
    echo -e "${YELLOW}💡 您的当前部署类型为内网访问，请使用上述OTA地址进行设备配置${RESET}"
    echo -e "${YELLOW}💡 如果需要从公网访问，请确保路由器已配置端口映射（8000, 8003）${RESET}"
  elif [ "$CURRENT_DEPLOY_TYPE" = "public" ]; then
    echo -e "${YELLOW}OTA接口（当前部署类型 - 公网访问）：${BOLD}http://$EXTERNAL_IP:8003/xiaozhi/ota/${RESET}"
    echo -e "${YELLOW}💡 您的当前部署类型为公网访问，请使用上述OTA地址进行设备配置${RESET}"
    echo -e "${YELLOW}💡 确保路由器已配置端口映射（8000, 8003）${RESET}"
  else
    echo -e "${YELLOW}💡 请根据您的部署方式选择相应的OTA地址${RESET}"
  fi
  
  echo -e "${PURPLE}==================================================${RESET}"
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
            unsupported_msg="macOS"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            unsupported_msg="Windows"
            ;;
        *)
            unsupported_msg="未知系统 ($os_kernel)"
            ;;
    esac
    
    if [ "$is_supported" = false ]; then
        echo -e "${RED}==================================================${RESET}"
        echo -e "${RED}⚠️  警告：本脚本不适用于 $unsupported_msg 系统${RESET}"
        echo -e "${RED}⚠️  当前系统信息：$os_info${RESET}"
        echo -e "${RED}⚠️  强制执行可能导致未知错误，请谨慎操作！${RESET}"
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
            echo -e "${YELLOW}⚠️  检测到 UFW 防火墙已启用${RESET}"
            echo -e "${CYAN}💡 建议开放以下端口：${RESET}"
            echo -e "  - sudo ufw allow 8000  # WebSocket 服务"
            echo -e "  - sudo ufw allow 8003  # OTA/视觉接口服务"
            read -r -p "是否现在开放这些端口？(y/n，默认n): " open_ports
            open_ports=${open_ports:-n}
            if [[ "$open_ports" == "y" || "$open_ports" == "Y" ]]; then
                sudo ufw allow 8000 && sudo ufw allow 8003
                echo -e "${GREEN}✅ 端口已开放${RESET}"
            else
                echo -e "${CYAN}ℹ️  端口未开放，请根据需要手动配置${RESET}"
            fi
        fi
    fi
    
    # 检查 firewalld 状态
    if command -v firewall-cmd &> /dev/null; then
        if systemctl is-active --quiet firewalld; then
            echo -e "${YELLOW}⚠️  检测到 Firewalld 防火墙已启用${RESET}"
            echo -e "${CYAN}💡 建议开放以下端口：${RESET}"
            echo -e "  - sudo firewall-cmd --permanent --add-port=8000/tcp"
            echo -e "  - sudo firewall-cmd --permanent --add-port=8003/tcp"
            echo -e "  - sudo firewall-cmd --reload"
            echo -e "${CYAN}ℹ️  请根据上述命令手动配置防火墙${RESET}"
        fi
    fi
    
    echo -e "${GREEN}✅ 防火墙检查完成${RESET}"
}

# ========================= 主执行函数 =========================
main() {
    check_system
    check_dependencies
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
    download_files
    config_keys
    check_firewall
    start_service
    show_connection_info

    echo -e "\n${PURPLE}==================================================${RESET}"
    echo -e "${GREEN}🎊  小智服务器部署成功！！ 🎊 ${RESET}"
    echo -e "${GREEN}🥳🥳🥳 请尽情使用吧 🥳🥳🥳
    echo -e "${PURPLE}==================================================${RESET}"
}

# 启动主函数
main "$@"
