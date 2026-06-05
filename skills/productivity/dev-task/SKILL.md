---
name: dev-task
description: 5-phase 多子代理开发工作流（拆任务→探索→编码→审查→收尾）。三子代理上下文隔离，串联靠主代理手动复制粘贴。审核（Phase 3）是流程必备，跑在子代理里。
version: 1.4.0
author: ejuer
triggers:
  - 实现
  - 开发
  - 加功能
  - 改代码
  - 写代码
  - 修复
  - 重构
metadata:
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

---

## 硬限制（v1.4 新增）

主代理在 Phase 0 / Phase 2 / Phase 4 之前**必须**自检以下硬指标，任一不满足直接标对应错误码退出，不进入后续 phase。

**任务规模**：

- 单次 /dev-task 改动文件 ≤ 20；超出 → 主代理标 `[SCOPE_TOO_LARGE]` 并退出，让用户拆小
- 单次新增代码行 ≤ 1000；超出同上
- 任务预期时长 > 1 周（涉及 5+ 个模块 / 跨多个子系统）→ 强制拆成多次 /dev-task
- Phase 1 探索产出"建议改文件列表" > 25 → 标 `[SCOPE_TOO_LARGE]` 退出

**输入质量**：

- $ARGUMENTS 必须含三要素：目标（goal）/ 涉及范围（scope）/ 验收标准（acceptance）
- 缺任一要素 → 用 `clarify` 追问（最多 2 轮，超过 2 轮用户还没给齐 → 退出）
- 模糊度硬指标：$ARGUMENTS 字符数 < 10 → 直接标 `[INPUT_TOO_VAGUE]` 退出

**环境前提**（在 Phase 0 之前必须满足）：

- 必须在 git 仓库（`git rev-parse --is-inside-work-tree` true）；不是 → 问用户 `git init` 还是退出
- 必须有项目 manifest（pom.xml / package.json / requirements.txt / go.mod / Cargo.toml 之一）；缺 → 标 `[NO_MANIFEST]` 退出
- 首次跑前主代理必须能定位"编译命令"；找不到 → 标 `[NO_BUILD_CMD]` 退出

---

## 文件黑名单（v1.4 新增）

**子代理绝对禁止改**（除非 $ARGUMENTS 明确说"修改 X 文件"，且主代理二次确认）：

- `pom.xml` / `build.gradle` / `build.gradle.kts` / `package.json` / `package-lock.json` / `requirements.txt` / `go.mod` / `Cargo.toml`
- `.gitignore` / `.gitattributes` / `.git/` 任何文件
- `CLAUDE.md` / `AGENTS.md` / `.cursorrules` / `.windsurfrules`
- `.env` / `.env.*` / `*.key` / `*.pem` / `*.p12` / `secrets/` / `credentials/`
- `Dockerfile` / `docker-compose.yml` / `Dockerfile.*`
- `~/.hermes/config.yaml` / `~/.hermes/.env` / `~/.hermes/skills/*/SKILL.md`
- `node_modules/` / `target/` / `build/` / `dist/` / `.venv/`

**子代理绝对禁止读**：

- `.env` / `.env.*` / `*.key` / `*.pem` / `*.p12`
- `~/.ssh/` / `~/.gnupg/`
- 任何 `secrets/` / `credentials/` 目录

**子代理改黑名单文件时**：主代理必须 `[BLOCKED]` + 列出被改的具体文件 + 给出修复建议让用户手动处理。

---

## 子代理工具白名单（v1.4 新增）

**Phase 1 探索子代理**：

- toolsets: `["file", "terminal", "search"]`
- 实际可调：read_file / search_files / terminal（只读命令）
- **禁止** 调：write_file / patch / edit / notebook_edit / web 工具集（除非任务明确要联网查文档）

**Phase 2 编码子代理**：

- toolsets: `["file", "terminal", "search"]`
- 可调：write_file / patch / read_file / search_files / terminal
- **禁止** 调：delegate_task（防嵌套）/ clarify / memory / send_message / execute_code（leaf 工具黑名单已自动禁）

**Phase 3 审查子代理**：

- toolsets: `["file", "terminal", "search"]`
- 可调：read_file / search_files / terminal（只读）
- **禁止** 调：write_file / patch（审查不该改代码）/ delegate_task / clarify / memory

**所有子代理通用**：

- 禁止 spawn 任何子子代理（max_spawn_depth=1 已硬保证）
- 禁止调主代理专属的 clarify（统一问主代理）
- 禁止调 execute_code（保留主代理独占）

---

## 完成定义 DoD（v1.4 新增）

Phase 4 收尾前主代理**必须**逐条 check：

- [ ] 改动文件列表完整（来自 Phase 2 + Phase 4 修复的并集）
- [ ] Phase 3 输出含 PASS/WARN/FAIL 标签 + 末尾"通过/有条件通过/不通过"
- [ ] FAIL 数 = 0（如果 > 0，标 [INCOMPLETE] 退出，不进 commit 询问）
- [ ] 至少跑一次编译/类型检查（命令用户指定 / 推断）且输出"build success"或等价
- [ ] `git diff --stat` 输出包含在最终汇报
- [ ] `git status` 输出包含在最终汇报
- [ ] BLOCKED 项（如果有）必须列在汇报顶部，标红
- [ ] 文档同步（README / CHANGELOG / docs/）已做（如有）
- [ ] todo 全部 completed

**任一不满足** → 标 `[DOD_FAIL]`，先补完再走 commit 询问。

---

## 错误处理兜底（v1.4 新增）

| 失败标签 | 触发条件 | 主代理动作 |
|---------|---------|-----------|
| `[INPUT_TOO_VAGUE]` | $ARGUMENTS < 10 字符 | 退出，要求用户重写 |
| `[SCOPE_TOO_LARGE]` | 文件 > 20 / 行 > 1000 / 涉及 5+ 模块 | 退出，要求用户拆小 |
| `[NO_MANIFEST]` | 缺项目 manifest | 退出，提示用什么 init |
| `[NO_BUILD_CMD]` | 找不到编译命令 | 退出，让用户指定 |
| `[TIMEOUT]` | 子代理 600s 超时 | 标 [TIMEOUT]，问用户重跑 or 跳过 |
| `[NO_CHANGE]` | Phase 2 子代理没改任何文件 | 重跑 1 次，再 0 改动则 [INCOMPLETE] 退出 |
| `[FORMAT_FAIL]` | Phase 3 输出无 PASS/WARN/FAIL | 重跑 1 次强调格式，再失败则主代理手动审查 |
| `[INCOMPLETE]` | Phase 3 仍有 FAIL / Phase 2 0 改动 | 退出，列未完成项 |
| `[BLOCKED]` | Phase 4 改不了 FAIL / 碰到黑名单 | 转人工，列具体阻塞点 |
| `[DOD_FAIL]` | DoD 9 条任一不满足 | 先补完，再走 commit |

**用户连续选 C 3 次**（任何询问）→ 自动 `[USER_ABANDONED]` 退出，整个流程终止，把现状交还。

**子代理试图违反黑名单**：主代理在最终汇报标 `[CHILD_VIOLATION]` + 警告。

---

## 决策汇总（v1.4）

| 决策点 | 行为 | 实现 |
|-------|------|------|
| 1. git commit | 询问 | Phase 4.3 `clarify` |
| 2. FAIL 重写 | 询问 | Phase 3.2 `clarify` |
| 3. 文档同步 | 全自动 | Phase 4.2 |
| 4. 跑测试 / lint | 询问 | Phase 2.2 `clarify` |
| 5. worktree 隔离 | 询问 | Phase 0.1 `clarify` |
| **审核（Phase 3）** | **流程必备** | **必跑、不参与决策** |
| 7. 硬限制兜底 | 自动 | 上述错误处理表 |

---

## 何时加载 references

- Phase 1 / 2 / 3 启动前：用 `skill_view(name="dev-task", file_path="references/phase-prompts.md")` 加载子代理 prompt 模板
- Phase 3 启动前：还要加载 `references/output-format.md` 给审查子代理看格式

---

## 失败模式

| 失败 | 处理 |
|------|------|
| Phase 1 子代理试图写文件 | 在最终汇报里标注，警告用户 |
| Phase 2 子代理没改任何文件 | 重跑 Phase 2，明确说"必须输出 diff" |
| Phase 3 子代理输出没有 PASS/WARN/FAIL 标签 | 重跑，强调格式 |
| Phase 4 主代理改不了 FAIL | 标 [BLOCKED]，转人工 |
| 用户在询问中选 C | 退出流程，把现状交还 |
| 任务太大 / 模糊 | 回到 Phase 0，让用户拆小 |
| 触发 SCOPE_TOO_LARGE / NO_CHANGE / DOD_FAIL | 按错误处理表执行 |
| 触发 INPUT_TOO_VAGUE / NO_MANIFEST | 立即退出，提示用户 |
| 用户连续选 C 3 次 | USER_ABANDONED 退出 |
