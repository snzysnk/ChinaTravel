## Why

前后端代码目前与仓库级文件混在同一个 Git 仓库中，且该仓库尚无任何提交、也没有远端。
这带来两个问题：一是前后端无法独立演进与发布，任何一端改动都会牵动整仓历史；
二是仓库根既承载编排与规格文件、又承载两端源码，边界只能靠目录约定维持，没有版本控制层面的强制力。

本次变更将其重塑为 **workspace + git submodule** 结构：workspace 仓库只保留仓库级文件，
前后端各自成为独立仓库并通过 submodule 挂载。同时修正一个既有负债——
Go module path 指向 `github.com/xieruixiang/ChinaTravel`，而该 GitHub 账号并不存在，
使得模块路径无法被 Go 工具链解析。

## What Changes

- **BREAKING**（对开发者与工具链）：Go module path 由 `github.com/xieruixiang/ChinaTravel`
  改为 `github.com/snzysnk/ChinaTravel-backend`。`backend/go.mod` 的 `module` 指令与
  Go 源码中 14 处对自身模块的 import 全部需要改写。此变更**推翻**了已归档变更
  `backend-project-layout` 中"约束 5：Go 源码的导入路径不随目录移动而改变"这一决定——
  当时的结论建立在"module path 保持有效"的前提上，而该前提不成立。HTTP 接口契约、
  响应信封、配置项与运行时行为**完全不变**。
- 新增三个 GitHub 仓库（均为 public）：`snzysnk/ChinaTravel`（workspace）、
  `snzysnk/ChinaTravel-backend`、`snzysnk/ChinaTravel-frontend`。
- 拆分：`backend/` 与 `frontend/` 各自成为独立 Git 仓库并各自拥有初始提交。
- workspace 仓库以 git submodule 形式挂载上述两个仓库，挂载点仍为 `backend/` 与 `frontend/`。
- 仓库级文件（`Makefile`、`AGENTS.md`、`CLAUDE.md` 符号链接、`README.md`、`.gitignore`、
  `openspec/`、`.claude/`）留在 workspace 仓库根，不随任一端下移。
- 后端仓库的 `.gitignore` 锚点随之调整：构建产物规则由 `/backend/bin/` 改为 `/bin/`，
  以适应仓库根的变化。
- `openspec/config.yaml` 中的项目背景硬约束同步更新（module path 与新仓库拓扑）。

本次变更**不引入任何新的第三方依赖**（`gh` 是仅用于一次性仓库创建与推送的开发工具，
不进入 `go.mod`，也不成为构建或运行时的依赖）。

## Capabilities

### New Capabilities

- `workspace-repo-topology`: 定义 workspace 仓库的拓扑契约——哪些内容属于 workspace 仓库根、
  前后端如何以 submodule 形式挂载、submodule URL 与挂载点的对应关系，
  以及开发者在克隆 workspace 后如何获得可运行的完整工作区。

### Modified Capabilities

- `backend-project-layout`: 现有 requirement「后端与前端 SHALL 各占一个互为平级的顶层目录」
  需扩展——两个顶层目录不再由本仓库直接承载内容，而是作为 submodule 挂载点；
  requirement「后端 Go 命令 SHALL 在后端目录下执行」的语义不变，但其承载对象变为
  独立后端仓库的根目录。仓库级文件留在仓库根的 requirement 不变。

## Impact

- **Go 模块**：`backend/go.mod`（1 行 `module` 指令）+ 13 个 `.go` 文件中的 14 行 import。
  受影响文件：`cmd/server/main.go`（2）、`internal/bootstrap/app.go`（6）、
  `internal/bootstrap/app_test.go`（1）、`internal/health/handler.go`（1）、
  `internal/destination/handler.go`（1）、`internal/platform/middleware/recovery.go`（1）、
  `internal/platform/logger/logger.go`（1）、`internal/platform/logger/logger_test.go`（1）。
- **规格与流程文件**：`openspec/config.yaml` 的项目背景段落。
- **编排**：`Makefile` 的后端目标语义不变（仍以 `backend/` 为工作目录），
  但该目录自此是 submodule 挂载点；`make` 目标本身无需改动。
- **被丢弃的内容**：`backend/bin/server`（11MB 构建产物，本就不该入库）、
  `backend/.claude/.cc-writes`（会话态垃圾）。
- **不涉及**：HTTP 接口、响应信封契约、配置项名与加载顺序、日志出口、CORS 白名单、
  前端页面行为、Go 依赖集合。
- **受影响的既有规格**：`backend-project-layout`（见上）。
  其余五个能力规格（`api-response-envelope`、`cross-origin-access`、
  `frontend-api-integration`、`http-server-bootstrap`、`observability-baseline`）不受影响。
