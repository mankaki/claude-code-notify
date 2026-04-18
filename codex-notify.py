#!/usr/bin/env python3
import json
import os
import re
import subprocess
import sys

TMP = (os.environ.get("TMPDIR") or "/tmp").rstrip("/")
LOG = f"{TMP}/codex-notify.log"

MESSAGES = {
    "task_complete": "Codex 回复完了",
    "default": "Codex 在呼叫你",
    "review_complete": "Code review 完成",
    "review_findings": "Review: {summary}",
    "review_passed": "Review passed",
    "review_failed": "Review failed",
}

COMPLETE_TYPES = {"agent-turn-complete", "task_complete", "review_ended", "exited_review_mode"}


def notify(text, sound="Glass"):
    cmd = (
        f"display notification {json.dumps(text, ensure_ascii=False)} "
        f'with title "Codex" sound name "{sound}"'
    )
    with open(LOG, "a") as log:
        subprocess.run(["osascript", "-e", cmd], stderr=log, check=False)


def first_nonempty(*values):
    for value in values:
        if isinstance(value, str):
            stripped = value.strip()
            if stripped:
                return stripped
    return ""


def looks_like_review_text(text):
    low = text.lower()
    return (
        "code review finished" in low
        or "review comment:" in low
        or "full review comments:" in low
        or low.startswith("findings")
        or low.startswith("review:")
    )


def looks_like_review_payload(payload):
    if not isinstance(payload, dict):
        return False
    if payload.get("schema") == "code_review":
        return True
    findings = payload.get("findings")
    overall = payload.get("overall_correctness")
    return isinstance(findings, list) and overall in ("patch is correct", "patch is incorrect")


def summarize_review_text(text):
    compact = text.replace("\r", "").strip()
    compact = re.sub(r"^<<\s*Code review finished\s*>>\s*", "", compact, flags=re.IGNORECASE)
    compact = re.sub(r"^[-•]\s*Worked for .*?$", "", compact, flags=re.MULTILINE)
    compact = re.sub(r"^[-•]\s*$", "", compact, flags=re.MULTILINE)
    compact = compact.strip()

    lines = [line.strip() for line in compact.splitlines() if line.strip()]
    normalized = []
    for line in lines:
        if re.fullmatch(r"[─━—_-]{3,}", line):
            continue
        normalized.append(re.sub(r"^[-•]\s*", "", line).strip())

    for idx, line in enumerate(normalized):
        low = line.lower()
        if low in ("review comment:", "full review comments:", "findings:", "review:"):
            for next_line in normalized[idx + 1 :]:
                next_low = next_line.lower()
                if next_low in ("review comment:", "full review comments:", "findings:", "review:"):
                    continue
                if next_line and not re.fullmatch(r"[─━—_-]{3,}", next_line):
                    return next_line
            return MESSAGES["review_complete"]

    for line in normalized:
        low = line.lower()
        if low in ("findings:", "review:"):
            continue
        if line and not re.fullmatch(r"[─━—_-]{3,}", line):
            return line
    return MESSAGES["review_complete"]


def summarize_review_json(text):
    try:
        payload = json.loads(text)
    except Exception:
        return ""
    if not looks_like_review_payload(payload):
        return ""

    findings = payload.get("findings")
    overall = (payload.get("overall_correctness") or "").strip().lower()
    if not isinstance(findings, list):
        if overall == "patch is correct":
            return MESSAGES["review_passed"]
        if overall == "patch is incorrect":
            return MESSAGES["review_failed"]
        return MESSAGES["review_complete"]
    if not findings:
        if overall == "patch is correct":
            return MESSAGES["review_passed"]
        if overall == "patch is incorrect":
            return MESSAGES["review_failed"]
        return MESSAGES["review_complete"]

    first = findings[0]
    if not isinstance(first, dict):
        if overall == "patch is correct":
            return MESSAGES["review_passed"]
        if overall == "patch is incorrect":
            return MESSAGES["review_failed"]
        return MESSAGES["review_complete"]

    title = (first.get("title") or "").strip()
    body = (first.get("body") or "").strip()
    summary = title or body
    if not summary:
        if overall == "patch is correct":
            return MESSAGES["review_passed"]
        if overall == "patch is incorrect":
            return MESSAGES["review_failed"]
        return MESSAGES["review_complete"]
    return MESSAGES["review_findings"].format(summary=summary)


def compact_text(text):
    review_json = summarize_review_json(text)
    if review_json:
        text = review_json
    elif looks_like_review_text(text):
        text = summarize_review_text(text)

    text = text.replace("\n", " ").replace("\r", " ").strip()
    text = re.sub(r"`([^`]*)`", r"\1", text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"\1", text)
    text = re.sub(r"\[(.*?)\]\((.*?)\)", r"\1", text)
    text = re.sub(r"(^|\s)#{1,6}\s*", " ", text)
    text = re.sub(r"/Users/\S+", "", text)
    text = re.sub(r"(?:^|(?<=[\s(]))(?:[\w.~/-]+/)?[\w.-]+\.(?:py|ts|tsx|js|jsx|rs|go|java|kt|swift|c|cc|cpp|h):\d+\b", "", text)
    text = re.sub(r":\s*(?:,\s*)+(?=\S)", ": ", text)
    text = re.sub(r"\s*,\s*(?=,|[，。.!?；;]|$)", "", text)
    text = re.sub(r",\s*,+", ", ", text)
    text = re.sub(r"\s+", " ", text).strip(" -:;,.，。")

    for sep in ("。", "！", "？", ". ", "! ", "? ", "；", ";"):
        if sep in text:
            text = text.split(sep, 1)[0]
            break

    if len(text) > 48:
        text = text[:45].rstrip() + "..."
    return text or MESSAGES["task_complete"]


def summarize(payload):
    kind = payload.get("type") or ""
    last = first_nonempty(
        payload.get("last_agent_message"),
        payload.get("last-assistant-message"),
        payload.get("last_assistant_message"),
    )
    review_output = payload.get("review_output")
    inputs = payload.get("input-messages") or payload.get("input_messages") or []

    if kind in COMPLETE_TYPES:
        if isinstance(review_output, dict) and looks_like_review_payload(review_output):
            return compact_text(json.dumps(review_output, ensure_ascii=False)), "Funk"
        if last:
            return compact_text(last), "Funk"
        if inputs:
            return MESSAGES["task_complete"], "Funk"
        return MESSAGES["task_complete"], "Funk"

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
