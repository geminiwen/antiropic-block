#!/bin/bash

# 守护进程管理和监控脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$SCRIPT_DIR/run-daemon.pid"
LOG_DIR="$SCRIPT_DIR/logs"
DAEMON_LOG="$LOG_DIR/daemon.log"
RUN_LOG="$LOG_DIR/run-output.log"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 启动守护进程
start() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            echo -e "${YELLOW}守护进程已在运行 (PID: $PID)${NC}"
            return 1
        fi
    fi

    echo "启动守护进程..."
    nohup "$SCRIPT_DIR/run-daemon.sh" > /dev/null 2>&1 &
    sleep 1

    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        echo -e "${GREEN}守护进程已启动 (PID: $PID)${NC}"
        return 0
    else
        echo -e "${RED}启动失败${NC}"
        return 1
    fi
}

# 停止守护进程
stop() {
    if [ ! -f "$PID_FILE" ]; then
        echo -e "${YELLOW}守护进程未运行${NC}"
        return 1
    fi

    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "停止守护进程 (PID: $PID)..."
        kill "$PID"
        sleep 2

        if ps -p "$PID" > /dev/null 2>&1; then
            echo -e "${YELLOW}强制停止...${NC}"
            kill -9 "$PID"
        fi

        rm -f "$PID_FILE"
        echo -e "${GREEN}守护进程已停止${NC}"
        return 0
    else
        echo -e "${YELLOW}进程不存在，清理 PID 文件${NC}"
        rm -f "$PID_FILE"
        return 1
    fi
}

# 查看状态
status() {
    if [ ! -f "$PID_FILE" ]; then
        echo -e "${RED}守护进程未运行${NC}"
        return 1
    fi

    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo -e "${GREEN}守护进程运行中${NC}"
        echo "PID: $PID"
        echo "运行时长: $(ps -p "$PID" -o etime= | tr -d ' ')"
        echo "内存使用: $(ps -p "$PID" -o rss= | awk '{print $1/1024 " MB"}')"
        echo ""

        if [ -f "$DAEMON_LOG" ]; then
            echo "最近的日志 (最后10行):"
            echo "----------------------------------------"
            tail -10 "$DAEMON_LOG"
        fi
        return 0
    else
        echo -e "${RED}PID 文件存在但进程不运行${NC}"
        return 1
    fi
}

# 查看日志
logs() {
    local lines=${1:-50}

    if [ ! -f "$DAEMON_LOG" ]; then
        echo -e "${YELLOW}日志文件不存在${NC}"
        return 1
    fi

    echo "========== 守护进程日志 (最后 $lines 行) =========="
    tail -n "$lines" "$DAEMON_LOG"
}

# 实时查看日志
follow() {
    if [ ! -f "$DAEMON_LOG" ]; then
        echo -e "${YELLOW}等待日志文件创建...${NC}"
        mkdir -p "$LOG_DIR"
        touch "$DAEMON_LOG"
    fi

    echo "实时监控日志 (Ctrl+C 退出)..."
    tail -f "$DAEMON_LOG"
}

# 查看运行输出日志
run_logs() {
    local lines=${1:-50}

    if [ ! -f "$RUN_LOG" ]; then
        echo -e "${YELLOW}运行输出日志不存在${NC}"
        return 1
    fi

    echo "========== run.sh 输出日志 (最后 $lines 行) =========="
    tail -n "$lines" "$RUN_LOG"
}

# 重启
restart() {
    stop
    sleep 2
    start
}

# 显示帮助
usage() {
    cat << EOF
用法: $0 {start|stop|restart|status|logs|follow|run-logs}

命令:
  start       启动守护进程
  stop        停止守护进程
  restart     重启守护进程
  status      查看运行状态
  logs [n]    查看守护进程日志 (默认最后50行)
  follow      实时监控日志
  run-logs [n] 查看 run.sh 的输出日志 (默认最后50行)

示例:
  $0 start          # 启动
  $0 status         # 查看状态
  $0 logs 100       # 查看最后100行日志
  $0 follow         # 实时监控
  $0 run-logs 20    # 查看 run.sh 最后20行输出

EOF
}

# 主命令处理
case "${1}" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    status)
        status
        ;;
    logs)
        logs "${2}"
        ;;
    follow)
        follow
        ;;
    run-logs)
        run_logs "${2}"
        ;;
    *)
        usage
        exit 1
        ;;
esac

exit $?
