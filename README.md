# ChinaTravel

Go 项目。开发体系基于 harness + OpenSpec + superpowers。

## 仓库拓扑

本仓库是 **workspace 仓库**，只承载仓库级文件（`Makefile`、`AGENTS.md`、`README.md`、
`.gitignore`、`openspec/`、`.claude/`）。前后端各自是独立仓库，以 git submodule 挂载：

| 挂载点 | 仓库 |
|--------|------|
| `backend/` | https://github.com/snzysnk/ChinaTravel-backend |
| `frontend/` | https://github.com/snzysnk/ChinaTravel-frontend |

两端代码的提交落在各自的仓库中；本仓库只记录 submodule 指针。

## 获取完整工作区

克隆时一并拉取 submodule：

```bash
git clone --recurse-submodules https://github.com/snzysnk/ChinaTravel.git
```

已经克隆过、但 `backend/` 与 `frontend/` 为空时，补拉一次：

```bash
git submodule update --init --recursive
```

## 开发

**首次使用需先安装前端依赖**（后续不必重复）：

```bash
cd frontend && npm install
```

```bash
make help                 # 列出全部可用命令
make run-backend          # 启动后端（在 backend/ 下执行），监听 18080
make serve-frontend       # 启动前端开发服务器，监听 5174，并把 /api 转发到后端
make test                 # 运行后端全部 Go 测试
make typecheck-frontend   # 检查前端 TypeScript 类型
```

端到端验收：终端 A 执行 `make run-backend`，终端 B 执行 `make serve-frontend`，
浏览器访问 <http://localhost:5174>。

## 技术栈

| 端 | 技术栈 | 位置 |
|----|--------|------|
| 后端 | Go 1.24 + Gin（依赖仅 `gin` 与 `yaml.v3`） | `backend/`（独立仓库，Go 模块根） |
| 前端 | Vue 3 + TypeScript + Vite | `frontend/`（独立仓库，前端根） |

前端源码中不出现后端地址或端口：请求以相对路径发起，开发期由 Vite 转发（转发目标在
`frontend/vite.config.ts`），生产环境由反向代理转发。后端端口取值的唯一权威来源是
`backend/configs/config.yaml` 的 `server.port`。

注意：后端 Go 命令必须在 `backend/` 目录下执行——配置默认路径 `configs/config.yaml`
相对进程工作目录解析，读不到时不报错、静默回落到内置默认值。`Makefile` 已保证这一点。
