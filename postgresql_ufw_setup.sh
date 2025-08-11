#!/bin/bash

# PostgreSQL 数据库 UFW 防火墙安全配置脚本
# 此脚本将配置UFW防火墙，只允许本地连接PostgreSQL数据库

echo "======================================="
echo "PostgreSQL UFW 防火墙安全配置开始"
echo "======================================="

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo "错误：此脚本需要root权限运行，请使用 sudo 执行"
   exit 1
fi

# 备份当前UFW配置
echo "1. 备份当前UFW配置..."
if [ -f /etc/ufw/ufw.conf ]; then
    cp /etc/ufw/ufw.conf /etc/ufw/ufw.conf.backup.$(date +%Y%m%d_%H%M%S)
    echo "   UFW配置已备份"
fi

# 重置UFW规则（谨慎操作）
echo "2. 重置UFW规则..."
echo "   注意：这将清除所有现有的UFW规则"
read -p "   是否继续？(y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "   操作取消"
    exit 1
fi

ufw --force reset

# 设置默认策略
echo "3. 设置默认策略..."
ufw default deny incoming
ufw default allow outgoing
echo "   已设置：拒绝所有入站连接，允许所有出站连接"

# 允许SSH连接（重要：防止被锁定）
echo "4. 允许SSH连接..."
ufw allow ssh
ufw allow 22/tcp
echo "   已允许：SSH连接（端口22）"

# 允许本地回环接口所有连接
echo "5. 允许本地回环接口连接..."
ufw allow in on lo
ufw allow out on lo
echo "   已允许：本地回环接口（lo）所有连接"

# PostgreSQL端口配置
POSTGRES_PORTS=(5432 15432 16430)

echo "6. 配置PostgreSQL端口访问控制..."
for port in "${POSTGRES_PORTS[@]}"; do
    echo "   配置端口 $port:"
    
    # 只允许本地IP连接
    ufw allow from 127.0.0.1 to any port $port proto tcp comment "PostgreSQL local access port $port"
    ufw allow from ::1 to any port $port proto tcp comment "PostgreSQL local IPv6 access port $port"
    
    # 如果有Docker，允许Docker网桥连接
    if command -v docker >/dev/null 2>&1; then
        ufw allow from 172.17.0.0/16 to any port $port proto tcp comment "PostgreSQL Docker bridge access port $port"
        ufw allow from 172.18.0.0/16 to any port $port proto tcp comment "PostgreSQL Docker compose access port $port"
    fi
    
    # 拒绝所有其他外部连接到PostgreSQL端口
    ufw deny $port/tcp comment "Block external access to PostgreSQL port $port"
    
    echo "     ✓ 已配置端口 $port 的访问控制"
done

# 允许HTTP和HTTPS（如果需要Web服务）
echo "7. 配置Web服务端口（可选）..."
read -p "   是否允许HTTP(80)和HTTPS(443)访问？(y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ufw allow 80/tcp comment "HTTP access"
    ufw allow 443/tcp comment "HTTPS access"
    echo "   已允许：HTTP(80) 和 HTTPS(443) 端口"
fi

# 允许其他常用服务端口（根据需要）
echo "8. 配置其他服务端口..."
echo "   检测到的监听端口："
ss -tlnp | grep LISTEN | awk '{print $4}' | cut -d: -f2 | sort -nu | head -10

read -p "   是否需要配置其他端口访问？(y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "   请手动添加需要的端口，例如："
    echo "   sudo ufw allow [端口号]/tcp comment \"服务描述\""
fi

# 启用UFW
echo "9. 启用UFW防火墙..."
ufw --force enable

# 显示最终配置
echo "10. 显示最终UFW配置..."
echo "======================================="
ufw status verbose
echo "======================================="

# 显示安全建议
echo ""
echo "🔒 安全配置完成！"
echo ""
echo "✅ 已完成的安全配置："
echo "   - PostgreSQL端口 (5432, 15432, 16430) 仅允许本地访问"
echo "   - 拒绝所有外部对PostgreSQL端口的访问"
echo "   - 保留SSH访问以防被锁定"
echo "   - 允许本地回环接口通信"
echo "   - 如果有Docker，已允许Docker网桥访问"
echo ""
echo "⚠️  重要提醒："
echo "   1. 请测试您的Spring Boot应用是否能正常连接数据库"
echo "   2. 如果使用Docker PostgreSQL，确保容器配置正确"
echo "   3. 定期检查UFW日志：sudo tail -f /var/log/ufw.log"
echo "   4. 如需紧急禁用防火墙：sudo ufw disable"
echo ""
echo "🛡️  外部扫描防护："
echo "   现在外部无法访问您的PostgreSQL端口，这将："
echo "   - 防止端口扫描发现PostgreSQL服务"
echo "   - 阻止针对已知CVE的攻击尝试"
echo "   - 减少暴露面，提高整体安全性"
echo ""
echo "测试命令："
echo "   本地连接测试：psql -h 127.0.0.1 -p 5432 -U username -d database"
echo "   外部连接测试：telnet [服务器IP] 5432 (应该被拒绝)"
echo ""
echo "======================================="
echo "PostgreSQL UFW 防火墙配置完成！"
echo "======================================="