#!/bin/bash
# Claude Code SessionStart hook: 把 session_id 和 cwd 存到 meta 文件，
# 给 notify.sh / stop.sh 查阅，用来在通知里显示项目名、区分多个会话。

input=$(cat)

printf '%s' "$input" | python3 -c '
import json, os, sys
try:
    d = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
sid = (d.get("session_id") or "default").replace("/", "_")
cwd = d.get("cwd") or os.getcwd()
with open(f"/tmp/claude-notify-{sid}.meta", "w") as f:
    json.dump({"cwd": cwd, "sid": sid}, f)
' 2>/dev/null
exit 0
