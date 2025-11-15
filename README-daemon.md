# 守护进程使用说明

每隔 37 分钟（±5分钟随机）执行一次 run.sh 的守护进程方案。

**执行时间窗口**: UTC+8 时区 09:00 - 20:00（仅在此时间段内执行）

## 文件说明

- `run-daemon.sh` - 守护进程主脚本
- `daemon-control.sh` - 进程管理和监控脚本
- `run-daemon.service` - systemd 服务配置文件（可选）
- `logs/` - 日志目录
  - `daemon.log` - 守护进程日志
  - `run-output.log` - run.sh 执行输出日志
  - `systemd.log` - systemd 日志（如果使用 systemd）

## 快速开始

### 方式 1: 使用控制脚本（推荐）

```bash
# 启动守护进程
./daemon-control.sh start

# 查看运行状态
./daemon-control.sh status

# 查看日志
./daemon-control.sh logs

# 实时监控日志
./daemon-control.sh follow

# 查看 run.sh 的输出
./daemon-control.sh run-logs

# 停止守护进程
./daemon-control.sh stop

# 重启守护进程
./daemon-control.sh restart
```

### 方式 2: 使用 systemd（Linux 推荐）

```bash
# 1. 编辑 service 文件，将 %USER% 替换为你的用户名
sed -i "s/%USER%/$(whoami)/g" run-daemon.service

# 2. 复制到 systemd 目录
sudo cp run-daemon.service /etc/systemd/system/

# 3. 重载配置
sudo systemctl daemon-reload

# 4. 启动服务
sudo systemctl start run-daemon

# 5. 设置开机自启
sudo systemctl enable run-daemon

# 查看状态
sudo systemctl status run-daemon

# 查看日志
sudo journalctl -u run-daemon -f
```

### 方式 3: 使用 nohup 手动后台运行

```bash
# 后台启动
nohup ./run-daemon.sh &

# 查看日志
tail -f logs/daemon.log
```

## 功能特性

### 1. 时间窗口控制 ⏰
- **执行时段**: UTC+8 时区 09:00 - 20:00
- **自动等待**: 超出时间窗口自动等待到次日 09:00
- **智能检测**: 每次执行前检查时间窗口
- **时区支持**: 使用 `Asia/Shanghai` 时区（UTC+8）

### 2. 随机延迟
- 基础间隔: 37 分钟
- 随机范围: ±5 分钟（32-42 分钟）
- 避免时间碰撞，更自然的执行模式
- 自动检测下次执行是否超出时间窗口

### 3. 完整日志
- 执行时间戳（带时区信息）
- 执行次数统计
- 退出码记录
- 耗时统计
- 下次执行时间预告
- 时间窗口状态记录

### 4. 进程管理
- PID 文件防止重复运行
- 优雅的信号处理
- 自动重启（systemd）
- 进程状态监控

### 5. 错误处理
- run.sh 不存在时自动等待
- 执行失败不中断循环
- 详细的错误日志

## 日志示例

### 正常执行日志
```
[2025-11-15 10:00:00 CST] INFO: 守护进程启动 (PID: 12345)
[2025-11-15 10:00:00 CST] ========== 执行次数: 1 ==========
[2025-11-15 10:00:00 CST] INFO: 开始执行 run.sh
[2025-11-15 10:02:30 CST] INFO: run.sh 执行成功 (耗时: 150秒)
[2025-11-15 10:02:30 CST] INFO: 等待 39 分钟 (2340秒)，下次执行时间: 2025-11-15 10:41:30
```

### 超出时间窗口日志
```
[2025-11-15 19:45:00 CST] INFO: run.sh 执行成功 (耗时: 120秒)
[2025-11-15 19:45:00 CST] INFO: 下次执行时间 2025-11-15 20:22:00 超出执行窗口，将等待到明天 9:00
[2025-11-15 20:00:00 CST] INFO: 当前不在执行时间窗口内 (9:00-20:00)，等待到 2025-11-16 09:00:00
```

## 监控和维护

### 查看守护进程状态
```bash
./daemon-control.sh status
```

### 实时查看最新日志
```bash
./daemon-control.sh follow
```

### 查看历史日志
```bash
# 最后 50 行
./daemon-control.sh logs

# 最后 100 行
./daemon-control.sh logs 100
```

### 清理旧日志
```bash
# 清理 7 天前的日志
find logs/ -name "*.log" -mtime +7 -delete
```

### 日志轮转（可选）
创建 `/etc/logrotate.d/run-daemon`:

```
/path/to/antiropic-block/logs/*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    create 0644 username username
}
```

## 故障排查

### 进程无法启动
```bash
# 检查权限
ls -l run-daemon.sh run.sh

# 查看错误日志
cat logs/daemon.log
```

### 进程意外退出
```bash
# 查看最后的日志
tail -50 logs/daemon.log

# 使用 systemd 自动重启
sudo systemctl enable run-daemon
```

### 日志文件过大
```bash
# 压缩旧日志
gzip logs/daemon.log.old

# 配置 logrotate
sudo vi /etc/logrotate.d/run-daemon
```

## 性能说明

- 内存占用: ~2-5 MB
- CPU 占用: 空闲时 <0.1%
- 日志增长: 约 1-2 KB/次执行

## 配置修改

如需调整配置，编辑 `run-daemon.sh` 中的以下变量：

```bash
# 时间窗口配置
TIMEZONE="Asia/Shanghai"  # 时区（UTC+8）
START_HOUR=9              # 开始时间（9:00）
END_HOUR=20               # 结束时间（20:00）

# 执行间隔配置
BASE_SECONDS=$((37 * 60))  # 基础间隔（37分钟）
RANDOM_OFFSET=$((RANDOM % 600 - 300))  # 随机偏移（±5分钟）
```

### 时区说明

- **UTC+8 时区** 对应的 TIMEZONE 值：
  - `Asia/Shanghai` （中国大陆）
  - `Asia/Hong_Kong` （香港）
  - `Asia/Taipei` （台湾）
  - `Asia/Singapore` （新加坡）

- 如果你在其他时区，请修改 `TIMEZONE` 变量，例如：
  - 美国东部时间：`America/New_York` (UTC-5/-4)
  - 日本时间：`Asia/Tokyo` (UTC+9)
  - 欧洲中部时间：`Europe/Paris` (UTC+1/+2)

## 注意事项

1. 确保 run.sh 有执行权限
2. 首次运行会自动创建 logs 目录
3. PID 文件在进程运行时不要手动删除
4. **时间窗口基于配置的时区**，确保时区设置正确
5. 守护进程会 24 小时运行，但只在 9:00-20:00 执行任务
6. 在 Linux 上建议使用 systemd 方式，更稳定可靠
7. 如果系统时区与 UTC+8 不同，脚本会自动使用配置的时区
