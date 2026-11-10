# mojo-lark-agent

Turn a Lark / Feishu bot into a normal agent: people can search it, DM it, add it to group chats and
@mention it, and it answers with a full Claude Code session behind it, one per chat, with history.

This is the setup the Mojo team runs for its own Lark bot. It writes no bot code of its own: it is a
set of templates, scripts and lessons on top of [cc-connect](https://github.com/chenhg5/cc-connect)
(MIT), which bridges Lark's long-connection events to a local Claude Code process.

[中文说明](#中文说明)

## How it works

```
Lark user ──DM / @mention──► Lark Open Platform ──WebSocket (long connection)──► cc-connect
                                                                                   │ allow-list,
                                                                                   │ @-only in groups,
                                                                                   │ one session per chat
                                                                                   ▼
                                                     Claude Code (claude CLI, your subscription)
                                                     work_dir = agent folder:
                                                       CLAUDE.md               persona + rules
                                                       .claude/settings.json   permissions
                                                       groups/<chat_id>.md     per-chat context
                                                                                   │
                                                                     ListAgents / SendMessage
                                                                                   ▼
                                                     other Claude Code sessions on the machine
```

- **No public URL.** Lark pushes events over a WebSocket that cc-connect opens.
- **Per-chat sessions and history.** cc-connect resumes the same Claude session per chat and person.
- **Group context layer.** The agent keeps `groups/<chat_id>.md` per chat: what the group is for,
  who is who, standing instructions, decisions, and `route`, the Claude session that handles that
  group's work. Tell it once in the group and it remembers.
- **Hand-off to sessions.** When other Claude Code sessions run on the same machine (one per project,
  say), the agent can list them and message the right one.
- **Quiet output.** The chat shows only the final answer: no thinking, tool calls or footer.
- **Owner vs colleagues.** An allow-list decides who may talk to it; the persona gives colleagues
  read-only help and only acts on the Owner's requests.

## Set up

1. **Lark app** (open.larksuite.com or open.feishu.cn → Developer Console):
   - Add the **Bot** capability.
   - Permissions → Batch import → paste [`docs/lark-scopes.json`](docs/lark-scopes.json) (tenant scopes only).
   - Events & callbacks → subscription mode **long connection** for both events and callbacks; add the
     event `im.message.receive_v1` and the callback `card.action.trigger`. Lark only accepts the
     long-connection mode while a client is connected, so start cc-connect (step 3) first.
   - Availability: add everyone who should be able to find the bot, then create and publish a version.
2. **Install tools:** `brew install cc-connect`, the `claude` CLI logged in, `node`, `jq`, `python3`.
3. **Render an agent folder:**
   ```bash
   AGENT_DIR=~/agents/ada AGENT_NAME=Ada OWNER_NAME=Sam \
   OWNER_OPEN_ID=ou_xxx WORKSPACE_DIR=~/work ./scripts/install.sh
   ```
   Fill `~/.config/mojo-lark-agent/env` (`AGENT_APP_ID`, `AGENT_APP_SECRET`, `AGENT_ALLOW_FROM`).
   Don't know your open_id yet? Run `scripts/run.sh` with `AGENT_ALLOW_FROM=*` for a minute, send
   `/whoami` to the bot, then set the real list.
4. **Run it:** `"$AGENT_DIR"/scripts/run.sh` in a terminal, or `./scripts/install.sh --launchd`
   for a macOS LaunchAgent that restarts on failure (logs in `~/Library/Logs/<slug>.log`).
5. Edit `"$AGENT_DIR"/CLAUDE.md` for your context (product docs, who is who, what it may do).

Adding a colleague: add them to the app's availability (new version), get their open_id (contact API,
a shared group's member list, or `/whoami`), append it to `AGENT_ALLOW_FROM`, restart.

## Lessons (read these)

- **Trust the folder.** Claude Code ignores a project's `permissions.allow` and
  `additionalDirectories` until the folder is trusted. `install.sh` sets
  `projects[<dir>].hasTrustDialogAccepted = true` in `~/.claude.json`.
- **Permission mode.** cc-connect passes nothing for mode `default`, so a user-level
  `defaultMode: bypassPermissions` in `~/.claude/settings.json` would silently win. The template sets
  `defaultMode` in the project settings too. Deny rules apply in every mode.
- **Path rules.** In permission rules `/x` is relative to the project, `//x` is absolute, `~/x` is home.
- **macOS privacy.** launchd won't let `/bin/zsh` read `~/Documents`; `scripts/launch.mjs` starts it
  through `node` (as long as node has access). Keep the agent elsewhere to avoid this.
- **One client per app.** Lark spreads events across all long-connection clients of an app. Run one
  cc-connect per app, and stop old listeners (e.g. `lark-cli event +subscribe`) first.
- **Contact scope follows availability.** The bot can only look up users inside the app's availability.
- **Restart only when idle.** Restarting cc-connect kills a reply in progress.
- **Logs.** The Lark SDK logs incoming event payloads (message text) at debug level; no secrets.
- **Offline when the machine sleeps.** Move it to a server for 24/7; sessions on your laptop are then
  out of reach for hand-off.

## Files

| Path | What |
|---|---|
| `templates/config.toml` | cc-connect config: Lark long connection, allow-list, @-only groups, quiet display |
| `templates/CLAUDE.md` | persona, reply style, group-context layer, session hand-off, Owner vs colleagues |
| `templates/.claude/settings.json` | permission mode, read-only allow-list, deny rules for secrets and outward actions |
| `scripts/install.sh` | renders templates, trusts the folder, creates the env file, optional LaunchAgent |
| `scripts/run.sh`, `scripts/launch.mjs` | start cc-connect with secrets from the env file; launchd entry point |
| `docs/lark-scopes.json` | permissions to batch-import in the Lark console |

---

## 中文说明

把飞书 / Lark 机器人变成一个正常的 agent：能搜到、能私聊、能拉进群里 @，背后是完整的 Claude Code，
每个聊天一个会话，带历史。这是 Mojo 团队自己在用的方案，本身不写机器人代码，用的是开源的
[cc-connect](https://github.com/chenhg5/cc-connect)（MIT）把飞书长连接事件接到本机 Claude Code。

- **不需要公网地址**：飞书事件走长连接。
- **群组 context 层**：每个群一份 `groups/<chat_id>.md`，记群的用途、成员、长期规则、决定，以及
  `route`（这个群的任务交给哪个 Claude session）。在群里交代一次，它就记住。
- **转交 session**：同一台机器上跑着别的 Claude Code session 时，它能列出来并把任务发给对的那个。
- **只发最终答案**：不显示思考过程、工具调用和底部信息。
- **Owner 和同事分开**：白名单决定谁能用；同事只能问和读，改东西只听 Owner 的。

配置步骤见上面 Set up（飞书后台：机器人能力 → 批量导入 `docs/lark-scopes.json` → 事件和回调都选长连接，
加 `im.message.receive_v1` 和 `card.action.trigger` → 可用范围 → 发版本）。踩过的坑见 Lessons：
文件夹要设为可信、权限模式、路径写法、macOS 隐私限制、一个应用只能一个长连接、只在空闲时重启。

## License

MIT
