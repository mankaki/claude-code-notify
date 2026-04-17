#!/bin/bash
# Claude Code Stop hook: 会话结束时弹「任务完成 · 项目名」通知，并清理 meta 文件。

input=$(cat)

eval "$(printf '%s' "$input" | python3 -c '
import json, os, sys, shlex
try:
    d = json.loads(sys.stdin.read())
except Exception:
    d = {}
sid = (d.get("session_id") or "default").replace("/", "_").replace("\t","_")
cwd = ""
try:
    with open(f"/tmp/claude-notify-{sid}.meta") as f:
        cwd = (json.load(f).get("cwd") or "")
except Exception:
    pass
project = os.path.basename(cwd) if cwd else ""
print(f"SID={shlex.quote(sid)}")
print(f"PROJECT={shlex.quote(project)}")
')"

TITLE="Claude Code"
[ -n "$PROJECT" ] && TITLE="Claude Code · $PROJECT"

python3 -c '
import json, sys
title = sys.argv[1]
print(f"display notification \"任务完成\" with title {json.dumps(title)} sound name \"Funk\"")
' "$TITLE" | osascript 2>/dev/null || true

# 清理会话状态文件
rm -f "/tmp/claude-notify-${SID}.waiting" "/tmp/claude-notify-${SID}.meta"
exit 0
