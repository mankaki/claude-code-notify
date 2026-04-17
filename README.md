# claude-code-notify

Claude Code 在需要你操作（权限确认、选择、空闲等待输入等）时，通过 macOS 系统通知 + 提示音提醒你，防止晾着终端错过。

## 特性

- 空闲提醒：macOS 原生通知 banner + Glass 提示音
- **权限/选择/确认**类事件：弹 AppleScript 对话框，显示 Claude 的原话和「去终端处理」按钮（不抢焦点，不打断你手上的事）
- 同一会话内「waiting for your input」空闲提醒只响**第一次**，不会每 60 秒骚扰
- 响应过其他事件后状态重置，下次再空闲会再提醒一次

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
cp notify.sh ~/.claude/notify.sh
chmod +x ~/.claude/notify.sh

# 3. 合并 hooks 到你的 ~/.claude/settings.json
#    —— 如果文件不存在，直接复制 settings.json 过去
#    —— 如果已有内容（比如 env、model），只把 "hooks" 字段合并进去，别整个覆盖
```

合并后的 `~/.claude/settings.json` 大概长这样：

```json
{
  "env": { "...": "..." },
  "model": "opus[1m]",
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "~/.claude/notify.sh" }
        ]
      }
    ]
  }
}
```

## 生效

新开 Claude Code 会话自动生效。当前正在运行的会话需要打开一次 `/hooks` 菜单（或重启 CLI）让配置重载。

## 调整

- **换提示音**：改 `notify.sh` 里的 `Glass`，可选 Basso / Blow / Bottle / Frog / Funk / Glass / Hero / Morse / Ping / Pop / Purr / Sosumi / Submarine / Tink
- **自定义去重**：`notify.sh` 里判断 `waiting for your input` 的那段就是去重规则，按需改
- **自定义「需要决策」的关键词**：`grep -qiE "permission|approve|confirm|choose|select|..."` 那行，加词就加关键词
- **让对话框抢焦点**：把 `tell application "System Events"` 改成 `tell application "$APP_NAME" to activate` 再 `display dialog ...`
- **调试**：`claude --debug` 能看到 hook 执行日志

## 参考

- [Hooks Guide](https://code.claude.com/docs/zh-CN/hooks-guide)
