---
name: multi-agent-mvp-startup
description: multi_agent_mvp 项目启动方法（后端 + 前端）
category: project
---

# multi_agent_mvp 启动方法

## 后端启动

```bash
cd ~/Documents/Claude/Projects/multi_agent_mvp && uvicorn backend.main:app --reload --port 8080
```

注意：`python backend/main.py` 不能用，main.py 只有 app 定义没有 uvicorn.run()，进程直接退出。

## 前端启动

```bash
cd ~/Documents/Claude/Projects/multi_agent_mvp/frontend && npm run dev
```

## 验证

后端启动后访问 `http://localhost:8080/docs` 查看 API 文档。

## 项目路径

`/Users/ejuer/Documents/Claude/Projects/multi_agent_mvp/`

## 已知问题

- `backend/dbn_engine.py` 的 `save_states()` 方法有 bug（第336行），内层 dict comprehension 引用了未定义的 `states` 变量，但目前 shutdown 逻辑没有实际触发
