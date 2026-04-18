# code-agent-notify

给代码代理 CLI 做 macOS 系统通知。目前支持：
- Claude Code
- Codex CLI

## Claude Code

Claude Code 在需要你操作或回复完毕时，通过 macOS 系统通知 + 提示音提醒你，防止晾着终端错过。

### 特性

- 权限/选择/空闲等事件 → 右上角 banner + Glass 音
- Claude 回复结束 → banner + Funk 音（Stop hook）
- 同一会话内「waiting for your input」空闲提醒只响**第一次**，不会每 60 秒骚扰；响应其他事件后自动重置

### 安装

```bash
# 1. 克隆
git clone https://github.com/mankaki/code-agent-notify.git
cd code-agent-notify

# 2. 放到 ~/.claude/
cp notify.sh stop.sh claude-notify.py ~/.claude/
chmod +x ~/.claude/notify.sh ~/.claude/stop.sh ~/.claude/claude-notify.py

# 3. 合并 hooks 到 ~/.claude/settings.json
#    —— 文件不存在就直接复制 settings.json
#    —— 已有内容（env、model 等）只合并 "hooks" 字段，别整个覆盖
```

合并后大概长这样：

```json
{
  "env": { "...": "..." },
  "model": "opus[1m]",
  "hooks": {
    "Notification": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "~/.claude/notify.sh" }] }
    ],
    "Stop": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "~/.claude/stop.sh" }] }
    ]
  }
}
```

改完 `~/.claude/settings.json` 后**重启 Claude Code CLI**。

## Codex CLI

Codex 在一轮回复结束时，通过 macOS 系统通知提醒你。

### 特性

- 回复结束 → banner + Funk 音
- 兼容 `task_complete` / `agent-turn-complete` 两种完成事件
- 正文优先显示 `last_agent_message`，兼容旧字段 `last-assistant-message`
- 自动压缩长文本：去 markdown、去路径/行号、只取首句、超长截断
- 遇到 Codex review 结果时，优先提炼 findings / 首条结论，避免整段原文塞满通知

### 安装

```bash
# 1. 放到 ~/.codex/
cp codex-notify.py ~/.codex/
chmod +x ~/.codex/codex-notify.py

# 2. 在 ~/.codex/config.toml 里加
notify = ["python3", "/Users/你的用户名/.codex/codex-notify.py"]
notification_condition = "always"
tui.notifications = true
```

## 依赖

- macOS（`osascript`）
- `python3`（macOS 自带，或 `brew install python`）

## 调试

- Claude Code 错误日志：`${TMPDIR:-/tmp}/claude-notify.log`
- Codex 错误日志：`${TMPDIR:-/tmp}/codex-notify.log`
- Claude 去重状态文件：`${TMPDIR:-/tmp}/claude-notify-<session_id>.waiting`

## 调整

- **换提示音**：改脚本里的 `Glass` / `Funk`，可选 Basso / Blow / Bottle / Frog / Funk / Glass / Hero / Morse / Ping / Pop / Purr / Sosumi / Submarine / Tink
- **自定义 Claude 去重**：改 `claude-notify.py` 里对 `waiting for your input` 的判断
- **自定义 Codex 摘要压缩**：改 `codex-notify.py` 里的 `compact_text()`

## 参考

- [Claude Code Hooks Guide](https://code.claude.com/docs/zh-CN/hooks-guide)
- [Codex Documentation](https://developers.openai.com/codex)
