# PostgreSQL 安全防护 - UFW 防火墙命令详解

## 🚀 一键执行脚本
```bash
# 下载并执行配置脚本
sudo bash /workspace/postgresql_security_setup.sh
```

## 🔧 手动执行命令（逐步操作）

### 第一步：重置并设置基本策略
```bash
# 重置UFW配置（清除所有规则）
sudo ufw --force reset

# 设置默认策略：拒绝入站，允许出站
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

### 第二步：允许本地和基本服务
```bash
# 允许本地回环地址的所有连接（重要：确保本地程序正常工作）
sudo ufw allow from 127.0.0.1
sudo ufw allow from ::1

# 允许SSH访问（重要：确保远程管理不受影响）
sudo ufw allow 22/tcp comment 'SSH access'

# 允许Web服务端口（根据您的需要）
sudo ufw allow 80/tcp comment 'HTTP web server'
sudo ufw allow 443/tcp comment 'HTTPS web server'
sudo ufw allow 8080/tcp comment 'Spring Boot default port'
```

### 第三步：配置PostgreSQL安全访问（核心部分）
```bash
# 只允许本地访问PostgreSQL端口
sudo ufw allow from 127.0.0.1 to any port 5432 proto tcp comment 'PostgreSQL local access - port 5432'
sudo ufw allow from 127.0.0.1 to any port 15432 proto tcp comment 'PostgreSQL local access - port 15432'
sudo ufw allow from 127.0.0.1 to any port 16430 proto tcp comment 'PostgreSQL local access - port 16430'

# 明确拒绝PostgreSQL端口的外部访问
sudo ufw deny 5432/tcp comment 'Block external PostgreSQL access - port 5432'
sudo ufw deny 15432/tcp comment 'Block external PostgreSQL access - port 15432'
sudo ufw deny 16430/tcp comment 'Block external PostgreSQL access - port 16430'
```

### 第四步：启用防火墙
```bash
# 启用UFW防火墙
sudo ufw --force enable

# 查看当前规则
sudo ufw status verbose
```

## 🔍 验证和测试命令

### 检查配置是否生效
```bash
# 检查UFW状态
sudo ufw status verbose

# 检查监听端口
sudo netstat -tlnp | grep -E ':5432|:15432|:16430'

# 或使用ss命令
sudo ss -tlnp | grep -E ':5432|:15432|:16430'
```

### 测试本地连接
```bash
# 测试本地PostgreSQL连接
psql -h localhost -p 15432 -U your_username -d your_database
psql -h 127.0.0.1 -p 16430 -U your_username -d your_database
```

### 测试外部访问被阻止
```bash
# 从其他机器测试（应该失败）
psql -h your_server_ip -p 15432 -U your_username -d your_database
# 这个连接应该超时或被拒绝
```

## 🛡️ 安全规则解释

| 规则类型 | 来源 | 目标端口 | 协议 | 作用 |
|---------|------|----------|------|------|
| ALLOW | 127.0.0.1 | 5432 | TCP | 允许本地访问标准PostgreSQL端口 |
| ALLOW | 127.0.0.1 | 15432 | TCP | 允许本地访问自定义PostgreSQL端口 |
| ALLOW | 127.0.0.1 | 16430 | TCP | 允许本地访问自定义PostgreSQL端口 |
| DENY | any | 5432 | TCP | 拒绝外部访问PostgreSQL端口 |
| DENY | any | 15432 | TCP | 拒绝外部访问PostgreSQL端口 |
| DENY | any | 16430 | TCP | 拒绝外部访问PostgreSQL端口 |
| ALLOW | any | 22 | TCP | 允许SSH远程管理 |
| ALLOW | any | 80 | TCP | 允许HTTP Web访问 |
| ALLOW | any | 443 | TCP | 允许HTTPS Web访问 |
| ALLOW | any | 8080 | TCP | 允许Spring Boot应用访问 |

## 🔧 PostgreSQL 配置文件调整

### postgresql.conf 设置
```ini
# 只监听本地地址
listen_addresses = 'localhost'
# 或者指定具体端口
listen_addresses = '127.0.0.1'

# 设置端口
port = 5432
```

### pg_hba.conf 设置
```
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# 只允许本地连接
local   all             all                                     md5
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5

# 不要添加以下规则（会允许外部访问）
# host    all             all             0.0.0.0/0               md5
```

### Docker PostgreSQL 安全启动
```bash
# 正确方式：只绑定到本地IP
docker run -d --name postgres-secure \
  -p 127.0.0.1:15432:5432 \
  -e POSTGRES_PASSWORD=your_password \
  postgres:latest

# 错误方式：绑定到所有IP（不安全）
# docker run -p 15432:5432 postgres:latest
```

## 🚨 重要注意事项

1. **Spring Boot 应用配置**：
   ```yaml
   spring:
     datasource:
       url: jdbc:postgresql://localhost:15432/your_database
       # 或者使用
       url: jdbc:postgresql://127.0.0.1:16430/your_database
   ```

2. **远程管理**：
   如需远程管理PostgreSQL，使用SSH隧道：
   ```bash
   ssh -L 5432:localhost:15432 user@your_server
   ```

3. **定期检查**：
   ```bash
   # 每周检查防火墙状态
   sudo ufw status verbose
   
   # 检查异常连接
   sudo netstat -n | grep :5432
   ```

## 🔄 回滚命令（如有问题）

```bash
# 如果需要临时关闭UFW
sudo ufw disable

# 完全重置UFW配置
sudo ufw --force reset

# 恢复默认设置
sudo ufw default allow incoming
sudo ufw default allow outgoing
```

这些配置确保：
- ✅ Spring Boot应用可以正常连接本地PostgreSQL
- ✅ 外部扫描无法发现PostgreSQL服务
- ✅ 避免您提到的所有CVE漏洞被扫描到
- ✅ 不影响服务器上其他程序的正常运行