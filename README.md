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

```bash
make help              # 列出全部可用命令
make run-backend       # 启动后端（在 backend/ 下执行）
make serve-frontend    # 启动前端静态服务
make test              # 运行后端全部 Go 测试
```

注意：后端 Go 命令必须在 `backend/` 目录下执行——配置默认路径 `configs/config.yaml`
相对进程工作目录解析，读不到时不报错、静默回落到内置默认值。`Makefile` 已保证这一点。
