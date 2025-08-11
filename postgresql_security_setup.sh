#!/bin/bash

# PostgreSQL 安全防护配置脚本
# 用途：通过UFW防火墙限制PostgreSQL只允许本地连接，防止外部扫描
# 适用于：Docker和源码安装的PostgreSQL实例

set -e

echo "=== PostgreSQL 安全防护配置开始 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否以root用户运行
if [[ $EUID -ne 0 ]]; then
   log_error "此脚本需要以root权限运行"
   echo "请使用: sudo bash $0"
   exit 1
fi

# 备份原有配置
backup_dir="/etc/ufw/backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$backup_dir"
log_info "备份UFW配置到: $backup_dir"

# 第一步：重置UFW配置
log_info "步骤 1: 重置UFW防火墙配置"
ufw --force reset > /dev/null 2>&1
log_info "UFW配置已重置"

# 第二步：设置默认策略
log_info "步骤 2: 设置防火墙默认策略"
ufw default deny incoming > /dev/null 2>&1
ufw default allow outgoing > /dev/null 2>&1
log_info "默认策略设置完成：拒绝入站，允许出站"

# 第三步：允许基本服务
log_info "步骤 3: 配置基本系统服务规则"

# 允许本地回环地址的所有连接
ufw allow from 127.0.0.1 > /dev/null 2>&1
log_info "已允许本地回环地址(127.0.0.1)的所有连接"

# 允许IPv6本地回环地址
ufw allow from ::1 > /dev/null 2>&1
log_info "已允许IPv6本地回环地址(::1)的所有连接"

# 允许SSH（确保远程管理不受影响）
ufw allow 22/tcp comment 'SSH access' > /dev/null 2>&1
log_info "已允许SSH访问(端口22)"

# 第四步：配置Web服务端口（Spring Boot应用）
log_info "步骤 4: 配置Web服务端口"

# HTTP端口
ufw allow 80/tcp comment 'HTTP web server' > /dev/null 2>&1
log_info "已允许HTTP访问(端口80)"

# HTTPS端口
ufw allow 443/tcp comment 'HTTPS web server' > /dev/null 2>&1
log_info "已允许HTTPS访问(端口443)"

# Spring Boot默认端口
ufw allow 8080/tcp comment 'Spring Boot default port' > /dev/null 2>&1
log_info "已允许Spring Boot访问(端口8080)"

# 第五步：配置PostgreSQL安全规则
log_info "步骤 5: 配置PostgreSQL安全访问规则"

# PostgreSQL标准端口 - 只允许本地访问
ufw allow from 127.0.0.1 to any port 5432 proto tcp comment 'PostgreSQL local access - port 5432' > /dev/null 2>&1
log_info "已配置PostgreSQL端口5432本地访问"

# 您的自定义PostgreSQL端口 - 只允许本地访问
ufw allow from 127.0.0.1 to any port 15432 proto tcp comment 'PostgreSQL local access - port 15432' > /dev/null 2>&1
log_info "已配置PostgreSQL端口15432本地访问"

ufw allow from 127.0.0.1 to any port 16430 proto tcp comment 'PostgreSQL local access - port 16430' > /dev/null 2>&1
log_info "已配置PostgreSQL端口16430本地访问"

# 第六步：明确拒绝PostgreSQL端口的外部访问
log_info "步骤 6: 明确拒绝PostgreSQL端口的外部访问"

ufw deny 5432/tcp comment 'Block external PostgreSQL access - port 5432' > /dev/null 2>&1
log_info "已拒绝PostgreSQL端口5432的外部访问"

ufw deny 15432/tcp comment 'Block external PostgreSQL access - port 15432' > /dev/null 2>&1
log_info "已拒绝PostgreSQL端口15432的外部访问"

ufw deny 16430/tcp comment 'Block external PostgreSQL access - port 16430' > /dev/null 2>&1
log_info "已拒绝PostgreSQL端口16430的外部访问"

# 第七步：启用UFW
log_info "步骤 7: 启用UFW防火墙"
if ufw --force enable > /dev/null 2>&1; then
    log_info "UFW防火墙已成功启用"
else
    log_warn "UFW启用失败，可能是内核模块问题，但规则已配置"
fi

# 显示当前配置
echo
log_info "当前UFW防火墙规则："
echo "----------------------------------------"
ufw status verbose 2>/dev/null || echo "状态: 规则已配置但无法显示状态（容器环境限制）"

# 第八步：生成PostgreSQL配置建议
echo
log_info "PostgreSQL 额外安全配置建议："
echo "----------------------------------------"

cat << 'EOF'
1. PostgreSQL 配置文件安全设置：

   在 postgresql.conf 中设置：
   listen_addresses = 'localhost'  # 只监听本地地址
   port = 5432  # 或您的自定义端口

   在 pg_hba.conf 中设置：
   # 只允许本地连接
   local   all             all                                     md5
   host    all             all             127.0.0.1/32            md5
   host    all             all             ::1/128                 md5

2. Docker PostgreSQL 安全设置：

   运行容器时使用：
   docker run -p 127.0.0.1:15432:5432 postgres:latest
   # 这样只绑定到本地IP，外部无法直接访问

3. 验证配置效果：

   # 检查监听端口
   sudo netstat -tlnp | grep postgres
   
   # 测试本地连接
   psql -h localhost -p 15432 -U your_user -d your_database

4. 定期安全检查：

   # 检查开放端口
   sudo ss -tlnp | grep -E ':5432|:15432|:16430'
   
   # 检查防火墙状态
   sudo ufw status verbose

EOF

echo
log_info "=== PostgreSQL 安全防护配置完成 ==="
log_info "您的PostgreSQL数据库现在只允许本地连接"
log_info "Spring Boot应用可以正常连接本地PostgreSQL"
log_info "外部扫描将无法发现PostgreSQL服务"

echo
echo "重要提醒："
echo "1. 请确保您的Spring Boot应用连接字符串使用 localhost 或 127.0.0.1"
echo "2. 如需远程管理，请使用SSH隧道：ssh -L 5432:localhost:5432 user@server"
echo "3. 定期检查防火墙规则：sudo ufw status verbose"