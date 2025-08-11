#!/bin/bash

# PostgreSQL UFW 快速安全配置脚本
# 适用于已经运行PostgreSQL的系统，快速配置防火墙保护

echo "🔒 PostgreSQL UFW 快速安全配置"
echo "================================"

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo "❌ 错误：需要root权限，请使用: sudo $0"
   exit 1
fi

# 显示当前状态
echo "📊 当前UFW状态："
ufw status
echo ""

# 设置基础规则
echo "🛡️  配置基础防火墙规则..."

# 允许SSH（重要！）
ufw allow ssh >/dev/null 2>&1
echo "✅ 已允许SSH访问"

# 允许本地回环
ufw allow in on lo >/dev/null 2>&1
ufw allow out on lo >/dev/null 2>&1
echo "✅ 已允许本地回环接口"

# 配置PostgreSQL端口
PORTS=(5432 15432 16430)

echo ""
echo "🗄️  配置PostgreSQL端口安全访问..."

for port in "${PORTS[@]}"; do
    # 允许本地访问
    ufw allow from 127.0.0.1 to any port $port proto tcp comment "PostgreSQL local port $port" >/dev/null 2>&1
    ufw allow from ::1 to any port $port proto tcp comment "PostgreSQL IPv6 local port $port" >/dev/null 2>&1
    
    # 允许Docker网桥（如果存在）
    if command -v docker >/dev/null 2>&1; then
        ufw allow from 172.17.0.0/16 to any port $port proto tcp comment "PostgreSQL Docker port $port" >/dev/null 2>&1
        ufw allow from 172.18.0.0/16 to any port $port proto tcp comment "PostgreSQL Docker compose port $port" >/dev/null 2>&1
    fi
    
    # 拒绝外部访问
    ufw deny $port/tcp comment "Block external PostgreSQL port $port" >/dev/null 2>&1
    
    echo "✅ 端口 $port 已配置（仅本地访问）"
done

# 设置默认策略
echo ""
echo "⚙️  设置默认策略..."
ufw default deny incoming >/dev/null 2>&1
ufw default allow outgoing >/dev/null 2>&1
echo "✅ 默认策略：拒绝入站，允许出站"

# 启用UFW
echo ""
echo "🚀 启用UFW防火墙..."
ufw --force enable >/dev/null 2>&1

# 显示最终配置
echo ""
echo "📋 最终UFW配置："
echo "================================"
ufw status verbose

echo ""
echo "🎉 PostgreSQL UFW安全配置完成！"
echo ""
echo "🔐 安全效果："
echo "   ✓ PostgreSQL端口仅允许本地访问"
echo "   ✓ 外部扫描无法发现数据库服务"
echo "   ✓ 阻止所有远程PostgreSQL攻击"
echo "   ✓ Spring Boot应用可正常连接"
echo ""
echo "🧪 测试命令："
echo "   本地测试: telnet 127.0.0.1 5432"
echo "   外部测试: telnet [服务器IP] 5432 (应被拒绝)"
echo ""
echo "🚨 紧急禁用: sudo ufw disable"
echo "📊 查看日志: sudo tail -f /var/log/ufw.log"
echo ""
echo "================================"