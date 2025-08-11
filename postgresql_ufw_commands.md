# PostgreSQL UFW 防火墙配置详细指南

## 🚨 重要提醒
**执行前请确保您有SSH或物理访问权限，避免被防火墙锁定！**

## 📋 快速配置命令清单

### 1. 基础防火墙设置

```bash
# 检查当前UFW状态
sudo ufw status verbose

# 重置UFW规则（可选，谨慎使用）
sudo ufw --force reset

# 设置默认策略
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 允许SSH（防止被锁定）
sudo ufw allow ssh
sudo ufw allow 22/tcp
```

### 2. 本地回环接口配置

```bash
# 允许本地回环接口通信（重要！）
sudo ufw allow in on lo
sudo ufw allow out on lo
```

### 3. PostgreSQL端口安全配置

#### 标准PostgreSQL端口 (5432)
```bash
# 只允许本地IP访问
sudo ufw allow from 127.0.0.1 to any port 5432 proto tcp comment "PostgreSQL local access"
sudo ufw allow from ::1 to any port 5432 proto tcp comment "PostgreSQL local IPv6 access"

# 如果使用Docker，允许Docker网桥访问
sudo ufw allow from 172.17.0.0/16 to any port 5432 proto tcp comment "PostgreSQL Docker bridge access"
sudo ufw allow from 172.18.0.0/16 to any port 5432 proto tcp comment "PostgreSQL Docker compose access"

# 明确拒绝外部访问
sudo ufw deny 5432/tcp comment "Block external PostgreSQL access"
```

#### 您的自定义端口 (15432)
```bash
# 只允许本地IP访问
sudo ufw allow from 127.0.0.1 to any port 15432 proto tcp comment "PostgreSQL local access port 15432"
sudo ufw allow from ::1 to any port 15432 proto tcp comment "PostgreSQL local IPv6 access port 15432"

# Docker网桥访问
sudo ufw allow from 172.17.0.0/16 to any port 15432 proto tcp comment "PostgreSQL Docker bridge access port 15432"
sudo ufw allow from 172.18.0.0/16 to any port 15432 proto tcp comment "PostgreSQL Docker compose access port 15432"

# 拒绝外部访问
sudo ufw deny 15432/tcp comment "Block external access to PostgreSQL port 15432"
```

#### 您的自定义端口 (16430)
```bash
# 只允许本地IP访问
sudo ufw allow from 127.0.0.1 to any port 16430 proto tcp comment "PostgreSQL local access port 16430"
sudo ufw allow from ::1 to any port 16430 proto tcp comment "PostgreSQL local IPv6 access port 16430"

# Docker网桥访问
sudo ufw allow from 172.17.0.0/16 to any port 16430 proto tcp comment "PostgreSQL Docker bridge access port 16430"
sudo ufw allow from 172.18.0.0/16 to any port 16430 proto tcp comment "PostgreSQL Docker compose access port 16430"

# 拒绝外部访问
sudo ufw deny 16430/tcp comment "Block external access to PostgreSQL port 16430"
```

### 4. Spring Boot应用端口配置（可选）

```bash
# 如果Spring Boot应用需要外部访问，添加其端口
# 假设Spring Boot运行在8080端口
sudo ufw allow 8080/tcp comment "Spring Boot application"

# 如果只需要本地访问Spring Boot
sudo ufw allow from 127.0.0.1 to any port 8080 proto tcp comment "Spring Boot local access"
```

### 5. 启用防火墙

```bash
# 启用UFW
sudo ufw --force enable

# 查看最终配置
sudo ufw status verbose
sudo ufw status numbered
```

## 🔍 验证和测试

### 检查防火墙状态
```bash
# 查看详细状态
sudo ufw status verbose

# 查看编号的规则列表
sudo ufw status numbered

# 查看UFW日志
sudo tail -f /var/log/ufw.log
```

### 测试连接
```bash
# 本地连接测试（应该成功）
telnet 127.0.0.1 5432
telnet 127.0.0.1 15432
telnet 127.0.0.1 16430

# 从外部IP测试（应该被拒绝）
# 从另一台机器执行：
# telnet [您的服务器IP] 5432
# telnet [您的服务器IP] 15432
# telnet [您的服务器IP] 16430
```

### Spring Boot应用测试
```bash
# 测试Spring Boot应用能否连接数据库
# 检查应用日志中的数据库连接状态
tail -f /path/to/your/springboot/logs/application.log
```

## 🚨 安全效果

配置完成后，您的PostgreSQL数据库将获得以下保护：

### ✅ 防护效果
- **端口隐藏**：外部扫描无法发现PostgreSQL端口
- **访问控制**：只有本地应用可以连接数据库
- **攻击防护**：阻止针对已知CVE的远程攻击
- **减少暴露面**：最小化网络攻击向量

### 🔒 被阻止的攻击类型
- CVE-2023-39417：SQL注入攻击
- CVE-2021-23214：SQL注入攻击  
- CVE-2022-2625：权限提升攻击
- CVE-2023-2454：安全漏洞利用
- CVE-2022-1552：权限许可绕过
- 以及其他所有远程网络攻击

## 🛠️ 管理命令

### 临时禁用防火墙（调试用）
```bash
sudo ufw disable
```

### 重新启用防火墙
```bash
sudo ufw enable
```

### 删除特定规则
```bash
# 查看规则编号
sudo ufw status numbered

# 删除指定编号的规则
sudo ufw delete [规则编号]
```

### 修改规则
```bash
# 添加新的允许规则
sudo ufw allow from [IP地址] to any port [端口号]

# 删除旧规则，添加新规则
sudo ufw delete [旧规则]
sudo ufw allow [新规则]
```

## ⚠️ 故障排除

### 如果Spring Boot应用无法连接数据库

1. **检查应用配置**：
   ```properties
   # 确保使用本地IP连接
   spring.datasource.url=jdbc:postgresql://127.0.0.1:5432/database_name
   # 或
   spring.datasource.url=jdbc:postgresql://localhost:5432/database_name
   ```

2. **检查PostgreSQL配置**：
   ```bash
   # 查看PostgreSQL监听地址
   sudo grep listen_addresses /etc/postgresql/*/main/postgresql.conf
   
   # 应该设置为：
   # listen_addresses = 'localhost,127.0.0.1'
   ```

3. **Docker PostgreSQL配置**：
   ```bash
   # 确保容器端口映射正确
   docker run -p 127.0.0.1:5432:5432 postgres
   
   # 或在docker-compose.yml中：
   # ports:
   #   - "127.0.0.1:5432:5432"
   ```

### 紧急恢复命令
```bash
# 如果被防火墙锁定，通过控制台执行：
sudo ufw disable
sudo ufw --force reset
sudo ufw allow ssh
sudo ufw enable
```

## 📊 监控建议

### 设置日志监控
```bash
# 实时监控UFW日志
sudo tail -f /var/log/ufw.log | grep -E "(5432|15432|16430)"

# 查看被阻止的连接尝试
sudo grep "BLOCK" /var/log/ufw.log | grep -E "(5432|15432|16430)"
```

### 定期安全检查
```bash
# 每周检查UFW状态
sudo ufw status verbose

# 检查异常连接尝试
sudo grep -i "postgresql\|postgres" /var/log/auth.log
sudo grep -E "(5432|15432|16430)" /var/log/syslog
```

---

## 🎯 总结

通过正确配置UFW防火墙，您可以：
1. **完全阻止**外部对PostgreSQL端口的访问
2. **保持**Spring Boot应用的正常数据库连接
3. **防护**所有已知的PostgreSQL CVE攻击
4. **隐藏**数据库服务，避免被扫描发现

这是一个**无损**的安全加固方案，不会影响您现有应用的正常运行！