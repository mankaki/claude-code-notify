#!/usr/bin/env python3
import json
import os
import subprocess
import sys

TMP = (os.environ.get("TMPDIR") or "/tmp").rstrip("/")
LOG = f"{TMP}/codex-notify.log"

MESSAGES = {
    "agent_turn_complete": "Codex 回复完了",
    "default": "Codex 在呼叫你",
}


def notify(text, sound="Glass"):
    cmd = (
        f"display notification {json.dumps(text, ensure_ascii=False)} "
        f'with title "Codex" sound name "{sound}"'
    )
    with open(LOG, "a") as log:
        subprocess.run(["osascript", "-e", cmd], stderr=log, check=False)


def summarize(payload):
    kind = payload.get("type") or ""
    last = (payload.get("last-assistant-message") or "").strip()
    inputs = payload.get("input-messages") or []

    if kind == "agent-turn-complete":
        if last:
            text = last.replace("\n", " ").replace("\r", " ").strip()
            if len(text) > 120:
                text = text[:117] + "..."
            return text, "Funk"
        if inputs:
            return MESSAGES["agent_turn_complete"], "Funk"
        return MESSAGES["agent_turn_complete"], "Funk"

    return MESSAGES["default"], "Glass"


def main():
    if len(sys.argv) < 2:
        sys.exit(0)
    try:
        payload = json.loads(sys.argv[1])
    except Exception:
        notify(MESSAGES["default"], "Glass")
        sys.exit(0)

    text, sound = summarize(payload)
    notify(text, sound)


if __name__ == "__main__":
    main()
