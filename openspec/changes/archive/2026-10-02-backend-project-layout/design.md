## Context

动机与范围见 `proposal.md`。此处只记录塑造本方案的技术约束（均已核对源码确认）：

**约束 1：Go 模块根与 `internal` 封装按目录位置生效。** `internal/` 的导入保护只对位于 `go.mod` 同级或下级的包生效。因此后端下移时 `go.mod` 必须与 `internal/` 一同移动，二者不能分离。

**约束 2：配置默认路径相对进程工作目录。** `backend/internal/platform/config/config.go` 中 `defaultPath = "configs/config.yaml"` 是相对路径；`cmd/server/main.go` 调用 `config.Load("")` 传入空串，即采用该默认值。项目中没有基于可执行文件位置或 `go.mod` 位置的路径解析。

**约束 3：配置文件缺失是静默失败。** 同文件的 `applyFile` 对 `fs.ErrNotExist` 返回 `nil`（"未提供该层配置"），因此读不到配置文件既不报错也不告警，直接回落到内置默认值。该行为已由 `http-server-bootstrap` 规格中的 Scenario「配置来源缺失时仍可启动」固化为契约，本次不改变它。

**约束 4：默认值与配置文件取值当前恰好一致。** 内置默认（端口 8080、白名单 `http://localhost:5173`、日志级别 info）与 `backend/configs/config.yaml` 中的取值相同，故约束 3 的触发不会立即显现，只在修改配置文件后暴露。

**约束 5：Go 源码的导入路径不随目录移动而改变。** module path 由 `go.mod` 的 `module` 指令决定（`github.com/xieruixiang/ChinaTravel`），与仓库目录名无关。已核实源码中共 14 处对自身 module 的导入，分布在 `cmd/server/main.go`（2）、`internal/bootstrap/app.go`（6）、`internal/bootstrap/app_test.go`（1）、`internal/health/handler.go`（1）、`internal/destination/handler.go`（1）、`internal/platform/middleware/recovery.go`（1）、`internal/platform/logger/logger.go` 与 `logger_test.go`（各 1）。这些导入**不需要修改**——这是本方案相对"重命名 module"方案的主要优势。

## Goals / Non-Goals

**Goals:**

- 确立后端与前端互为平级的顶层目录布局，使后端的物理落点可被目录树直接读出。
- 把"后端命令在后端目录下执行"从 Makefile 的隐含习惯提升为规格级的成文约定，使其对不用 Makefile 的入口（CI、IDE run configuration、容器启动命令）同样生效。
- 使本次变更对 Go 源码的侵入降到最低：导入路径零改动，业务代码零改动。
- 把由于选择最小改动方案而残留的风险显式记录，而非让它继续隐性存在。

**Non-Goals:**

- 不修复"配置路径相对工作目录"这一根因（见 Decisions 决策 3 与 Risks）。
- 不改动任何 HTTP 接口、响应信封契约、领域代码或配置取值。
- 不引入前端构建工具链，不为 `frontend/` 增加任何依赖管理或产物目录。
- 不建立 `docs/`、`scripts/`、`deploy/` 等新顶层目录；本能力只为其将来落位提供依据。
- 不改变 `http-server-bootstrap` 中关于领域垂直分包的约定，`internal/` 内部的切分方式保持原样。

## Decisions

### 决策 1：后端整体下移，且 `go.mod` 随之下移

后端顶层目录取名为 `backend/`，其下包含 `cmd/`、`internal/`、`configs/`、`go.mod`、`go.sum`。

**理由**：由约束 1，`go.mod` 与 `internal/` 必须同处一地，否则 `internal` 的导入保护失效（若 `go.mod` 留在根而 `internal/` 下移，`internal/` 会落到模块根之下但仍受保护——然而那样 `backend/` 就只是"代码目录"而非"后端根"，`configs/` 与 `go.mod` 的归属会再次变得含混，对称化只做了一半）。

**代价**：仓库根不再是 Go 模块根。`go test ./...` / `go build ./...` 从仓库根执行不再覆盖后端；IDE 需在 `backend/` 打开或在仓库根手动配置 module。

**已考虑的替代**：

- **在根保留 `go.mod`，仅移动源码目录**：被否。会让 `backend/` 定义模糊（是"后端根"还是"源码目录"？），且 `configs/` 归属不清，问题被推迟而非解决。
- **使用 Go workspace（`go.work`）在根桥接**：被否。为两个目录的项目引入 workspace 属于过度设计，且 `go.work` 不改变 `internal` 的封装边界与工作目录约束，无法解决约束 2 的问题，只增加一层概念。

### 决策 2：仓库级文件留在根

`Makefile`、`AGENTS.md`、`README.md`、`.gitignore`、`openspec/` 留在仓库根。

**理由**：这些文件的作用域是整个仓库：`Makefile` 同时编排前后端，`openspec/` 承载仓库级的规格与变更流程，`.gitignore` 的规则同时覆盖两侧。把它们移入 `backend/` 会使"后端目录"变成"仓库配置目录"，与决策 1 的定义冲突。

**已考虑的替代**：把 `openspec/` 与 `Makefile` 也移入 `backend/`，使根目录只剩两个平级目录。被否，因为前端相关任务与规格流程会被迫放到后端目录下，语义错误。

### 决策 3：以成文约定承担风险，本次不修复配置路径根因

由约束 2、3、4，后端下移后，"从后端目录启动"成为配置文件能被加载的前提。本次选择**在规格与项目约定中显式写明该前提**，而不改动 `config` 包的路径解析逻辑。

**理由**：根因修复会触及 `config` 包的公开行为。候选修法各有代价——改为相对可执行文件位置查找会改变测试与开发两种运行方式的行为差异；改为相对 `go.mod` 位置查找需要新增向上遍历逻辑；改为"未显式指定路径时缺失即报错"会直接违反 `http-server-bootstrap` 已固化的 Scenario「配置来源缺失时仍可启动」。三者都超出"确立目录布局"这一变更的边界，混入本变更会使变更范围失控，也会掩盖目录布局这一主要目的。

**已考虑的替代**：本次一并修复（即探索阶段讨论的 B2 方案）。经权衡后放弃，改为后续独立变更处理——届时可以专门讨论"配置路径的解析基准应该是工作目录、可执行文件位置还是模块根"这一独立问题。

**代价**：残留一个"静默回落到默认值"的风险，见 Risks 首条。

### 决策 4：Makefile 引入目录变量统一编排基准

引入 `BACKEND_DIR` 与 `FRONTEND_DIR` 两个变量，所有 target 经变量切换目录，不再出现硬编码的 `cd frontend`。

**理由**：在决策 3 之下，Makefile 是"正确姿势"的主要载体，它必须让后端根的位置显式可见。变量化的 `cd $(BACKEND_DIR)` 同时表达了两件事：后端根在哪，以及后端命令在哪个目录下执行——后者正是规格中新增 Requirement 的可执行体现。

**已考虑的替代**：仅在后端 target 中写死 `cd backend`。被否，与前端 target 的写法失去一致性，且路径变更时需多处修改。

### 决策 5：`.gitignore` 做等价替换，不顺带增加前端规则

`/bin/` 改为 `/backend/bin/`，不新增 `node_modules/`、`dist/` 等前端规则。

**理由**：本次变更的语义是"路径随目录移动而更新"，不是"完善忽略规则"。前端当前零构建、无依赖安装，加规则属于为不存在的产物做准备（YAGNI）。混入无关改动会让 review 难以判断哪些是布局变更的必需项。

### 决策 6：同步更新 `openspec/config.yaml` 的路径硬约束

`openspec/config.yaml` 中 `context` 字段的路径表述（`cmd/server`、`internal/platform`、`internal/<领域>`、`configs/config.yaml`）需加上 `backend/` 前缀。

**理由**：该字段是后续每次变更写 spec 时喂给 AI 助手的硬约束。若不更新，下一个变更的 spec 会照着过期路径书写，且这种错误不会在任何校验中暴露——它只会在实现阶段被发现，属于会静默扩散的错误。

**这是本变更中唯一"改文件但不改行为"的一类改动**，之所以纳入，是因为它正是本次不对称问题长期存在的成因之一。

## Risks / Trade-offs

- **[从仓库根执行后端命令会静默使用内置默认值，且不报错]** → 以规格 Requirement（「后端 Go 命令 SHALL 在后端目录下执行」）与 `AGENTS.md` 的项目约定双重成文；Makefile 全部目标经变量切换目录，使正确路径成为唯一显眼入口；在规格中以 Scenario 明确标注该用法"不被支持"而非"受支持"。**根因未消除**，缓解手段依赖协作者阅读约定。
- **[默认值与配置文件取值一致，掩盖了上述风险]** → 无法通过观察运行结果发现，只能靠约定。故在 `AGENTS.md` 中说明该风险的存在与触发条件（修改配置文件后才会暴露），使排查方向可知。
- **[仓库根不再是 Go 模块根，IDE module 探测失效]** → 一次性本地调整（在 `backend/` 打开或在根配置 module）。属可接受的开发体验成本，在 `AGENTS.md` 中说明。无需 CI 适配——当前仓库尚无 CI 配置。
- **[目录移动在 git 历史中的可见性]** → 原计划用 `git mv` 使 git 记录为重命名，并在移动与内容修改之间分两个提交。**执行时发现本仓库 `main` 分支尚无任何提交、全部文件为未跟踪状态**：此前提下 `git mv` 不可用（无 HEAD 可记录重命名），未跟踪文件的移动也不会产生 `R` 标记，分两个提交的策略一并失效。故改为普通 `mv`，并在首次提交时让 git 以重命名方式识别（同一提交内同时包含移动与内容修改，git 的相似度检测仍可识别为 rename）。此项不再构成本变更的风险缓解措施，仅作为执行记录。
- **[`bin/` 中的构建产物移动后残留]** → `bin/` 已被 `.gitignore` 忽略，不进入版本库；移动后重新构建即可，无需迁移。
- **[本变更与既有的"领域垂直分包"约定产生表述重叠]** → 在规格中划清边界：`backend-project-layout` 只规定**顶层**布局与工作目录前提，`http-server-bootstrap` 继续规定 `internal/` **内部**的领域切分。两者正交，互不引用对方的具体路径。

## Migration Plan

1. 移动 `cmd/`、`internal/`、`configs/`、`go.mod`、`go.sum` 至 `backend/`（普通 `mv`——本仓库尚无提交，`git mv` 不可用，详见 Risks 末条）；`bin/` 为被忽略的产物，可直接删除。
2. 在同一轮改动内更新 `Makefile`、`.gitignore`、`AGENTS.md`、`openspec/config.yaml`，使移动后的仓库立即可用（避免出现"移动了但 Makefile 还指向旧路径"的中间态）。
3. 验证：在 `backend/` 下执行 `go build ./...` 与 `go test ./...` 全绿；`make help` / `make build` / `make test` 正常；启动后端后确认配置被加载（而非回落默认值）——通过临时设置一个与默认值不同的环境变量并观察生效，或改动配置文件后观察端口变化。
4. 本地 IDE 配置调整（在 `backend/` 打开项目），不涉及版本库。

**回滚策略**：本变更不含运行时状态与数据迁移，回滚即把各目录移回原位并还原四个被修改文件，无遗留副作用。

## Open Questions

无。方案边界（是否修复配置路径根因、Makefile 是否变量化、仓库级文件归属、spec 落点）均已在本阶段确认。
