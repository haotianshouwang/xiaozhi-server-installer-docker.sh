# 小智服务器部署脚本介绍文档

## 概述

**小智服务器部署脚本**是一个功能强大的Docker自动化部署工具，专门用于快速部署和配置xiaozhi-server语音AI服务器。该脚本支持一键部署、智能系统检测、交互式配置和完整的容器管理功能。

## 为什么写这个脚本？
- 因为我见到了太多的小白不会部署了（大佬救命啊 大佬这个怎么部署啊 佬！救命！），所以写了这个脚本，使用ai辅助（**@豆包** **@minimax**），同时这个脚本也是**我自己第一个作品，如果有bug请多多包涵**并提交**Issue**和**Pull Request**来改进这个脚本。
- 如果你还有什么奇奇怪怪的想法想加进脚本欢迎PR！

## 功能特性

### 🔧 核心功能
- **一键Docker部署**：自动安装Docker和Docker Compose
- **智能系统检测**：自动检测系统兼容性和资源状况
- **交互式配置**：提供用户友好的配置界面
- **配置文件支持**：支持阿里云、腾讯云、百度、OpenAI等15种api配置文件配置
- **本地模型支持**：支持FunASR、SherpaASR、VoskASR等本地语音识别模型的配置
- **完整容器管理**：安装、启动、停止、重启、日志查看、连接测试
- **完整服务器监控**：查看cpu、内存、gpu、网络的详细监控

### 最低要求
- **操作系统**：Linux（Ubuntu 18.04+, CentOS 7+, Debian 9+）
- **内存**：最低2GB，推荐4GB+
- **磁盘空间**：至少10GB可用空间
- **权限**：需要root权限或sudo权限
- **网络**：稳定的互联网连接

### 推荐配置
- **内存**：8GB+（支持本地ASR模型）
- **CPU**：4核心+处理器
- **磁盘**：50GB+ SSD存储
- **网络**：100Mbps+带宽

### 支持的系统
- ✅ Ubuntu 18.04/20.04/22.04/24.04
- ✅ CentOS 7/8/9
- ✅ Debian 9/10/11/12
- ✅ Fedora 35+
- ⚠️ 其他Linux发行版（需要手动调整）

## 安装前准备

### 1. 权限准备
```bash
# 确保有sudo权限
sudo -v

# 或者使用root权限
sudo bash xiaozhi-server-installer-docker.sh
```

### 2. 网络检查
确保可以访问以下地址：
- GitHub（代码仓库）
- GitHub Proxy（国内加速）
- 各种云服务API地址

### 3. 端口准备
脚本会使用以下端口，请确保未被占用：
- **8000**：主服务端口
- **8003**：WebSocket端口

## 执行指令

### 方式一：通过 curl 或 wget 下载并执行（一行命令）

### 使用 curl
```bash
curl -fsSL https://gh-proxy.com/https://raw.githubusercontent.com/haotianshouwang/xiaozhi-server-installer-docker.sh/refs/heads/main/xiaozhi-server-installer-docker.sh | sudo tee /tmp/xiaozhi-installer.sh > /dev/null && sudo bash /tmp/xiaozhi-installer.sh
```

### 使用 wget
```bash
wget -qO- https://gh-proxy.com/https://raw.githubusercontent.com/haotianshouwang/xiaozhi-server-installer-docker.sh/refs/heads/main/xiaozhi-server-installer-docker.sh | sudo tee /tmp/xiaozhi-installer.sh > /dev/null && sudo bash /tmp/xiaozhi-installer.sh
```

### 方式二：管道执行
```bash
# 直接通过管道执行，无需下载文件
curl -fsSL https://gh-proxy.org/https://raw.githubusercontent.com/haotianshouwang/xiaozhi-server-installer-docker.sh/refs/heads/main/xiaozhi-server-installer-docker.sh| sudo bash
```

```bash
# 备用加速站点
curl -fsSL https://gh.llkk.cc/https://raw.githubusercontent.com/haotianshouwang/xiaozhi-server-installer-docker.sh/refs/heads/main/xiaozhi-server-installer-docker.sh | sudo bash
```

```bash
# GitHub 链接
curl -fsSL https://raw.githubusercontent.com/haotianshouwang/xiaozhi-server-installer-docker.sh/refs/heads/main/xiaozhi-server-installer-docker.sh | sudo bash
```

### 方式三：下载后执行
```bash
# 1. 下载脚本
curl -O https://gh-proxy.org/https://raw.githubusercontent.com/haotianshouwang/xiaozhi-server-installer-docker.sh/refs/heads/main/xiaozhi-server-installer-docker.sh

# 2. 添加执行权限
chmod +x xiaozhi-server-installer-docker.sh

# 3. 以root权限执行
sudo ./xiaozhi-server-installer-docker.sh
```
```bash
#备用加速站点
# 1. 下载脚本
curl -O https://gh.llkk.cc/https://raw.githubusercontent.com/haotianshouwang/xiaozhi-server-installer-docker.sh/refs/heads/main/xiaozhi-server-installer-docker.sh

# 2. 添加执行权限
chmod +x xiaozhi-server-installer-docker.sh

# 3. 以root权限执行
sudo ./xiaozhi-server-installer-docker.sh
```

```bash
# GitHub链接
# 1. 下载脚本
curl -O https://raw.githubusercontent.com/haotianshouwang/xiaozhi-server-installer-docker.sh/refs/heads/main/xiaozhi-server-installer-docker.sh

# 2. 添加执行权限
chmod +x xiaozhi-server-installer-docker.sh

# 3. 以root权限执行
sudo ./xiaozhi-server-installer-docker.sh
```

### 方式四：国内用户加速版
```bash
# 使用GitHub Proxy加速下载
curl -fsSL https://gh-proxy.com/https://raw.githubusercontent.com/haotianshouwang/xiaozhi-server-installer-docker.sh/refs/heads/main/xiaozhi-server-installer-docker.sh | sudo bash
```


## 部署流程

### 1. 启动部署
执行脚本后，脚本会自动：
- 检查root权限
- 检测系统兼容性
- 安装必要依赖
- 显示交互式菜单

### 2. 选择部署类型
脚本提供以下选项：
- **全新部署**：删除现有配置，重新部署
- **更新服务器**：保留配置，更新到最新版本
- **仅修改配置**：不下载服务器文件
- **测试连接**：测试服务器连通性
- **查看日志**：查看Docker容器日志

### 3. 配置ASR服务
- 选择适合的语音识别服务
- 本地服务需要4GB+内存
- 云端服务需要相应的API密钥

### 4. 配置TTS服务
- 选择语音合成服务
- 配置语音参数和音色

### 5. 配置LLM服务
- 选择大语言模型
- 配置模型参数和API设置

### 6. 启动服务
脚本会自动：
- 拉取Docker镜像
- 创建和启动容器
- 配置网络和端口
- 初始化配置文件

## 常用管理命令

### 启动服务
```bash
cd ~/xiaozhi-server
docker-compose up -d
```

### 停止服务
```bash
cd ~/xiaozhi-server
docker-compose down
```

### 查看服务状态
```bash
docker ps | grep xiaozhi
```

### 查看日志
```bash
docker logs xiaozhi-esp32-server
```

### 重启服务
```bash
docker restart xiaozhi-esp32-server
```

### 完全卸载
```bash
# 在脚本中选择"删除服务器"选项
# 或手动执行：
docker stop xiaozhi-esp32-server
docker rm xiaozhi-esp32-server
docker rmi xiaozhi-esp32-server
rm -rf ~/xiaozhi-server
```

## 故障排除

### 常见问题

#### 1. 权限不足
```bash
# 错误信息：权限不足，无法继续部署
# 解决方案：
sudo bash xiaozhi-server-installer-docker.sh
```

#### 2. 网络连接问题
```bash
# 错误信息：下载失败或连接超时
# 解决方案：
# 1. 检查网络连接
# 2. 使用国内镜像加速
# 3. 配置代理（如果需要）
```

#### 3. 内存不足
```错误信息：内存不足 无法使用
# 解决方案：
# 1. 选择云端ASR服务（选项6-15）
# 2. 升级服务器内存到4GB+
# 3. 关闭其他占用内存的程序
```

#### 4. 端口被占用
```bash
# 错误信息：端口8000/8003已被占用
# 解决方案：
# 1. 检查端口占用：netstat -tulpn | grep : 8000
# 2. 停止占用端口的服务
# 3. 修改docker-compose.yml中的端口映射
```

#### 5. Docker未安装
```bash
# 错误信息：Docker未安装
# 解决方案：
# 脚本会自动安装Docker，如果失败请手动安装：
curl -fsSL https://get.docker.com | bash
```

### 日志分析

#### 查看详细日志
```bash
# 进入脚本菜单，选择"查看Docker日志"
# 或直接使用命令：
docker logs --tail 100 xiaozhi-esp32-server
```

#### 常见日志信息
- `INFO`：正常服务信息
- `WARN`：警告信息
- `ERROR`：错误信息 出大红了（
## 配置说明

### 配置文件位置
- **主配置**：`~/xiaozhi-server/data/.config.yaml`
- **Docker配置**：`~/xiaozhi-server/docker-compose.yml`
- **日志文件**：Docker容器日志

### 环境变量配置
```bash
# 设置代理（如果需要）
export http_proxy=http://proxy:port
export https_proxy=http://proxy:port

# 设置阿里云访问密钥
export ALIBABA_CLOUD_ACCESS_KEY_ID=your_key_id
export ALIBABA_CLOUD_ACCESS_KEY_SECRET=your_key_secret
```

## 安全建议

### 1. 网络安全
- 建议在防火墙后部署
- 使用HTTPS进行外部访问
- 定期更新系统和依赖包

### 2. API密钥安全
- 不要在公共场合分享API密钥
- 定期轮换访问密钥
- 使用最小权限原则

### 3. 容器安全
- 定期更新Docker镜像
- 监控容器运行状态
- 备份重要配置文件

## 性能优化

### 1. 内存优化
- 使用云端ASR服务减少本地内存占用
- 调整容器内存限制
- 关闭不必要的服务

### 2. 网络优化
- 使用CDN加速模型下载
- 优化API调用频率
- 启用连接池

### 3. 存储优化
- 使用SSD存储提升I/O性能
- 定期清理日志文件
- 压缩和归档历史数据

## 更新升级

### 1. 脚本更新
```bash
# 下载最新版本
curl -fsSL https://raw.githubusercontent.com/haotianshouwang/xiaozhi-server-installer-docker.sh/refs/heads/main/xiaozhi-server-installer-docker.sh | sudo bash
```

### 2. 服务更新
```bash
# 在脚本中选择"更新服务器"
# 或手动更新：
cd ~/xiaozhi-server
git pull
docker-compose up -d --force-recreate
```

### 3. 模型更新
```bash
# 删除旧模型文件，重新部署时脚本会自动下载最新模型
rm -rf ~/xiaozhi-server/models/*
```

## 技术支持

### 官方资源
- **GitHub仓库**：https://github.com/haotianshouwang/xiaozhi-server-installer-docker.sh
- **Docker Hub**：xiaozhi-esp32-server
- **问题反馈**：GitHub Issues

### 社区支持
- **技术交流群**：🐧 528866460
- **文档Wiki**：本文档
- **教程视频**：还没做（

### 常用链接
- **官方文档**：https://github.com/haotianshouwang/xiaozhi-server-installer-docker.sh/wiki
- **API文档**：各云服务商官方文档
- **Docker文档**：https://docs.docker.com

### 主要改进
- **内存管理**：智能检测服务器内存，自动显示合适的ASR选项
- **错误处理**：增强错误提示和恢复机制
- **用户体验**：优化菜单显示，提供清晰的状态反馈
- **性能优化**：减少不必要的网络请求和文件操作
- **兼容性**：改善跨Linux发行版的兼容性

## 许可证

本脚本遵循MIT许可证，详见LICENSE文件。

## 贡献指南

欢迎提交Issue和Pull Request来帮助改进这个项目！

---

**作者**：昊天兽王
**版本**：1.2.68
**更新日期**：2025-11-14  
**文档版本**：1.0
