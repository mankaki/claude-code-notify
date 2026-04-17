#!/bin/bash
# Claude Code Notification hook: macOS notification + sound.
# Click the notification → focus the terminal that spawned Claude Code.
#
# Dedup logic: within the same session, the "waiting for your input"
# idle reminder only notifies the first time; it's silenced on subsequent
# triggers (Claude Code re-fires it every ~60s). Any other notification
# (permission, selection, etc.) resets the state so the next idle reminder
# will notify again.
#
# Dependencies:
#   - python3 (macOS 自带)
#   - osascript (macOS 自带)
#   - terminal-notifier (可选，装了才能点击聚焦): brew install terminal-notifier

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

# Map $TERM_PROGRAM to macOS bundle ID for terminal-notifier -activate.
# Falls back to Terminal.app if unrecognized.
case "$TERM_PROGRAM" in
  vscode)          BUNDLE="com.microsoft.VSCode" ;;
  cursor)          BUNDLE="com.todesktop.230313mzl4w4u92" ;;  # Cursor
  iTerm.app)       BUNDLE="com.googlecode.iterm2" ;;
  WezTerm)         BUNDLE="com.github.wez.wezterm" ;;
  ghostty)         BUNDLE="com.mitchellh.ghostty" ;;
  Apple_Terminal)  BUNDLE="com.apple.Terminal" ;;
  *)               BUNDLE="com.apple.Terminal" ;;
esac

if command -v terminal-notifier >/dev/null 2>&1; then
  terminal-notifier \
    -title "Claude Code" \
    -message "$MSG" \
    -sound Glass \
    -sender "$BUNDLE" \
    -activate "$BUNDLE" \
    >/dev/null 2>&1 || true
else
  python3 -c '
import json, sys
print(f"display notification {json.dumps(sys.argv[1])} with title \"Claude Code\" sound name \"Glass\"")
' "$MSG" | osascript 2>/dev/null || true
fi
