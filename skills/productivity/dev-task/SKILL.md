---
name: dev-task
description: "Use when the user says '实现', '开发', '加功能', '改代码', '写代码', '修复', '重构'. Run a 5-phase multi-sub-agent dev workflow: 拆任务→探索→编码→审查→收尾. Three sub-agents are context-isolated; the main agent hand-copies context between phases. Phase 3 (review) is mandatory — runs in a sub-agent and emits PASS/WARN/FAIL with a final verdict (通过 / 有条件通过 / 不通过). Project-type agnostic (Java / Python / Node / Go / etc). Hard limits on task size, file blacklist, sub-agent tool whitelist, and 9-item DoD enforced at Phase 0 / 4."
disable-model-invocation: true
user-invocable: true
license: MIT
compatibility: "Agent-agnostic. Sub-agent constraint blocks use operation descriptions (not tool names) — works across hermes, claude code, codex, aider. Cross-agent tool name mapping in body § 工具映射 and references/phase-prompts.md § Agent tool name mapping. Requires git and a project manifest (pom.xml / package.json / requirements.txt / go.mod / Cargo.toml)."
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Task, AskUserQuestion
metadata:
  version: "1.4.0"
  author: ejuer
  hermes:
    tags: [workflow, multi-agent, dev, automation, orchestration]
---

# /dev-task — 多子代理开发工作流

主代理（你）按 5 phase 流程执行。每个 phase 有明确目标、输入、输出、工具调用。

**审核（Phase 3）是流程必备**，跑在 `delegate_task` spawn 的独立子代理里。Phase 3 必跑、出 PASS/WARN/FAIL、Phase 4 必处理 FAIL。

---

## 设计哲学

设计此类多子代理 SOP skill 时，**先区分"流程必备"和"用户选择"**：

| 类型 | 例子 | 处理 |
|------|------|------|
| **流程必备**（不问） | 5 phase 流程、子代理约束、Phase 3 审核、信息串联 | 直接写进 SOP，不列在"决策点"问 |
| **用户选择**（问） | commit 时机、FAIL 重试、文档同步、测试/lint、worktree | 用 clarify 问 A/B/C |

**判定标准**：这个改动会让 SOP 跑不通吗？是 → 流程必备；否 → 用户选择。

反例：把"Phase 3 审核要不要跑"列成决策点问用户 — 错。审核是流程骨架的一部分，必跑、必出 PASS/WARN/FAIL、Phase 4 必处理。

---

## 触发判断

读取用户消息中 `/dev-task` 之后的文本（即 `$ARGUMENTS`）：

- **为空** → 停下来问：「要做什么？请描述具体任务、涉及哪些文件、有没有验收标准」
- **非空** → 进入 Phase 0

---

## Phase 0: 拆任务

**工具**：`todo` + `terminal` + `clarify`

**步骤**：

### 0.1 worktree 询问（决策 5B）

如果当前目录是 git 仓库（`git rev-parse --is-inside-work-tree` 返回 true），用 `clarify` 问用户：

```
当前在 git 仓库。要不要开 worktree 隔离开发？
- A: 开 worktree（自动 git worktree add ../<branch>）
- B: 直接在当前目录改
```

- 用户选 A → `git worktree add ../dev-task-<任务简写> -b dev-task/<任务简写>`，后续所有操作在 worktree 目录跑
- 用户选 B → 继续在当前目录

### 0.2 拆任务

用 `todo` 创建 5 个追踪项：
1. Phase 1 探索
2. Phase 2 编码
3. Phase 3 审查
4. Phase 4 收尾（含文档同步 + 询问 commit）
5. 总汇报

第一个标 `in_progress`。

提取 `$ARGUMENTS` 关键信息：任务目标、涉及范围、验收标准。

### 0.3 输出

todo list（用户可见）+ 内部记录工作目录、任务摘要、worktree 路径（如有）

---

## Phase 1: 探索（只读子代理）

**工具**：`delegate_task`

**调用**：

```
delegate_task(
  goal="探索上下文：理解 {任务} 需要改哪些文件、有什么已有代码、规范是什么",
  context=<见 references/phase-prompts.md 的 Phase 1 模板>,
  toolsets=["file", "terminal", "search"]
)
```

**子代理约束**（必须写进 prompt）：

- **只读**！不要调 write_file / patch
- terminal 只能用只读命令：ls / cat / grep / head / tail / git status / git log / git diff
- 禁止：rm / mv / git commit / npm install / pip install / 任何改状态的操作

**输出要求**（结构化）：

1. 相关文件列表（绝对路径）
2. 现有 API / 接口 / 类
3. 规范约定（命名 / 注释 / 错误处理）
4. 风险点
5. 建议实现路径

**主代理动作**：完整保存到主代理上下文，下一 phase 用。

---

## Phase 2: 编码（general 子代理）

**工具**：`delegate_task` + `clarify`

### 2.1 编码

```
delegate_task(
  goal="编码：按 Phase 1 探索结果实现 {任务}",
  context="任务：$ARGUMENTS\n\n=== Phase 1 探索结果 ===\n{完整贴入}\n\n<其他要求见 references/phase-prompts.md 的 Phase 2 模板>",
  toolsets=["file", "terminal", "search"]
)
```

**输出要求**：
1. 改动的文件列表（绝对路径 + 类型：新增/修改/删除）
2. 每个文件的关键改动说明
3. 未完成项（如有）

### 2.2 跑测试询问（决策 4B）

Phase 2 编码完成后，用 `clarify` 问用户：

```
编码完成。改动文件：{列表}
要不要跑项目自带的测试 / lint？
- A: 跑（请告诉我命令，比如 mvn test / npm test / pytest）
- B: 不跑
```

- 用户选 A → 跑用户指定的命令，把结果记录到上下文（Phase 3 审查要参考）
- 用户选 B → 跳过

### 2.3 主代理动作

把编码结果 + 测试结果（如有）保存，Phase 3 用。

---

## Phase 3: 审查（独立 general 子代理）**【流程必备】**

**工具**：`delegate_task` + `clarify`

### 3.1 审查子代理调用

```
delegate_task(
  goal="代码审查：对照规范和 Phase 1 基线审查 Phase 2 的改动",
  context="任务：$ARGUMENTS\n\n=== Phase 1 探索结果（基线） ===\n{完整贴入}\n\n=== Phase 2 改动 ===\n{完整贴入}\n\n=== 测试结果（如有） ===\n{贴入}

<审查维度 + 输出格式见 references/phase-prompts.md 的 Phase 3 + references/output-format.md>",
  toolsets=["file", "terminal", "search"]
)
```

**子代理约束**：
- **独立上下文**，不带 Phase 2 的"思维惯性"
- 5 个审查维度：规范遵守 / 完整性 / 安全性 / 可维护性 / 文档同步
- 每条意见用 `[PASS] / [WARN] / [FAIL]` 前缀
- 末尾必须总结（通过 / 有条件通过 / 不通过）

### 3.2 FAIL 重写询问（决策 2B）

Phase 3 输出"不通过"（≥1 FAIL）时，用 `clarify` 问用户：

```
Phase 3 审查发现 {N} 个 FAIL：
{FAIL 列表摘要}

要不要自动回 Phase 2 重写？
- A: 重写（重新跑 Phase 2 + Phase 3，最多循环 2 次）
- B: 不重写，让 Phase 4 主代理手动修
- C: 自己手动处理（跳出 /dev-task 流程）
```

- 用户选 A → 重新跑 Phase 2 + Phase 3（**只把 FAIL 项贴回 Phase 2 prompt**），最多循环 2 次
- 用户选 B → 继续 Phase 4
- 用户选 C → 退出流程，把现状交还用户

### 3.3 主代理动作

把 Phase 3 完整审查结果保存，Phase 4 用。

---

## Phase 4: 收尾（主代理执行，不 spawn 子代理）

### 4.1 修 FAIL

- 把 Phase 3 的 FAIL 项过一遍
- 能修就修（用 `patch` / `write_file`）
- 修不了的 → 标 `[BLOCKED]`，写明原因
- 修完后**重跑 Phase 3 验证**（如果之前选了 A 自动重写循环，这步跳过）

### 4.2 文档同步（决策 3A 全自动）

**自动**做：
- 项目有 `README.md` → 是否有新增功能/命令/API 需要写进去？自动改
- 项目有 `CHANGELOG.md` → 追加本次改动（用 LLM 总结）
- 项目有 `docs/` → 检查是否需要新增/修改对应章节

不需要询问用户。

### 4.3 询问 commit（决策 1B）

用 `clarify` 给用户看最终汇总：

```
所有 FAIL 已修完，文档已同步。

改动文件：
{完整列表}

新增/修改的 FAIL 修复：{列表}

要不要 git commit？
- A: Commit（自动生成 commit message 预览）
- B: 不 commit，留给用户
```

- 用户选 A → 自动 `git add` + `git commit -m "{自动生成的 message}"`，message 格式：`<type>: <任务简写>`

  type 推断规则：
  - "实现" / "加" / "新增" → `feat`
  - "修复" / "修" / "bug" → `fix`
  - "重构" / "优化" → `refactor`
  - "改" / "更新" → `chore`
- 用户选 B → 跳过

### 4.4 更新 todo + 汇报

- 所有 todo 标 `completed`
- 给用户最终汇报（结构化）：
  1. 改了什么文件
  2. 修了哪些 FAIL
  3. BLOCKED 项（如有）
  4. 文档同步了哪些
  5. commit 信息（如已 commit）

---

## 串联规则（关键）

- 上下文**全部**靠主代理手动复制粘贴到子代理 context
- **不要假设**子代理能看见别的子代理的输出
- Phase 1 → Phase 2：完整贴 Phase 1 输出
- Phase 1 + Phase 2 → Phase 3：两个都完整贴
- Phase 3 → Phase 4：执行修复建议

---

## 不做的事（避免越界）

- ❌ 不做自动 push（commit 后留给用户）
- ❌ 不预设项目类型（Java / Python / Node 都行）
- ❌ 不调 GitHub API（提 PR 让用户来）
- ❌ 不改 git config（用户邮箱/姓名不在 skill 管）

---

## 工具映射

| Claude Code | Hermes | 说明 |
|------------|--------|------|
| `Agent` | `delegate_task` | spawn 子代理 |
| `TaskCreate` | `todo add` | 新建追踪项 |
| `TaskUpdate` | `todo merge` | 更新状态 |
| `Read` | `read_file` | 读文件 |
| `Write` / `Edit` | `write_file` / `patch` | 写文件 |
| `Bash` | `terminal` | 跑命令 |
| `Grep` / `Glob` | `search_files` | 搜内容/文件 |
| `WebFetch` | `web` 工具集 | 抓网页 |
| `AskUserQuestion` | `clarify` | 询问用户 |

---

## 硬限制 + 文件黑名单 + 工具白名单（v1.4）

**Phase 0 自检硬指标**：文件 ≤ 20 / 行 ≤ 1000 / 模块 < 5 / `$ARGUMENTS` ≥ 10 字符 / git repo + manifest 必须存在。不满足 → 标错误码退出。

**子代理黑名单**：禁止改/读 manifest、密钥、agent 配置、构建产物。违反 → `[BLOCKED]`。

**子代理工具白名单**：Phase 1/3 只读，Phase 2 可写。所有子代理禁嵌套 spawn、禁 `clarify`、禁 `execute_code`。

完整规则（含错误码表、DoD 9 条清单）→ `references/hard-limits.md`。


## 决策汇总（v1.4）

| 决策点 | 行为 | Phase |
|-------|------|-------|
| git commit / FAIL 重写 / 跑测试 / worktree | 询问（`clarify`） | 0.1 / 2.2 / 3.2 / 4.3 |
| 文档同步 / 硬限制兜底 | 全自动 | 4.2 / 各 Phase |
| **审核（Phase 3）** | **流程必备** | **必跑，不参与决策** |

错误码表 + DoD 9 条 → `references/hard-limits.md`。用户连选 C 3 次 → `[USER_ABANDONED]` 退出。

---

## 何时加载 references

Phase 1 / 2 / 3 启动前，先把 prompt 模板读入上下文，再组装子代理 context：

| Agent | 操作 |
|-------|------|
| Hermes | `skill_view(name="dev-task", file_path="references/phase-prompts.md")` |
| Claude Code | `Read` → `<skill-dir>/references/phase-prompts.md` |
| Codex / Aider / 其他 | 直接读取 skill 目录下的 `references/phase-prompts.md` 文件 |

Phase 3 启动前同理，还要加载 `references/output-format.md` 给审查子代理看输出格式。

---

## Compatibility

Cross-agent tool mapping: `## 工具映射` table maps Hermes tool names (`delegate_task`, `terminal`, `write_file`, `patch`, `read_file`, `search_files`, `clarify`, `todo`) to Claude Code tool names (`Task`, `Bash`, `Write`, `Edit`, `Read`, `Grep`, `Glob`, `AskUserQuestion`, `TodoWrite`).
