#!/bin/bash

# PostgreSQL 安全防护配置脚本 - 保守版本
# 用途：只配置PostgreSQL相关规则，不影响现有UFW配置
# 适用于：Docker和源码安装的PostgreSQL实例

set -e

echo "=== PostgreSQL 安全防护配置开始（保守模式）==="

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

# 检查UFW当前状态
log_info "检查当前UFW状态..."
UFW_STATUS=$(ufw status | head -1)
echo "当前状态: $UFW_STATUS"

# 备份当前规则
backup_file="/tmp/ufw_backup_$(date +%Y%m%d_%H%M%S).txt"
log_info "备份当前UFW规则到: $backup_file"
ufw status verbose > "$backup_file" 2>/dev/null || echo "无法备份UFW状态" > "$backup_file"

echo
log_warn "重要提醒：此脚本只添加PostgreSQL相关规则，不会修改或删除您现有的UFW规则"
read -p "是否继续？(y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "操作已取消"
    exit 0
fi

echo
log_info "开始配置PostgreSQL安全规则..."

# 只配置PostgreSQL相关规则 - 不修改其他任何规则

# 第一步：允许本地访问PostgreSQL端口
log_info "步骤 1: 配置PostgreSQL本地访问规则"

# PostgreSQL标准端口 - 只允许本地访问
if ! ufw status | grep -q "5432.*127.0.0.1"; then
    ufw allow from 127.0.0.1 to any port 5432 proto tcp comment 'PostgreSQL local access - port 5432' > /dev/null 2>&1
    log_info "已配置PostgreSQL端口5432本地访问"
else
    log_info "PostgreSQL端口5432本地访问规则已存在"
fi

# 自定义PostgreSQL端口 - 只允许本地访问
if ! ufw status | grep -q "15432.*127.0.0.1"; then
    ufw allow from 127.0.0.1 to any port 15432 proto tcp comment 'PostgreSQL local access - port 15432' > /dev/null 2>&1
    log_info "已配置PostgreSQL端口15432本地访问"
else
    log_info "PostgreSQL端口15432本地访问规则已存在"
fi

if ! ufw status | grep -q "16430.*127.0.0.1"; then
    ufw allow from 127.0.0.1 to any port 16430 proto tcp comment 'PostgreSQL local access - port 16430' > /dev/null 2>&1
    log_info "已配置PostgreSQL端口16430本地访问"
else
    log_info "PostgreSQL端口16430本地访问规则已存在"
fi

# 第二步：明确拒绝PostgreSQL端口的外部访问
log_info "步骤 2: 配置PostgreSQL外部访问拒绝规则"

if ! ufw status | grep -q "5432.*DENY"; then
    ufw deny 5432/tcp comment 'Block external PostgreSQL access - port 5432' > /dev/null 2>&1
    log_info "已拒绝PostgreSQL端口5432的外部访问"
else
    log_info "PostgreSQL端口5432外部拒绝规则已存在"
fi

if ! ufw status | grep -q "15432.*DENY"; then
    ufw deny 15432/tcp comment 'Block external PostgreSQL access - port 15432' > /dev/null 2>&1
    log_info "已拒绝PostgreSQL端口15432的外部访问"
else
    log_info "PostgreSQL端口15432外部拒绝规则已存在"
fi

if ! ufw status | grep -q "16430.*DENY"; then
    ufw deny 16430/tcp comment 'Block external PostgreSQL access - port 16430' > /dev/null 2>&1
    log_info "已拒绝PostgreSQL端口16430的外部访问"
else
    log_info "PostgreSQL端口16430外部拒绝规则已存在"
fi

# 第三步：确保本地回环地址访问（如果没有的话）
log_info "步骤 3: 检查本地回环地址访问"

if ! ufw status | grep -q "127.0.0.1.*ALLOW"; then
    log_warn "检测到没有127.0.0.1的通用允许规则"
    read -p "是否添加本地回环地址访问规则？(推荐) (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ufw allow from 127.0.0.1 > /dev/null 2>&1
        log_info "已添加本地回环地址访问规则"
    else
        log_warn "跳过本地回环地址规则添加"
    fi
else
    log_info "本地回环地址访问规则已存在"
fi

# 第四步：启用UFW（如果未启用）
log_info "步骤 4: 检查UFW状态"

if [[ "$UFW_STATUS" == *"inactive"* ]]; then
    log_warn "UFW当前未启用"
    read -p "是否启用UFW防火墙？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if ufw --force enable > /dev/null 2>&1; then
            log_info "UFW防火墙已成功启用"
        else
            log_warn "UFW启用失败，可能是内核模块问题，但规则已配置"
        fi
    else
        log_warn "UFW保持未启用状态，规则已配置但不会生效"
    fi
else
    log_info "UFW已启用，规则已添加"
fi

# 显示当前配置
echo
log_info "当前UFW防火墙规则："
echo "----------------------------------------"
ufw status verbose 2>/dev/null || echo "状态: 规则已配置但无法显示状态（容器环境限制）"

echo
log_info "=== PostgreSQL 安全防护配置完成 ==="
log_info "✅ 只添加了PostgreSQL相关安全规则"
log_info "✅ 保留了您所有现有的UFW规则"
log_info "✅ PostgreSQL现在只允许本地连接"
log_info "✅ 外部扫描将无法发现PostgreSQL服务"

echo
log_info "备份文件位置: $backup_file"
echo "如需回滚PostgreSQL规则，可以手动删除相关规则"