#!/bin/bash
# ============================================================
# 上海房市追踪 - 校验脚本
# 每天 10:00 和 12:00 检查是否已更新，未更新则触发更新
# ============================================================

WORK_DIR="/Users/caocao/Documents/上海房市追踪系统"
DATA_DIR="$WORK_DIR/data"
LOG="$WORK_DIR/update.log"
TODAY=$(date '+%Y-%m-%d')
TODAY_FILE="$DATA_DIR/$TODAY.json"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔍 校验开始: 检查 $TODAY 数据是否存在" >> "$LOG"

# 检查今日数据文件是否存在且有效
if [ -f "$TODAY_FILE" ]; then
    FILE_SIZE=$(stat -f%z "$TODAY_FILE" 2>/dev/null || echo "0")
    if [ "$FILE_SIZE" -gt 100 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ 校验通过: $TODAY 数据已存在 (${FILE_SIZE} bytes)" >> "$LOG"
        
        # 额外检查: GitHub 推送是否成功
        LAST_PUSH=$(cd "$WORK_DIR" && git log --oneline -1 2>/dev/null)
        if echo "$LAST_PUSH" | grep -q "$TODAY"; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ GitHub 推送已完成: $LAST_PUSH" >> "$LOG"
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ GitHub 未推送今日数据，尝试重新推送..." >> "$LOG"
            cd "$WORK_DIR"
            GITHUB_TOKEN=$(cat "$WORK_DIR/.github_token" 2>/dev/null)
            REPO="jerrycao861-sketch/jerry-sh-housing"
            if [ -n "$GITHUB_TOKEN" ]; then
                git add -A
                git commit -m "Auto update: $TODAY - Daily housing data" 2>/dev/null || true
                git push "https://${GITHUB_TOKEN}@github.com/${REPO}.git" main >> "$LOG" 2>&1
                if [ $? -eq 0 ]; then
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ 补推成功" >> "$LOG"
                else
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ 补推失败，将在下次校验重试" >> "$LOG"
                fi
            fi
        fi
        
        echo "---" >> "$LOG"
        exit 0
    fi
fi

# 数据不存在或无效，触发更新
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ 校验失败: $TODAY 数据不存在或无效，触发更新..." >> "$LOG"

# 清除安全属性并执行主脚本
SCRIPT="$WORK_DIR/daily_update.sh"
xattr -d com.apple.provenance "$SCRIPT" 2>/dev/null
xattr -d com.apple.quarantine "$SCRIPT" 2>/dev/null
/bin/bash "$SCRIPT" >> "$LOG" 2>&1
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ 补充更新完成" >> "$LOG"
    
    # 发送通知
    osascript -e "display notification \"校验发现今日数据缺失，已自动补充更新\" with title \"📊 房市追踪 - 自动修复\" subtitle \"$TODAY 数据已补充\""
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ 补充更新失败 (退出码: $EXIT_CODE)" >> "$LOG"
    
    # 发送失败通知
    osascript -e "display notification \"自动更新失败，请手动检查\" with title \"⚠️ 房市追踪 - 更新异常\" subtitle \"退出码: $EXIT_CODE\""
fi

echo "---" >> "$LOG"
