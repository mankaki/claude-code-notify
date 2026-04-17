#!/bin/bash
# Claude Code Notification hook: macOS notification + sound.
#
# Dedup logic: within the same session, the "waiting for your input"
# idle reminder only notifies the first time; it's silenced on subsequent
# triggers (Claude Code re-fires it every ~60s). Any other notification
# (permission, selection, etc.) resets the state so the next idle reminder
# will notify again.
#
# Dependencies: python3 (macOS 自带), osascript (macOS 自带).

input=$(cat)

IFS=$'\t' read -r SID MSG IS_IDLE <<< "$(printf '%s' "$input" | python3 -c '
import json, sys
try:
    d = json.loads(sys.stdin.read())
except Exception:
    d = {}
msg = (d.get("message") or "Claude needs your attention").replace("\n"," ").replace("\r"," ").replace("\t"," ")
sid = (d.get("session_id") or "default").replace("\t","_")
is_idle = "1" if "waiting for your input" in msg.lower() else "0"
print(f"{sid}\t{msg}\t{is_idle}")
')"

state="/tmp/claude-notify-${SID}.waiting"

if [ "$IS_IDLE" = "1" ]; then
  [ -f "$state" ] && exit 0
  touch "$state"
else
  rm -f "$state"
fi

python3 -c '
import json, sys
msg = sys.argv[1]
print(f"display notification {json.dumps(msg)} with title \"Claude Code\" sound name \"Glass\"")
' "$MSG" | osascript 2>/dev/null || true
