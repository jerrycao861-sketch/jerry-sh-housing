#!/bin/bash
# ============================================================
# 上海房市追踪 - Launcher 脚本
# 用于绕过 macOS 安全限制，由 launchd 调用
# ============================================================

LOG="/Users/caocao/Documents/上海房市追踪系统/update.log"
SCRIPT="/Users/caocao/Documents/上海房市追踪系统/daily_update.sh"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Launcher 启动" >> "$LOG"

# 清除安全属性
xattr -d com.apple.provenance "$SCRIPT" 2>/dev/null
xattr -d com.apple.quarantine "$SCRIPT" 2>/dev/null

# 执行主脚本
/bin/bash "$SCRIPT" >> "$LOG" 2>&1
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ 主脚本退出码: $EXIT_CODE" >> "$LOG"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Launcher 完成" >> "$LOG"
