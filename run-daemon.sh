#!/bin/bash

# 守护进程：每隔 37 分钟 (±5分钟随机) 执行一次 run.sh
# 带有详细日志输出和进程管理
# 执行时间窗口：UTC-8 09:00 - 20:00

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_SCRIPT="$SCRIPT_DIR/run.sh"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/daemon.log"
PID_FILE="$SCRIPT_DIR/run-daemon.pid"

# 时间窗口配置 (UTC-8 时区)
TIMEZONE="America/Los_Angeles"  # 美国西海岸时区 (PST/PDT)
START_HOUR=9   # 开始时间：9:00
END_HOUR=20    # 结束时间：20:00

# 创建日志目录
mkdir -p "$LOG_DIR"

# 日志函数
log() {
    echo "[$(TZ=$TIMEZONE date '+%Y-%m-%d %H:%M:%S %Z')] $1" | tee -a "$LOG_FILE"
}

# 检查是否在允许的时间窗口内
is_in_time_window() {
    local current_hour=$(TZ=$TIMEZONE date '+%H')
    # 移除前导零
    current_hour=$((10#$current_hour))

    if [ $current_hour -ge $START_HOUR ] && [ $current_hour -lt $END_HOUR ]; then
        return 0  # 在时间窗口内
    else
        return 1  # 不在时间窗口内
    fi
}

# 计算到下一个时间窗口的秒数
seconds_until_next_window() {
    local current_hour=$(TZ=$TIMEZONE date '+%H')
    local current_minute=$(TZ=$TIMEZONE date '+%M')
    local current_second=$(TZ=$TIMEZONE date '+%S')

    # 移除前导零
    current_hour=$((10#$current_hour))
    current_minute=$((10#$current_minute))
    current_second=$((10#$current_second))

    local current_seconds=$((current_hour * 3600 + current_minute * 60 + current_second))
    local start_seconds=$((START_HOUR * 3600))
    local end_seconds=$((END_HOUR * 3600))

    if [ $current_seconds -lt $start_seconds ]; then
        # 当前时间在今天开始时间之前
        echo $((start_seconds - current_seconds))
    else
        # 当前时间在今天结束时间之后，等到明天开始时间
        local seconds_until_midnight=$((86400 - current_seconds))
        echo $((seconds_until_midnight + start_seconds))
    fi
}

# 检查是否已经在运行
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        log "ERROR: 守护进程已在运行 (PID: $OLD_PID)"
        exit 1
    else
        log "WARNING: 发现陈旧的 PID 文件，已清理"
        rm -f "$PID_FILE"
    fi
fi

# 写入当前进程 PID
echo $$ > "$PID_FILE"
log "INFO: 守护进程启动 (PID: $$)"

# 清理函数
cleanup() {
    log "INFO: 收到终止信号，正在停止守护进程..."
    rm -f "$PID_FILE"
    exit 0
}

# 捕获终止信号
trap cleanup SIGTERM SIGINT SIGQUIT

# 主循环
EXECUTION_COUNT=0
while true; do
    # 检查是否在时间窗口内
    if ! is_in_time_window; then
        wait_seconds=$(seconds_until_next_window)
        wait_time=$(TZ=$TIMEZONE date -d "+${wait_seconds} seconds" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || TZ=$TIMEZONE date -v+${wait_seconds}S '+%Y-%m-%d %H:%M:%S')
        log "INFO: 当前不在执行时间窗口内 (${START_HOUR}:00-${END_HOUR}:00)，等待到 $wait_time"
        sleep "$wait_seconds"
        continue
    fi

    EXECUTION_COUNT=$((EXECUTION_COUNT + 1))

    log "========== 执行次数: $EXECUTION_COUNT =========="

    # 检查 run.sh 是否存在
    if [ ! -f "$RUN_SCRIPT" ]; then
        log "ERROR: run.sh 不存在: $RUN_SCRIPT"
        sleep 60
        continue
    fi

    # 执行 run.sh 并记录输出
    log "INFO: 开始执行 run.sh"
    START_TIME=$(date +%s)

    # 执行脚本，同时输出到日志和控制台
    bash "$RUN_SCRIPT" >> "$LOG_DIR/run-output.log" 2>&1
    EXIT_CODE=$?

    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    if [ $EXIT_CODE -eq 0 ]; then
        log "INFO: run.sh 执行成功 (耗时: ${DURATION}秒)"
    else
        log "ERROR: run.sh 执行失败 (退出码: $EXIT_CODE, 耗时: ${DURATION}秒)"
    fi

    # 计算随机延迟：37分钟 ± 5分钟 (32-42分钟)
    BASE_SECONDS=$((37 * 60))  # 2220 秒
    RANDOM_OFFSET=$((RANDOM % 600 - 300))  # -300 到 +300 秒 (-5分钟 到 +5分钟)
    SLEEP_SECONDS=$((BASE_SECONDS + RANDOM_OFFSET))
    SLEEP_MINUTES=$((SLEEP_SECONDS / 60))

    # 计算下次执行时间
    NEXT_RUN_TIMESTAMP=$(($(date +%s) + SLEEP_SECONDS))
    NEXT_RUN=$(TZ=$TIMEZONE date -d "@${NEXT_RUN_TIMESTAMP}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || TZ=$TIMEZONE date -r ${NEXT_RUN_TIMESTAMP} '+%Y-%m-%d %H:%M:%S')

    # 检查下次执行是否超出时间窗口
    NEXT_HOUR=$(TZ=$TIMEZONE date -d "@${NEXT_RUN_TIMESTAMP}" '+%H' 2>/dev/null || TZ=$TIMEZONE date -r ${NEXT_RUN_TIMESTAMP} '+%H')
    NEXT_HOUR=$((10#$NEXT_HOUR))

    if [ $NEXT_HOUR -ge $END_HOUR ]; then
        log "INFO: 下次执行时间 $NEXT_RUN 超出执行窗口，将等待到明天 ${START_HOUR}:00"
        wait_seconds=$(seconds_until_next_window)
        sleep "$wait_seconds"
    else
        log "INFO: 等待 ${SLEEP_MINUTES} 分钟 (${SLEEP_SECONDS}秒)，下次执行时间: $NEXT_RUN"
        sleep "$SLEEP_SECONDS"
    fi
done
