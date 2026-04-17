# claude-code-notify

Claude Code 在需要你操作（权限确认、选择、空闲等待输入等）时，通过 macOS 系统通知 + 提示音提醒你，防止晾着终端错过。

## 特性

- 权限请求、选择、等待输入等事件都会弹 macOS 通知 + Glass 提示音
- 同一会话内的「waiting for your input」空闲提醒只响**第一次**，不会每 60 秒骚扰你
- 一旦你响应过其他事件，状态重置，下次再空闲会再提醒一次

## 依赖

- macOS（用 `osascript` 弹原生通知）
- `python3`（macOS 自带，或 `brew install python`）

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

- **换提示音**：改 `notify.sh` 最后那行的 `Glass`，可选 Basso / Blow / Bottle / Frog / Funk / Glass / Hero / Morse / Ping / Pop / Purr / Sosumi / Submarine / Tink
- **自定义过滤**：`notify.sh` 里判断 `waiting for your input` 的那段就是去重规则，按需改
- **调试**：`claude --debug` 能看到 hook 执行日志

## 参考

- [Hooks Guide](https://code.claude.com/docs/zh-CN/hooks-guide)
