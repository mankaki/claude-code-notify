#!/bin/bash
# Claude Code Notification hook: macOS banner 通知 + Glass 声。
# 同一会话内 "waiting for your input" 空闲提醒只响第一次；其他事件重置去重状态。
# Dependencies: python3, osascript (macOS 自带)
set -u

LOG="${TMPDIR:-/tmp}/claude-notify.log"
INPUT=$(cat)

RESULT=$(CLAUDE_HOOK_INPUT="$INPUT" python3 <<'PY'
import json, os, re, sys, time

try:
    d = json.loads(os.environ.get("CLAUDE_HOOK_INPUT") or "{}")
except Exception:
    d = {}

raw_sid = d.get("session_id") or "default"
sid = re.sub(r"[^A-Za-z0-9_-]", "_", raw_sid)[:64]
msg = (d.get("message") or "Claude needs your attention")
msg = msg.replace("\n", " ").replace("\r", " ").strip()

# 基于英文原文的分类（必须在翻译前）
low = msg.lower()
is_idle = "waiting for your input" in low

# 英文消息翻译成中文，未命中的保留原文
if is_idle:
    msg = "Claude 在等你输入"
elif "needs your permission" in low:
    m = re.search(r"permission to (?:use |run )?(.+?)[\s\.]*$", msg, re.I)
    tool = m.group(1).strip() if m else ""
    msg = f"Claude 请求使用 {tool} 的权限" if tool else "Claude 请求权限"

tmp = (os.environ.get("TMPDIR") or "/tmp").rstrip("/")
state = f"{tmp}/claude-notify-{sid}.waiting"

# GC：清掉 7 天前的 state 文件
try:
    cutoff = time.time() - 7 * 86400
    for name in os.listdir(tmp):
        if name.startswith("claude-notify-") and name.endswith(".waiting"):
            p = f"{tmp}/{name}"
            if os.path.getmtime(p) < cutoff:
                os.remove(p)
except Exception:
    pass

if is_idle:
    if os.path.exists(state):
        sys.exit(0)  # dedup：静默跳过
    open(state, "w").close()
else:
    try:
        os.remove(state)
    except FileNotFoundError:
        pass

print(f'display notification {json.dumps(msg, ensure_ascii=False)} with title "Claude Code" sound name "Glass"')
PY
)

[ -n "$RESULT" ] && echo "$RESULT" | osascript 2>>"$LOG"
exit 0
