#!/bin/bash
# Claude Code Notification hook.
#
# 功能：
#   - 读 /tmp/claude-notify-<sid>.meta 拿到 cwd，标题显示项目名
#   - 按消息关键词分类：permission/select/error/idle/other，各走不同音效和呈现
#   - waiting-for-input 空闲提醒同会话只响第一次，响应其他事件后自动重置
#
# 依赖：python3（macOS 自带）、osascript（macOS 自带）

input=$(cat)

eval "$(printf '%s' "$input" | python3 -c '
import json, os, sys, shlex

try:
    d = json.loads(sys.stdin.read())
except Exception:
    d = {}

msg = (d.get("message") or "Claude needs your attention").replace("\n"," ").replace("\r"," ").replace("\t"," ").strip()
sid = (d.get("session_id") or "default").replace("/", "_").replace("\t","_")

cwd = ""
try:
    with open(f"/tmp/claude-notify-{sid}.meta") as f:
        cwd = (json.load(f).get("cwd") or "")
except Exception:
    pass
project = os.path.basename(cwd) if cwd else ""

low = msg.lower()
if "waiting for your input" in low:
    kind = "idle"
elif any(k in low for k in ["permission", "approve", "allow", "允许", "授权"]):
    kind = "permission"
elif any(k in low for k in ["choose", "select", "choice", "选择"]):
    kind = "select"
elif any(k in low for k in ["error", "failed", "rate limit", "session limit", "错误", "失败"]):
    kind = "error"
else:
    kind = "other"

print(f"MSG={shlex.quote(msg)}")
print(f"SID={shlex.quote(sid)}")
print(f"PROJECT={shlex.quote(project)}")
print(f"KIND={shlex.quote(kind)}")
')"

state="/tmp/claude-notify-${SID}.waiting"
if [ "$KIND" = "idle" ]; then
  [ -f "$state" ] && exit 0
  touch "$state"
else
  rm -f "$state"
fi

TITLE="Claude Code"
[ -n "$PROJECT" ] && TITLE="Claude Code · $PROJECT"

case "$KIND" in
  permission) SOUND="Hero"  ;;
  select)     SOUND="Ping"  ;;
  error)      SOUND="Basso" ;;
  idle)       SOUND="Glass" ;;
  *)          SOUND="Pop"   ;;
esac

python3 -c '
import json, sys
msg, title, sound = sys.argv[1], sys.argv[2], sys.argv[3]
print(f"display notification {json.dumps(msg)} with title {json.dumps(title)} sound name {json.dumps(sound)}")
' "$MSG" "$TITLE" "$SOUND" | osascript 2>/dev/null || true
