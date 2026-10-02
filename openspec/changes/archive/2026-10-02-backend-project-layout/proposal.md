## Why

当前仓库的顶层布局不对称：前端独占 `frontend/` 一个目录，后端却直接摊在仓库根（`cmd/`、`internal/`、`configs/`、`go.mod` 与 `frontend/`、`Makefile`、`openspec/` 混在同一层）。这个不对称本身是 `bootstrap-gin-fullstack-skeleton` 的有意选择——该变更的 design.md 中"目录结构：领域垂直分包"一节只回答了 **`internal/` 内部怎么切**（按领域而非按 handler/service/repository 分层），从未回答"后端整体要不要有个顶层目录"。结果是：读代码的人无法从目录树一眼看出后端在哪，"后端"这个概念在仓库里没有物理落点。

本次变更为仓库补上缺失的那半个决策：确立"后端在 `backend/`、前端在 `frontend/`"的顶层对称布局，并把随之产生的**工作目录约定**一并写成契约——因为后端的配置路径是相对进程工作目录解析的，目录一挪，这条原本只存在于 Makefile 里的隐性习惯就会变成必须成文的规则。

## What Changes

- 建立**顶层对称布局**：后端整体下移到 `backend/`（`cmd/`、`internal/`、`configs/`、`go.mod`、`go.sum` 一并移动），与 `frontend/` 平级。
- 确立**仓库级文件留在根**：`Makefile`、`AGENTS.md`、`README.md`、`openspec/`、`.gitignore` 管的是整个仓库而非后端，SHALL 留在仓库根，SHALL NOT 移入 `backend/`。
- 确立**后端命令的工作目录约定**：所有后端 Go 命令（`go run` / `go build` / `go test` / `gofmt`）SHALL 在 `backend/` 目录下执行。原因是 `internal/platform/config` 的 `defaultPath` 是相对进程工作目录的 `configs/config.yaml`，从仓库根启动会**静默**读不到配置文件并回落到内置默认值（`applyFile` 对文件不存在返回 nil，不报错）。
- **Makefile** 引入 `BACKEND_DIR` / `FRONTEND_DIR` 两个变量，所有 target 经变量切换目录，使"后端根在哪"在编排层显式可见；`serve-frontend` 行为不变。
- **`.gitignore`** 的构建产物规则由 `/bin/` 等价替换为 `/backend/bin/`。
- **`openspec/config.yaml`** 硬约束中的路径表述同步更新（`cmd/server` → `backend/cmd/server`、`internal/platform` → `backend/internal/platform`、`configs/config.yaml` → `backend/configs/config.yaml`），否则后续变更的 spec 会照着过期路径书写，错误将静默扩散。

**BREAKING**：对**外部消费者**无破坏性——module path `github.com/xieruixiang/ChinaTravel` 不变，Go 源码中 14 处 import 路径无需改动，HTTP 接口与响应契约完全不变。**对开发者与工具链构成破坏性变更**：仓库根不再是 Go 模块根，IDE 需在 `backend/` 目录打开（或在仓库根配置 module）；从仓库根直接执行 `go test ./...` / `go build ./...` 不再覆盖后端代码。

**已明确排除的选项**：不在本次一并修复"配置路径相对 CWD"这一根因。经确认采用最小改动方案（仅挪目录 + 成文约定），根因修复（让配置路径不依赖工作目录）留作后续独立变更。**本变更因此以文档与规格的方式显式承担该风险**，而非消除它。

## Capabilities

### New Capabilities

- `backend-project-layout`：仓库顶层布局契约。规定后端与前端各自占一个顶层目录且互为平级、仓库级文件（编排、文档、规格、忽略规则）留在仓库根，以及"后端 Go 命令 SHALL 在 `backend/` 下执行"这一工作目录约定及其理由。该能力为后续新增顶层目录（如 `docs/`、`scripts/`、`deploy/`）提供落位依据。

### Modified Capabilities

无。`http-server-bootstrap` 中"服务 SHALL 按领域垂直分包组织代码"这条讲的是 `internal/` **内部**如何按领域切分，与"后端整体是否拥有顶层目录"是正交的两个问题，该 Requirement 的语义不因本次变更而改变；"服务 SHALL 从外部配置加载运行参数"规定的是配置的来源层级与优先级，本次改动的是配置文件**所在位置**而非加载规则，其全部 Scenario（含"配置来源缺失时仍可启动"）依然成立。故本次不变更任何既有 spec 的 Requirement。

## Impact

**受影响的目录与文件**：

- 移动（纯路径变更，内容零改动）：`cmd/`、`internal/`、`configs/`、`go.mod`、`go.sum` → `backend/` 下；`bin/` 为构建产物（`.gitignore` 已忽略），移动后可重建亦可直接删除。
- 修改：`Makefile`（引入目录变量并让后端 target 切换工作目录）、`.gitignore`（`/bin/` → `/backend/bin/`）、`AGENTS.md`（目录分层表与工作目录约定）、`openspec/config.yaml`（硬约束中的路径表述）。
- 新增：`openspec/specs/backend-project-layout/spec.md`（本次变更归档后落入主 spec）。

**不受影响**：Go 源码的 import 路径（module path 未变，14 处引用全部保持原样）、`configs/config.yaml` 内容、`frontend/index.html` 内容、`README.md` 内容、全部 HTTP 接口与响应信封契约、Go 依赖清单。

**受影响的接口**：无。本次变更不新增、不修改、不移除任何 HTTP 接口。

**已知风险（本次有意不消除）**：

- 从仓库根执行 `go run ./backend/cmd/server/` 时，配置将静默回落到内置默认值。当前内置默认值（端口 8080、来源白名单 `http://localhost:5173`、日志级别 info）与 `backend/configs/config.yaml` 中的取值恰好一致，故该情况**不会立即显现**，只在修改配置文件后才会暴露。本次以成文约定（`AGENTS.md` + `backend-project-layout` 规格）与 Makefile 编排降低其发生概率，根因修复留待后续变更。
- 仓库根不再是 Go 模块根，IDE 的 module 探测需要一次性的本地配置调整。

**不在本次范围内**：根因修复（配置路径脱离工作目录）、前端引入构建工具链、`docs/` / `scripts/` / `deploy/` 等新顶层目录的建立、容器化与部署编排。
