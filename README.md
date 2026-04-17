# claude-code-notify

Claude Code 在需要你操作或完成任务时，通过 macOS 系统通知 + 分类提示音提醒你，防止晾着终端错过。

## 特性

- **消息分类**：权限 / 选择 / 错误 / 空闲 / 任务完成，各有不同音效
  - 权限确认 → Hero 声
  - 等你选项 → Ping 声
  - 错误/限流 → Basso 声
  - 空闲等待 → Glass 声，同会话只响第一次
  - 任务完成 → Funk 声
- **通知标题带项目名**：「Claude Code · 豆瓣转notion」，多会话一眼分清
- 纯 banner，不弹对话框、不抢焦点

## 依赖

- macOS（用 `osascript` 弹通知和对话框）
- `python3`（macOS 自带，或 `brew install python`）

> macOS 26 (Tahoe) 上 `terminal-notifier` 的点击回调已失效（Apple 弃用了 `NSUserNotification`），所以不再依赖它。

## 安装

```bash
# 1. 克隆到任意位置
git clone https://github.com/mankaki/claude-code-notify.git
cd claude-code-notify

# 2. 放到 ~/.claude/
cp notify.sh session-start.sh stop.sh ~/.claude/
chmod +x ~/.claude/notify.sh ~/.claude/session-start.sh ~/.claude/stop.sh
cp icon.png ~/.claude/icon.png   # Claude logo，对话框会用它；没有就 fallback 系统图标

# 3. 合并 hooks 到你的 ~/.claude/settings.json
#    —— 如果文件不存在，直接复制 settings.json 过去
#    —— 如果已有内容（env、model 等），只把 "hooks" 字段合并进去，别整个覆盖
```

合并后的 `~/.claude/settings.json` 大概长这样：

```json
{
  "env": { "...": "..." },
  "model": "opus[1m]",
  "hooks": {
    "SessionStart": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "~/.claude/session-start.sh" }] }
    ],
    "Notification": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "~/.claude/notify.sh" }] }
    ],
    "Stop": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "~/.claude/stop.sh" }] }
    ]
  }
}
```

## 生效

新开 Claude Code 会话自动生效。当前正在运行的会话需要打开一次 `/hooks` 菜单（或重启 CLI）让配置重载。

## 工作原理

- **SessionStart** hook 把 `session_id + cwd` 存到 `/tmp/claude-notify-<sid>.meta`
- **Notification** hook 读 meta 拿项目名，按关键词分类，派发到 banner 或 dialog
- **Stop** hook 弹「任务完成」通知，清理 meta 文件
- 空闲去重用 `/tmp/claude-notify-<sid>.waiting` 做标记

## 调整

- **换提示音**：改 `notify.sh` 里的 `case "$KIND"` 段；可选 Basso / Blow / Bottle / Frog / Funk / Glass / Hero / Morse / Ping / Pop / Purr / Sosumi / Submarine / Tink
- **自定义消息分类**：`notify.sh` 里 python3 段的 `if/elif` 分支，加关键词就加关键词
- **让对话框抢焦点**：把 `tell application "System Events"` 换成 `tell application id "$APP_BUNDLE" to activate`，再 `display dialog ...`
- **调试**：`claude --debug` 能看到 hook 执行日志

## 参考

- [Hooks Guide](https://code.claude.com/docs/zh-CN/hooks-guide)
