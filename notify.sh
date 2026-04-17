#!/bin/bash
# Claude Code Notification hook: macOS notification + sound.
# Permission-style messages additionally pop an AppleScript dialog that
# force-focuses the terminal (click-to-focus on the notification itself
# is broken on macOS 26 because NSUserNotification is deprecated).
#
# Dedup logic: within the same session, the "waiting for your input"
# idle reminder only notifies the first time; subsequent triggers
# (Claude Code re-fires it every ~60s) are silenced. Any other
# notification resets the state so the next idle reminder will notify
# again.
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

case "$TERM_PROGRAM" in
  vscode)          APP_NAME="Visual Studio Code" ;;
  cursor)          APP_NAME="Cursor" ;;
  iTerm.app)       APP_NAME="iTerm" ;;
  WezTerm)         APP_NAME="WezTerm" ;;
  ghostty)         APP_NAME="Ghostty" ;;
  Apple_Terminal)  APP_NAME="Terminal" ;;
  *)               APP_NAME="Terminal" ;;
esac
# APP_NAME 保留供将来扩展；当前版本不主动切换前台，以免打断你手上的事。

# 判断是不是需要人做决定的消息（权限/选择/确认）
NEEDS_DECISION=0
if printf '%s' "$MSG" | grep -qiE "permission|approve|confirm|choose|select|允许|拒绝|确认|选择"; then
  NEEDS_DECISION=1
fi

if [ "$NEEDS_DECISION" = "1" ]; then
  # 后台弹一个 modal dialog（不切换前台，用 System Events 显示），hook 立即返回不会超时。
  ( osascript <<APPLESCRIPT 2>/dev/null
tell application "System Events"
  display dialog $(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$MSG") with title "Claude Code" buttons {"去终端处理"} default button 1 with icon caution giving up after 120
end tell
APPLESCRIPT
  ) &
else
  # 普通通知：声音 + banner，点击无效但至少有提示音
  python3 -c '
import json, sys
print(f"display notification {json.dumps(sys.argv[1])} with title \"Claude Code\" sound name \"Glass\"")
' "$MSG" | osascript 2>/dev/null || true
fi
