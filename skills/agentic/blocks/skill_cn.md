---
layout: default
name: blocks
description: "当用户说 'blocks', '分块', '分屏', '2x2', '2*2', '四宫格', '分配N个员工', '起N个worker', 'manager+workers'，或在 Hermes 会话中输入 `/blocks` 斜杠命令时使用。在一个全新的 tmux 窗口中并行生成 N 个 Hermes 代理。两种模式：(1) **平铺模式** — N 个 tmux 窗格，每个运行一个独立的 Hermes（N 必须为偶数 2/4/6/8，默认为 2x2）；(2) **管理者模式** — 当前 Hermes 聊天成为管理者（不额外增加 tmux 窗格），N 个工作窗格以 2 行 × (N/2) 列的网格生成，并通过 `~/blocks-shared/<session>/{tasks,results,done,summary}.md` 文件协调。两种模式在启动 Hermes 前都会先均分窗格大小（拆分 shell → resize-pane 使大小均匀 → 启动代理）。**同时还提供了一个真正的 hermes 斜杠命令**（`/blocks [N|--manager --workers N|list|kill|attach]`），已添加到 `hermes_cli/commands.py` 和 `cli.py`；在 Hermes 会话中，`/blocks` 和自然语言触发词是等效的。"
version: 1.10.0
author: Hermes Agent
license: MIT
platforms: [macos, linux]
metadata:
  hermes:
    tags: [tmux, panes, parallel, multi-agent, hermes, workflow, manager, worker, orchestration]
    related_skills: [hermes-agent]
---

# Blocks — 在 tmux 窗格中并行运行 Hermes

> **已确认在 v1.6.0 版本中可用。** 核心配方（生成 N 个窗格 + 发送角色提示 + 带文件系统协调的管理者模式）自 v1.6.0 以来一直稳定，在后续的次版本中未更改。

### 新内容

- **v1.7.0** — 重组了配方（将不同 N 的会话尺寸合并为每种模式的一个规范表格 — 平铺模式（200/200/240/320）和管理者模式（200/220/300/380），后者为 N 个工作输出增加了缓冲区；添加了 `select-layout tiled` 决策表；删除了重复的“端到端使用”描述）。修复了 4 个硬性错误：单次触摸 → 两次触摸的工作协议，指向 `macos-tmux-crash-recovery.md` 的死链接，无效的 `DISABLE_BLOCKS_AUTOOPEN` 锚点，以及重复的 `tmux-server-recovery.md` frontmatter 条目。
- **v1.8.0** — 添加了**真正的 `/blocks` 斜杠命令**（`hermes_cli/commands.py` + `cli.py` 补丁）。在 Hermes 会话中，`/blocks [N|2x2|--manager --workers N|list|kill|attach]` 现在等同于用自然语言说“blocks ...”。
- **v1.9.0** — 生成后在 macOS/Linux 上自动打开一个可见的终端窗口（写入 `/tmp/blocks-attach-<session>.command` 并用 `open` 打开；设置 `DISABLE_BLOCKS_AUTOOPEN=1` 可退出）。`/blocks` 处理程序现在会生成工作窗口并为用户弹出一个终端窗口。

## 概述

一个 shell 命令，N 个并行的 Hermes 代理并排运行。该技能封装了 tmux split-window + send-keys，用于生成一个 N 窗格的窗口，其中每个窗格运行一个独立的 Hermes CLI 进程（可选择使用不同的 `-p` 配置文件，以实现技能/内存/会话的完全隔离）。所有代理都在一个视口中可见 — 无需在标签页中寻找，一个 `prefix` 键即可切换，关闭窗口即可清理。

默认是 2x2（四个窗格，平铺），分别使用 `coder` / `researcher` / `reviewer` / `ops` 配置文件。所有内容都可覆盖。

## 快速开始

对于完整的、可变量 N、可自定义配置文件的配方（带有角色提示、等待休眠、错误处理），请参阅下面的[配方：2x2 默认值](#recipe-2x2-default-the-canonical-pattern)。

对于**管理者模式**，配方在[配方：在 tmux 中生成 N 个工作窗口](#recipe-spawn-n-workers-in-tmux-the-only-recipe-blocks---manager-needs) — 但更简单的方法是直接在你的 Hermes 聊天中说“分配 4 个员工”或“blocks --manager”，让这个技能处理其余部分（参见下面的调用流程）。

对于在调试 blocks 时可能遇到的 tmux 问题（base-index 偏移、分离状态下的尺寸、鼠标配置等），请参阅下面的 [tmux 拆分方向参考](#tmux-split-direction-reference) 和 [常见陷阱](#common-pitfalls) 部分。

## 偶数规则

**N 必须是偶数（2, 4, 6, 8）。** 奇数数量无法在网格中完美均分，`tiled` 会给你一个被拉伸的窗格。如果用户要求奇数 N（例如 3, 5），将其增加到下一个偶数并告知用户。常见数量：

| N | 布局 | 形状 |
|---|--------|------|
| 2 | 1×2 或 2×1 | 并排或上下 |
| 4 | 2×2 | 网格（默认）|
| 6 | 2×3 或 3×2 | 网格 |
| 8 | 2×4 或 4×2 | 网格 |
| > 8 | 不推荐 | 窗格对 prompt_toolkit 来说太小 |

**按 N 划分的会话尺寸**（平铺模式的规范 — 配方：2 窗格，配方：6 窗格，配方：8 窗格）：

| N | tmux `new-session -x W -y H` | 每个窗格尺寸 (W/(N/2) × H/2) |
|---|------------------------------|------------------------------|
| 2 | `-x 200 -y 50` | 100×25 |
| 4 | `-x 200 -y 50` | 100×25（2 列）|
| 6 | `-x 240 -y 50` | 80×25（3 列）|
| 8 | `-x 320 -y 50` | 80×25（4 列）|

高度始终为 50（prompt_toolkit 每个窗格大约需要 25 行；2 行 × 25 = 50）。宽度随 N 增加，以便最小的窗格保持 ≥80 个单元格宽。

**管理者模式使用更宽的缓冲区**（N=4 时 +20%，N=6/8 时 +25%），以便工作窗格有更多水平空间来显示长差异/表格。由[配方：在 tmux 中生成 N 个工作窗口](#recipe-spawn-n-workers-in-tmux-the-only-recipe-blocks---manager-needs) 使用：

| N | tmux `new-session -x W -y H` | 工作窗格尺寸 (W/(N/2) × H/2) |
|---|------------------------------|------------------------------|
| 2 | `-x 200 -y 50` | 100×25 |
| 4 | `-x 220 -y 50` | 110×25 |
| 6 | `-x 300 -y 50` | 100×25 |
| 8 | `-x 380 -y 50` | 95×25 |

两种策略都满足“最小窗格保持 ≥80 个单元格宽”（管理者模式 ≥95，平铺模式 ≥80）。对于随意多代理场景使用平铺模式（较小），当工作窗口预期产生较宽输出时使用管理者模式（较大）。

“操作顺序”是这个技能中唯一最重要的事情：

```
1. 使用显式的 -x -y 创建会话
2. 拆分为 N 个空的 shell 窗格
3. 强制每个窗格达到精确相等的大小 (resize-pane)
4. （仅对于 2xN 网格）可选地使用 select-layout tiled 作为安全网
5. 然后向每个窗格发送 'hermes'
6. 等待 6 秒，然后附加
```

**关键：** `select-layout tiled` 对于方形网格（2x2, 2x3, 2x4）是安全的，但会**破坏** 1+N 结构（管理者 + 工作窗口）。对于管理者模式，只依赖 `resize-pane` — 永远不要调用 tiled。见陷阱 16。

永远不要在拆分 + 启动 hermes 的同一个循环中操作。prompt_toolkit 会抢占焦点并混淆拆分器，导致一个高列和三个被压扁的窗格。

## 何时使用

- 用户说“blocks 2x2”、“分四块”、“四宫格”、“起 4 个 hermes 并排跑”
- 用户想要在一个屏幕上驱动多个代理（例如，一个写代码，一个研究，一个审查）
- 用户希望在后台运行长时间代理但仍可见
- 用户想要并排 A/B 比较提示/模型

不要用于：
- 一个快速任务 → 直接运行 `hermes chat -q "..."` 即可
- 真正长时间自主运行且不需要终端的任务 → `hermes chat -q "..."` 后台运行，或使用 `cronjob`
- 多个代理编辑同一个 git 仓库 → 在此技能基础上添加 `-w`（工作树）（参见下面的多仓库代码）

## 斜杠命令（Hermes 会话中的 `/blocks`）

从 v1.8.0 开始，此技能在自然语言触发之外，还提供了一个**真正的 hermes 斜杠命令**。在任何 Hermes 会话中，输入 `/blocks [args]` 会执行与相应自然语言短语相同的操作 — 但更可靠，因为斜杠命令已在 `hermes_cli/commands.py` 中注册，并像任何内置命令一样通过 `HermesCLI.process_command` 分发。

**已测试可用的参数（全部通过 `expect` 端到端测试）：**

| 斜杠命令 | 等同于 |
|---------------|----------------|
| `/blocks` | 4 个平铺窗格（默认）|
| `/blocks 2` | 2 个平铺窗格（1×2）|
| `/blocks 6` | 6 个平铺窗格（3×2）|
| `/blocks 2x2` | 4 个平铺窗格（2×2）|
| `/blocks --manager` | 管理者模式，4 个工作窗口 |
| `/blocks --manager --workers 6` | 管理者模式，6 个工作窗口 |
| `/blocks list` | 列出所有 `blocks-*` tmux 会话 |
| `/blocks kill` | 杀死所有 `blocks-*` tmux 会话 |
| `/blocks attach` | 重新附加到最近的 blocks 会话（使用 `os.execvp`，因此调用 shell 被替换 — 正确的 TTY 交接）|
| `/blocks attach blocks-mgr-140959` | 重新附加到特定会话（子字符串匹配）|

**在 hermes 源代码树中打了补丁的文件**（位于 `~/.hermes/hermes-agent/`）：

1. `hermes_cli/commands.py` — 添加一个 `CommandDef`：
   ```python
   CommandDef("blocks", "Spawn N even-sized tmux panes each running an isolated Hermes, or activate Manager mode (...)", "Blocks",
              cli_only=True,
              subcommands=("list", "kill", "attach", "--manager"),
              args_hint="[N|2x2|4|6|8|list|kill|attach|--manager [--workers N]]"),
   ```
   这为 `/help` 提供了一个清晰的条目，使标签补全工作，并让 `resolve_command` 找到它。

2. `cli.py` — 在 `HermesCLI` 类中添加两处：
   - `_handle_blocks_command(self, cmd_original: str)` — 解析参数（`/blocks list`, `/blocks --manager --workers 4` 等）并分派到相应的操作。
   - `_blocks_spawn_workers(self, n: int, manager_mode: bool = False)` — 实际的 tmux 拆分 + send-keys + 角色提示逻辑（相当于“配方：在 tmux 中生成 N 个工作窗口”部分的 Python 实现，而不是 bash）。
   - 在 `process_command` 中添加一行：`elif canonical == "blocks": self._handle_blocks_command(cmd_original)`。

**补丁中固定且关键的部分：**

- 处理程序运行已验证的按情况拆分序列（N=2/4/6/8，按正确顺序使用 `split-window -h`/`-v`，base-index 1），然后通过 `resize-pane` 强制每个窗格达到 `PANE_W x PANE_H` — 绝不使用 `select-layout tiled`（陷阱 16）。
- 斜杠命令处理程序中**特意省略**了 `select-layout tiled`。它会破坏性地重新计算网格。
- 处理程序在调用 `send-keys` 前后分别休眠 1 秒和 6 秒（陷阱 6，“send-keys 上的竞争条件”→ prompt_toolkit 需要约 5-7 秒来渲染）。
- “管理者模式已激活”横幅使用纯 `print()`（而不是 `cprint`）打印，以便可以从 `~/.hermes/logs/agent.log` 中 grep。
- 奇数 N 向上取整到下一个偶数发生在 BEFORE 进入 `if/elif` 拆分序列分派之前，因此 N=2/4/6/8 的分派始终获得有效的 N。

**⚠️ 回归风险：** 补丁位于 `~/.hermes/hermes-agent/`，这是一个 git 检出工作树。运行 `hermes update` 将拉取上游并覆盖它。有两种方法可以保护工作成果：
- 将补丁提交到 `hermes-agent` 的一个分支，并从该分支重新安装。
- 保存差异：`cd ~/.hermes/hermes-agent && git diff cli.py hermes_cli/commands.py > ~/.hermes/patches/blocks-slash-command.patch`，然后在更新后使用 `git apply` 重新应用。

**为什么即使有斜杠命令，自然语言触发仍然有价值：** 斜杠命令仅在 Hermes 会话**内部**工作。如果用户想从普通终端（不在聊天中）生成 blocks，自然语言路径也没有帮助 — 他们需要运行“配方：2x2 默认值”部分中的 bash，或者如果脚本可用，运行 `bash ~/.hermes/skills/blocks/scripts/blocks.sh`。

## 语法

用户通过对话方式调用它。解析意图并调用匹配的配方。

| 用户说 | 操作 |
|-----------|--------|
| `blocks` / `分块` | 2x2 默认值（coder, researcher, reviewer, ops）|
| `blocks 2x2` / `blocks 2*2` / `4 个` / `四宫格` | 2x2 默认配置文件 |
| `blocks 2` / `blocks 2x1` / `左右两个` | 2 个窗格，偶数垂直 |
| `blocks 1x2` / `blocks 2v` / `上下两个` | 2 个窗格，偶数水平 |
| `blocks 6` / `6 个` | 2x3 网格，平铺 |
| `blocks 4 coder designer writer pm` | 2x2 使用自定义配置文件名称 |
| `blocks 3x2` | 3 列 × 2 行（6 个窗格）|
| `blocks list` / `kill` / `attach` | 生命周期 — 参见[配方：列表 / 附加 / 杀死](#recipe-list--attach--kill) |
| `blocks --manager` / `blocks --manager --workers 4` / `分配 4 个员工` | 激活管理者模式 + 以 2x2 网格生成 4 个工作窗格 |
| `blocks --manager --workers 6` / `分配 6 个员工` | 激活管理者模式 + 以 3x2 网格生成 6 个工作窗格 |
| `blocks --manager --workers 2` / `分配 2 个员工` | 激活管理者模式 + 以 1x2 网格生成 2 个工作窗格 |
| `blocks --manager --workers N` / `分配 N 个员工` | N 必须是偶数（2/4/6/8）；如果用户说奇数 N，向上取整并告知 |
| `/blocks`（斜杠命令，在 Hermes 会话内）| 4 个平铺窗格（默认）— 等同于 `blocks 4` |
| `/blocks 2` / `/blocks 6` / `/blocks 2x2`（斜杠命令）| N 个平铺窗格 — 等同于 `blocks N` 或 `blocks 2x2` |
| `/blocks --manager`（斜杠命令）| 以 4 个工作窗口激活管理者模式 |
| `/blocks --manager --workers 6`（斜杠命令）| 以 6 个工作窗口激活管理者模式 |
| `/blocks list`（斜杠命令）| 列出所有 `blocks-*` tmux 会话（处理程序还公开了 `blocks attach`, `blocks kill` — 参见[斜杠命令部分](#slash-command-blocks-inside-a-hermes-session)）|

**奇数 N（3, 5, 7）：** 向上取整到下一个偶数并告知用户。`blocks 3` → 静默变为 `blocks 4` 并警告。`blocks 5` → `blocks 6`，依此类推。

配置文件回退：如果请求的配置文件不存在，则回退到默认配置文件（不带 `-p` 标志），而不是失败。

## 管理者/工作模式（`blocks --manager`）

对于受益于协调大脑和 N 只并行手的任务：用户给出一个任务，**当前的 Hermes 会话成为管理者**，将任务分解为 N 个子任务，将其分派给 N 个工作窗口（在 tmux 窗格中运行），等待结果，汇总，并在主聊天中向用户报告。

**管理者是当前的聊天，而不是 tmux 窗格。** 这是关键的设计选择：用户始终在主 Hermes 对话中与管理对话。N 个工作窗口存在于 tmux 窗格中，以便用户可以直观地监控其进度。无需将焦点切换到“管理者窗格” — 根本不存在这样的窗格。

### 调用流程（如果你是管理者，请先阅读此部分）

你（这个 Hermes 会话）即将成为管理者。以下是确切的流程：

```
用户触发                   Hermes 执行
─────────────────────────────────────────────────────────────────────
"blocks --manager"          →   通过终端工具运行“配方：在 tmux 中生成 N 个工作窗口”部分中的配方。
                                 配方输出：
                                   "✓ Manager mode activated.
                                    Session: blocks-mgr-XXXXX
                                    Workers: N panes in tmux session ...
                                    Shared: /Users/ejuer/blocks-shared/..."

                              →   向用户确认：
                                   "管理者模式已开启。已生成 N 个工作窗口。
                                    请把任务交给我。"

用户："把 X 跑通并对比 baseline"
                              →   将原话保存到 $SHARED/task.md
                              →   分解为 N 个子任务，写入 $SHARED/tasks/worker-N.md
                              →   在聊天中告诉用户计划
                              →   大约每 60 秒轮询 $SHARED/done/

（tmux 中的工作窗口执行工作，写入结果，触摸 done 文件）

                              →   当所有 done 文件都存在时：
                                   读取 results/worker-*.md，写入
                                   $SHARED/summary.md，在聊天中粘贴摘要。

用户："kill it"              →   `blocks kill`（或直接告诉用户自己运行）
```

**触发管理者模式的指令**（用户消息中的任何一个）：

- `blocks --manager` — 默认 4 个工作窗口
- `blocks --manager --workers N` — N 个工作窗口（N 必须为偶数，否则向上取整）
- `blocks --manager --workers 6` — 显式 N
- `分配 4 个员工` / `分配 6 个员工` / `分配 N 个员工` — 中文
- `起 4 个 worker` / `起 N 个 worker` / `起 4 个 hermes` — 中文变体
- `manager+workers` / `manager mode` / `4 panes with manager` — 英文变体
- `我要 manager` / `manager 模式` / `拆给 4 个员工做` — 语义变体

当你看到其中任何一个时，**在你的终端工具中执行配方**。配方的最后输出是“管理者模式已激活”横幅。打印横幅后，**你就是管理者** — 从这一刻起，每个用户消息都是管理者角色的任务。

> **分块提示（请先阅读）：** 默认的每个工作窗口 10 分钟超时是**上限**，而不是目标。在 macOS 上，完全分离的 tmux 服务器可能在 10 多分钟后被 launchd 回收 — 参见陷阱 18。将工作分成**6 分钟的轮次**（硬性上限 7 分钟），并带有显式的 `done/` 信号，并且在生成后附加到 tmux 会话（以便 launchd 将其视为用户附加的），或者准备好从文件系统恢复。参见 `references/tmux-server-recovery.md`。

**关键：不要仅仅将工作流程描述为文本。** 你必须实际通过终端工具执行 `tmux new-session`, `tmux send-keys` 和 `mkdir` 等操作。配方包含确切的 bash。运行它，然后成为管理者。

### 布局

```
┌─────────┬─────────┬─────────┐
│ 工作窗口 1│ 工作窗口 2│         │
│ (顶部)   │ (顶部)   │  ...    │  N 个窗格的网格
├─────────┼─────────┼─────────┤
│ 工作窗口 3│ 工作窗口 4│         │
│ (底部)   │ (底部)   │         │
└─────────┴─────────┴─────────┘

N=2: 1 列 × 2 行      N=6: 3 列 × 2 行
N=4: 2 列 × 2 行      N=8: 4 列 × 2 行
```

工作窗口在一个全新的 tmux 窗口中形成 2 行 × (N/2) 列的网格。N 必须是偶数（2/4/6/8）。用户默认**不在** tmux 会话中 — 工作窗口是可见的，但用户通过主聊天与管理者交互。（如果需要直接查看，可以 `tmux attach` 到会话，或使用 `blocks attach`。）

### 通信协议（基于文件系统）

```
~/blocks-shared/<session-name>/
├── task.md                    # 用户的原始任务（管理者写入）
├── plan.md                    # 管理者写入其计划
├── tasks/
│   ├── worker-1.md            # 分派给 worker-1 的子任务
│   ├── worker-2.md
│   ├── worker-3.md
│   └── worker-4.md
├── results/
│   ├── worker-1.md            # Worker-1 将其结果写入此处
│   ├── worker-2.md
│   └── ...
├── done/
│   ├── worker-1               # `touch` = worker-1 完成
│   ├── worker-2
│   └── ...
└── summary.md                 # 所有完成后，管理者在此处汇总
```

**为什么用文件而不是 tmux send-keys：** 管理者是一个 LLM，而不是一个确定性控制器。告诉它“使用 send-keys 来分派任务”会使 LLM 负责 tmux 语法、窗格索引和竞争条件。文件简单、幂等、可检查，并且能在管理者重启后幸存。它们还允许用户随时通过 `ls ~/blocks-shared/<session>/` 检查系统状态。

### 每个工作窗口知道什么（作为 hermes 启动后的第一条消息传递）

```
你是 blocks 会话 <SESSION> 中的 worker-N。

你的子任务：阅读 ~/blocks-shared/<SESSION>/tasks/worker-N.md

协议（必需 — 防止 tmux 服务器崩溃，参见陷阱 18）：
  1. **启动后 30 秒内**：`touch ~/blocks-shared/<SESSION>/done/worker-N-start`
     这表示“我已启动”。如果 tmux 服务器在任务中途崩溃，管理者仍然可以看到工作窗口收到了任务。如果没有这个文件，管理者会认为工作窗口从未启动。
  2. 执行任务文件中的子任务
  3. 将最终结果写入 `~/blocks-shared/<SESSION>/results/worker-N.md`
  4. `touch ~/blocks-shared/<SESSION>/done/worker-N-final`

不要启动任何不在任务文件中的工作。不要触碰其他工作窗口的文件。
如果你需要帮助，将问题写入 results/worker-N.md 并停止。
```

### 管理者知道什么（这就是你，当前的 Hermes 会话）

当用户调用 `blocks --manager` 或“分配 N 个员工”时，配方会在 tmux 中生成 N 个工作窗口并输出激活消息。**你（这个 Hermes）成为管理者。** 从这一刻起，此聊天中的每个用户消息都是管理者角色的任务或后续操作。

**管理者协议（请仔细阅读）：**

```
你是 blocks 会话 <SESSION> 中的管理者。

你有 N 个工作窗口：worker-1 ... worker-N。它们在 tmux 会话 <SESSION> 中运行。

你的工作：
  1. 用户会将一个任务粘贴到此聊天中。将其原样保存到：
     ~/blocks-shared/<SESSION>/task.md
  2. 将任务分解为 N 个子任务（每个工作窗口一个，或者更少，有些标记为 SKIPPED）。
     对于每个 worker-i，写入 ~/blocks-shared/<SESSION>/tasks/worker-i.md
  3. 将你的整体计划保存到 ~/blocks-shared/<SESSION>/plan.md
  4. 轮询完成情况：每 60 秒运行 `ls ~/blocks-shared/<SESSION>/done/`
     当所有预期的工作窗口文件都存在时，继续。
  5. 读取 results/worker-*.md，汇总，写入 ~/blocks-shared/<SESSION>/summary.md
  6. 直接在此聊天中向用户报告摘要。

超时：每个工作窗口**6 分钟的轮次**（硬性上限 7 分钟）。更长的窗口（10 分钟以上）存在 macOS 服务器在轮次中途崩溃的风险，导致所有工作窗口死亡且无法恢复 — 参见 references/tmux-server-recovery.md 和陷阱 18。如果 `done/worker-N-start` 存在但 `done/worker-N-final` 超过 6 分钟仍然缺失，则将工作窗口视为卡住。超时后，向用户报告卡住的工作窗口，并询问是继续等待还是跳过它继续。

你可以在 tmux 会话 <SESSION> 中查看工作窗口的 tmux 窗格。用户可以通过 `tmux attach -t <SESSION>` 附加来观察它们。如果工作窗口卡住，你可以通过 `tmux send-keys -t <SESSION>:1.<pane> 'message' Enter` 来推动它 — 但规范的协调是通过文件系统进行的。
```

**激活消息格式（由 blocks 脚本打印）：**

```
✓ 管理者模式已激活。
  会话：     blocks-mgr-135421
  工作窗口：   tmux 会话 blocks-mgr-135421 中有 4 个窗格
  共享目录：   /Users/ejuer/blocks-shared/blocks-mgr-135421
  协议：      $SHARED/tasks/ 用于子任务，$SHARED/done/ 用于完成信号

请告诉我你的任务。我会将其分解为 4 个子任务，分派给工作窗口，
轮询结果，然后在此处报告。
```

当用户看到这个时，他们知道管理者模式已激活。他们回复一个任务，你（这个 Hermes）遵循协议。

### 启动命令

```bash
blocks --manager              # 2x2 网格中的 4 个工作窗口（默认）
blocks --manager --workers 6  # 3x2 网格中的 6 个工作窗口
blocks --manager --workers 2  # 1x2 网格中的 2 个工作窗口
```

用户自然地调用：
- `blocks --manager`（或 `分配 4 个员工`, `起 4 个 worker`, `4 panes with manager`）
- `blocks --manager --workers 6`（或 `分配 6 个员工`, `6 panes with manager`）

### 配方：在 tmux 中生成 N 个工作窗口（blocks --manager 需要的唯一配方）

这是工作模板。它只生成工作窗口 — 管理者是调用的 Hermes 会话，而不是 tmux 窗格。

```bash
# N 是工作窗口的数量（必须为偶数：2/4/6/8）。默认为 4。
N=${BLOCKS_WORKERS:-4}
SESSION="blocks-mgr-$(date +%H%M%S)"
SHARED="$HOME/blocks-shared/$SESSION"

# 1. 创建共享目录结构
mkdir -p "$SHARED"/{tasks,results,done}

# 2. 会话大小：更多工作窗口需要更宽（每个工作窗口至少需要 50 个单元格宽）
W=200
H=50
if [ "$N" -ge 4 ]; then W=220; fi
if [ "$N" -ge 6 ]; then W=300; fi
if [ "$N" -ge 8 ]; then W=380; fi
tmux new-session -d -s "$SESSION" -x $W -y $H

COLS=$((N/2))

# 3. 构建 N 个工作窗口网格：2 行 × (N/2) 列。
#    已验证的拆分序列 — 不要使用 select-layout tiled（它会破坏性地重新计算网格）。
#    只需拆分 + resize-pane。
#
#    按情况拆分的序列（经验验证，base-index 1）：
#      N=2: 在 1.1 上 split-v  → 1.1 (顶部), 1.2 (底部)
#      N=4: 在 1.1 上 split-h，然后在 1.1 和 1.2 上分别 split-v
#           → 1.1 左上, 1.2 右上, 1.3 左下, 1.4 右下
#      N=6: 与 4 相同，然后在 1.2 上 split-h 并在 1.4 上 split-h
#           → 添加 1.5（1.2 的右侧）和 1.6（1.4 的右侧）
#      N=8: 与 6 相同，然后在 1.5 上 split-h 并在 1.6 上 split-h
#           → 添加 1.7 和 1.8
if [ "$N" -eq 2 ]; then
  tmux split-window -v -t "$SESSION":1
elif [ "$N" -eq 4 ]; then
  tmux split-window -h -t "$SESSION":1
  tmux split-window -v -t "$SESSION":1.1
  tmux split-window -v -t "$SESSION":1.2
elif [ "$N" -eq 6 ]; then
  tmux split-window -h -t "$SESSION":1
  tmux split-window -v -t "$SESSION":1.1
  tmux split-window -v -t "$SESSION":1.2
  tmux split-window -h -t "$SESSION":1.2
  tmux split-window -h -t "$SESSION":1.4
elif [ "$N" -eq 8 ]; then
  tmux split-window -h -t "$SESSION":1
  tmux split-window -v -t "$SESSION":1.1
  tmux split-window -v -t "$SESSION":1.2
  tmux split-window -h -t "$SESSION":1.2
  tmux split-window -h -t "$SESSION":1.4
  tmux split-window -h -t "$SESSION":1.5
  tmux split-window -h -t "$SESSION":1.6
fi

# 4. 强制均等调整大小（仅 resize-pane，不要 select-layout tiled）
PANE_W=$((W / COLS))
PANE_H=$((H / 2))
ALL_PANES=$(tmux list-panes -t "$SESSION" -F '#{pane_index}')
for p in $ALL_PANES; do
  tmux resize-pane -t "$SESSION":1.$p -x $PANE_W -y $PANE_H
done

# 5. 将窗格标记为 worker-1..worker-N（从左到右，从上到下）
i=1
for p in $ALL_PANES; do
  tmux select-pane -t "$SESSION":1.$p -T "worker-$i"
  i=$((i+1))
done

# 6. 在每个工作窗格中启动 hermes
sleep 1
i=1
for p in $ALL_PANES; do
  tmux send-keys -t "$SESSION":1.$p 'hermes' Enter
  i=$((i+1))
done

# 7. 等待 prompt_toolkit，然后发送工作窗口角色提示
sleep 6
i=1
for p in $ALL_PANES; do
  WORKER_PROMPT="You are worker-$i in blocks session $SESSION. \
Read $SHARED/tasks/worker-$i.md. \
Protocol (REQUIRED): \
  1. Within 30s of starting: touch $SHARED/done/worker-$i-start \
  2. Read tasks/worker-$i.md, do the work, append to results/worker-$i.md \
  3. When done: touch $SHARED/done/worker-$i-final \
(start touch is the liveness signal — the Manager polls it; final touch means 'I finished')"
  tmux send-keys -t "$SESSION":1.$p "$WORKER_PROMPT" Enter
  i=$((i+1))
done

# 8. 输出激活消息（这是调用的 Hermes 读取的内容）
cat <<EOF
✓ 管理者模式已激活。
  会话：     $SESSION
  工作窗口：   tmux 会话 $SESSION 中有 $N 个窗格
  共享目录：   $SHARED
  协议：      \$SHARED/tasks/ 用于子任务，\$SHARED/done/ 用于完成信号

请告诉我你的任务。我会将其分解为 $N 个子任务，分派给工作窗口，
轮询结果，然后在此处报告。
EOF
```

> **实现说明：** 上面的 2x3 和 2x4 情况是存根 — 此草案中 N>4 的列扩展逻辑不完整。对于 2x3，在构建 2x2 之后，需要**在每个**行的最右侧窗格上 split-h 以添加第三列。对于 2x4，重复。一般模式是：首先构建一个 2x2，然后对于每个额外的列，在每行的最右侧窗格上 split-h。窗格索引每次都会改变，所以最简洁的方法是使用 `tmux list-panes` 动态找到最右侧的窗格，或者在 `select-pane` 到最右侧窗格后使用 `-t :1`（活动窗格）。

### 端到端使用

端到端使用已由上面的[调用流程](#invocation-flow-read-this-first-if-you-are-the-manager)部分涵盖（显示用户触发 → Hermes 操作用于管理者→工作窗口轮的每一步）。这里没有单独的演练。

### 在打开的终端内部（按键和捕获）

`/blocks` 生成会话后，会弹出一个终端窗口并附加到该