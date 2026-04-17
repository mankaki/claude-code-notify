#!/bin/bash
input=$(cat)
msg=$(printf '%s' "$input" | jq -r '.message // ""')
sid=$(printf '%s' "$input" | jq -r '.session_id // "default"')
state="/tmp/claude-notify-${sid}.waiting"

if printf '%s' "$msg" | grep -qi "waiting for your input"; then
  [ -f "$state" ] && exit 0
  touch "$state"
else
  rm -f "$state"
fi

printf '%s' "$input" | jq -r '"display notification " + ((.message // "Claude needs your attention") | @json) + " with title \"Claude Code\" sound name \"Glass\""' | osascript 2>/dev/null || true
