#!/usr/bin/env python3
"""Claude Code 通知 hook 处理入口。

用法：
  claude-notify.py notification < event.json
  claude-notify.py stop         < event.json
"""
import json
import os
import re
import subprocess
import sys
import time

TMP = (os.environ.get("TMPDIR") or "/tmp").rstrip("/")
LOG = f"{TMP}/claude-notify.log"
STATE_PREFIX = "claude-notify-"
STATE_SUFFIX = ".waiting"
GC_MAX_AGE_SECONDS = 7 * 86400

MESSAGES = {
    "idle": "Claude 在等你输入",
    "permission": "Claude 请求使用 {tool} 的权限",
    "permission_generic": "Claude 请求权限",
    "needs_attention": "Claude 在呼叫你",
    "default": "Claude 在呼叫你",
    "stop": "Claude 回复完了",
}


def clean_sid(raw):
    return re.sub(r"[^A-Za-z0-9_-]", "_", raw or "default")[:64]


def state_path(sid):
    return f"{TMP}/{STATE_PREFIX}{sid}{STATE_SUFFIX}"


def gc_old_states():
    cutoff = time.time() - GC_MAX_AGE_SECONDS
    try:
        names = os.listdir(TMP)
    except FileNotFoundError:
        return
    for name in names:
        if not (name.startswith(STATE_PREFIX) and name.endswith(STATE_SUFFIX)):
            continue
        p = f"{TMP}/{name}"
        try:
            if os.path.getmtime(p) < cutoff:
                os.remove(p)
        except FileNotFoundError:
            pass


def classify(msg):
    """返回 (kind, translated_msg)。kind ∈ {'idle', 'permission', 'other'}。"""
    low = msg.lower()
    if "waiting for your input" in low:
        return "idle", MESSAGES["idle"]
    if "needs your permission" in low:
        match = re.search(r"permission to use\s+(.+?)\.?$", msg, re.IGNORECASE)
        if match:
            tool = match.group(1).strip()
            if tool and len(tool) < 80 and "\n" not in tool:
                return "permission", MESSAGES["permission"].format(tool=tool)
        return "permission", MESSAGES["permission_generic"]
    if "needs your attention" in low:
        return "other", MESSAGES["needs_attention"]
    return "other", msg


def notify(text, sound):
    cmd = (
        f"display notification {json.dumps(text, ensure_ascii=False)} "
        f'with title "Claude Code" sound name "{sound}"'
    )
    with open(LOG, "a") as log:
        subprocess.run(["osascript", "-e", cmd], stderr=log, check=False)


def normalize_msg(raw):
    msg = raw or MESSAGES["default"]
    for ch in ("\n", "\r", "\t"):
        msg = msg.replace(ch, " ")
    return msg.strip()


def handle_notification(event):
    msg = normalize_msg(event.get("message"))
    sid = clean_sid(event.get("session_id"))
    state = state_path(sid)
    kind, translated = classify(msg)

    if kind == "idle":
        if os.path.exists(state):
            return
        open(state, "w").close()
        gc_old_states()
    else:
        try:
            os.remove(state)
        except FileNotFoundError:
            pass

    notify(translated, "Glass")


def handle_stop(event):
    sid = clean_sid(event.get("session_id"))
    try:
        os.remove(state_path(sid))
    except FileNotFoundError:
        pass
    notify(MESSAGES["stop"], "Funk")


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ("notification", "stop"):
        sys.stderr.write("usage: claude-notify.py {notification|stop}\n")
        sys.exit(1)

    try:
        event = json.loads(sys.stdin.read() or "{}")
    except Exception:
        event = {}

    if sys.argv[1] == "notification":
        handle_notification(event)
    else:
        handle_stop(event)


if __name__ == "__main__":
    main()
