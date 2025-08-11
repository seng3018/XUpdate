# PostgreSQL 安全防护 - 保守UFW配置（不影响现有规则）

## 🚀 推荐方案：安全脚本执行
```bash
# 执行保守配置脚本（不会影响现有UFW规则）
sudo bash /workspace/postgresql_security_setup_safe.sh
```

## 🔧 手动执行命令（只添加PostgreSQL规则）

### ⚠️ 重要说明
**这些命令只会添加PostgreSQL相关规则，不会修改或删除您现有的任何UFW规则！**

### 第一步：检查当前状态
```bash
# 查看当前UFW状态和规则
sudo ufw status verbose

# 备份当前规则（建议）
sudo ufw status verbose > /tmp/ufw_backup_$(date +%Y%m%d_%H%M%S).txt
```

### 第二步：只添加PostgreSQL安全规则

#### 允许本地访问PostgreSQL端口
```bash
# 只允许本地127.0.0.1访问PostgreSQL端口
sudo ufw allow from 127.0.0.1 to any port 5432 proto tcp comment 'PostgreSQL local access - port 5432'
sudo ufw allow from 127.0.0.1 to any port 15432 proto tcp comment 'PostgreSQL local access - port 15432'
sudo ufw allow from 127.0.0.1 to any port 16430 proto tcp comment 'PostgreSQL local access - port 16430'
```

#### 拒绝外部访问PostgreSQL端口
```bash
# 明确拒绝外部访问PostgreSQL端口
sudo ufw deny 5432/tcp comment 'Block external PostgreSQL access - port 5432'
sudo ufw deny 15432/tcp comment 'Block external PostgreSQL access - port 15432'
sudo ufw deny 16430/tcp comment 'Block external PostgreSQL access - port 16430'
```

#### 可选：添加本地回环地址通用规则
```bash
# 如果您还没有本地回环地址的通用规则，可以添加（可选）
sudo ufw allow from 127.0.0.1
```

### 第三步：启用UFW（如果尚未启用）
```bash
# 只有在UFW未启用时才需要执行
sudo ufw status | grep -q "Status: inactive" && sudo ufw --force enable
```

## 🔍 验证配置

### 检查新添加的规则
```bash
# 查看所有规则
sudo ufw status verbose

# 查看PostgreSQL相关规则
sudo ufw status | grep -E '5432|15432|16430'
```

### 测试本地连接仍然有效
```bash
# 测试本地PostgreSQL连接（如果有运行的实例）
psql -h localhost -p 15432 -U your_username -d your_database
psql -h 127.0.0.1 -p 16430 -U your_username -d your_database
```

## 📋 规则解释

| 动作 | 来源 | 目标端口 | 效果 |
|------|------|----------|------|
| ALLOW | 127.0.0.1 | 5432 | ✅ 允许本地应用连接PostgreSQL |
| ALLOW | 127.0.0.1 | 15432 | ✅ 允许本地应用连接PostgreSQL |
| ALLOW | 127.0.0.1 | 16430 | ✅ 允许本地应用连接PostgreSQL |
| DENY | any | 5432 | ❌ 阻止外部扫描和连接 |
| DENY | any | 15432 | ❌ 阻止外部扫描和连接 |
| DENY | any | 16430 | ❌ 阻止外部扫描和连接 |

## 🛡️ 安全效果

这些配置确保：
- ✅ **Spring Boot应用可以正常连接本地PostgreSQL**
- ✅ **外部扫描无法发现PostgreSQL服务**
- ✅ **避免您提到的所有CVE漏洞被扫描到**
- ✅ **不影响服务器上其他程序的正常运行**
- ✅ **不影响之前设置的UFW规则**（包括自定义SSH端口等）

## 🚨 重要保证

### 不会影响的现有配置：
- ❌ 不会修改您的SSH端口规则
- ❌ 不会删除任何现有的UFW规则
- ❌ 不会修改UFW的默认策略
- ❌ 不会影响其他应用的端口配置

### 只会添加的规则：
- ✅ PostgreSQL端口的本地访问允许
- ✅ PostgreSQL端口的外部访问拒绝
- ✅ （可选）本地回环地址通用允许

## 🔄 如果需要回滚

### 删除PostgreSQL相关规则
```bash
# 查看规则编号
sudo ufw status numbered

# 删除特定规则（替换N为实际的规则编号）
sudo ufw delete N

# 或者根据规则内容删除
sudo ufw delete allow from 127.0.0.1 to any port 5432
sudo ufw delete allow from 127.0.0.1 to any port 15432
sudo ufw delete allow from 127.0.0.1 to any port 16430
sudo ufw delete deny 5432/tcp
sudo ufw delete deny 15432/tcp
sudo ufw delete deny 16430/tcp
```

## 💡 额外建议

### PostgreSQL配置文件优化
```ini
# postgresql.conf
listen_addresses = 'localhost'  # 只监听本地
```

### Docker PostgreSQL安全启动
```bash
# 确保Docker容器也只绑定到本地IP
docker run -p 127.0.0.1:15432:5432 postgres:latest
```

### Spring Boot应用配置
```yaml
# application.yml
spring:
  datasource:
    url: jdbc:postgresql://localhost:15432/your_database
    # 或者
    url: jdbc:postgresql://127.0.0.1:16430/your_database
```

这样配置后，外部扫描将完全无法发现您的PostgreSQL服务，但您的Spring Boot应用可以正常连接！