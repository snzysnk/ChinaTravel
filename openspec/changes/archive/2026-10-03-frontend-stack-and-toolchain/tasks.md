# 任务清单

**跨仓库提交边界**（依 `openspec/config.yaml` 的仓库拓扑硬约束）：第 1~4 组的改动落在
`frontend` 仓库；第 5~7 组的改动落在 workspace 仓库；submodule 指针更新在 workspace 仓库，
且必须在前端仓库提交完成之后执行。

## 1. 前端工程骨架

- [x] 1.1 在 `frontend/` 下建立 Vite + Vue 3 + TypeScript 工程骨架，产出 `frontend/package.json`、`frontend/vite.config.ts`、`frontend/tsconfig.json`、`frontend/index.html`、`frontend/src/main.ts`、`frontend/src/App.vue`。**验证**：`cd frontend && npm install && npm run build` 成功，产出 `frontend/dist/`，且 `dist/` 中只有静态资源、无对 `node_modules` 的引用。
- [x] 1.2 配置 `frontend/vite.config.ts` 的 `/api` 代理转发，目标端口与 `backend/configs/config.yaml` 的 `server.port`（18080）一致；为转发目标写注释说明其权威来源是后端配置文件。**验证**：启动后端后执行 `cd frontend && npm run dev`，`curl -s http://localhost:5173/api/health` 返回信封 JSON（`code` 为 0），且响应来自后端而非前端开发服务器。
- [x] 1.3 在 `frontend/package.json` 中声明 `engines.node` 最低版本，并把 `typecheck`（调用 `vue-tsc --noEmit`）作为独立脚本；确认 `frontend/.gitignore` 已忽略 `node_modules/` 与 `dist/`。**验证**：`cd frontend && npm run typecheck` 在无类型错误时退出码为 0；`git -C frontend status --porcelain` 不列出 `node_modules/` 或 `dist/`。

## 2. 接口层与类型声明

- [x] 2.1 建立 `frontend/src/api/types.ts`，以显式类型声明后端响应信封（业务码、提示文案、数据载荷三部分）与两个接口（健康检查、目的地列表）的数据结构；在文件头注释中注明其权威来源是后端 `api-response-envelope` 规格与 `backend/internal/platform/response/envelope.go`。**验证**：`npm run typecheck` 通过；人工核对类型字段与 `backend/internal/platform/response/envelope.go` 的 JSON 标签逐项一致。
- [x] 2.2 建立 `frontend/src/api/request.ts`，把 `frontend/index.html` 中现有 `request()` 的信封解析逻辑原样迁移过来（先校验 HTTP 与 JSON、再判断 `code`、为零取 `data`、非零以 `msg` 构造错误），使全体接口调用复用同一处解析。**验证**：`npm run typecheck` 通过；在浏览器中触发一次成功请求与一次失败请求（访问不存在的目的地 ID），分别得到数据与带 `msg` 的错误。
- [x] 2.3 建立 `frontend/src/api/index.ts`，暴露健康检查与目的地列表两个方法，内部经 `request.ts` 以**相对路径**（如 `/api/destinations`）发起请求，不得出现后端主机名或端口。**验证**：`grep -rn "18080\|localhost:18080" frontend/src/` 无匹配；`npm run typecheck` 通过。

## 3. 页面迁移

- [x] 3.1 把 `frontend/index.html` 的界面、样式与交互流程原样迁移为 `frontend/src/views/` 下的页面组件（含健康状态展示、目的地列表渲染、空集合空状态、请求失败的提示），逻辑改从 `src/api/` 调用。**验证**：`npm run dev` 后页面与迁移前的 `index.html` 逐项对照一致（健康状态标识、列表条数、空状态文案、失败提示文案）。
- [x] 3.2 保留 `frontend/index.html` 顶部注释中仍然成立的说明（尤其「以文件协议打开不受支持」这一已知限制），迁移到新工程的对应位置，而不是随旧文件一起删除。**验证**：`grep -rn "文件协议" frontend/src/` 有匹配；`frontend/index.html` 中该说明已不存在（旧文件待 3.3 删除）。
- [x] 3.3 删除旧的零构建 `frontend/index.html`（已由 1.1 的 Vite 入口 `index.html` 取代），确认前端仓库中不再存在第二份页面实现。**验证**：`git -C frontend ls-files | grep -c "index.html"` 结果为 1（仅 Vite 入口）。

## 4. 前端仓库提交

- [x] 4.1 在 `frontend` 仓库提交本变更的前端改动（工程骨架、接口层、页面迁移、旧文件删除）。**验证**：`git -C frontend status --porcelain` 为空；提交信息说明引入 Vue 3 + TypeScript + Vite 并说明 proxy 转发取代了 `API_BASE` 常量。

## 5. 编排更新（workspace 仓库）

- [x] 5.1 更新 `Makefile` 的 `serve-frontend` 目标，改为经 `$(FRONTEND_DIR)` 调用前端仓库自身的开发服务器命令；标注该命令由前端仓库的 `package.json` 定义，workspace 层只做进入与提示；确认 `FRONTEND_PORT`（5173）与前端开发服务器默认端口一致。**验证**：`make serve-frontend` 能启动前端开发服务器，页面可访问；`make help` 输出的前端说明与实际行为一致。
- [x] 5.2 在 `Makefile` 中新增前端类型检查目标（调用前端仓库的 `typecheck` 脚本），并确认后端目标不受影响。**验证**：该目标在前端存在类型错误时以非零退出；`cd backend && go build ./...` 仍成功。

## 6. 文档与规格上下文更新（workspace 仓库）

- [x] 6.1 更新 `AGENTS.md`：把 `frontend/` 的描述从「零构建的静态前端」改为工程化的 Vue 3 + TypeScript + Vite 前端；补充前端目录约定、前端命令的进入方式、以及「前端不得声明后端端口」这条约束；同时把「后端保持 Gin」的结论记入技术栈描述（见 `design.md` 决策 8）。**验证**：通读 `AGENTS.md`，不存在「零构建」等在本次变更后过期的表述；检索 `AGENTS.md` 中端口相关的表述与新的转发机制一致。
- [x] 6.2 更新 `openspec/config.yaml` 的 `context` 段：补充前端技术栈与前端目录约定，并在硬约束中补一条「前端请求以相对路径发起、经转发到后端，前端源码不出现后端端口」。**验证**：`openspec validate --all` 通过；运行 `openspec instructions proposal --change frontend-stack-and-toolchain --json` 后检查返回的 `context` 已包含前端技术栈。
- [x] 6.3 更新 `README.md` 的开发章节：说明前端首次需安装依赖、`make serve-frontend` 的行为变化、以及类型检查命令。**验证**：按 `README.md` 的步骤在干净检出上走一遍，前端能启动并访问。

## 7. 端到端验收与收尾

- [x] 7.1 端到端验收：终端 A `make run-backend`、终端 B `make serve-frontend`，访问 `http://localhost:5174`，确认健康状态与目的地列表均正常展示；确认前端发出的请求是同源相对路径，不触发跨域预检。**验证**：页面可访问（HTTP 200）；经同源转发的 `/api/health` 与 `/api/destinations` 均返回 `code=0`，列表条目数与后端内存仓储一致；源码检索确认请求路径均为 `/api/...` 相对路径。**执行方式修正**：本会话内无法开浏览器（沙箱禁用 macOS Launch Services），改为在协议层用 curl 做等价验证；浏览器内的目视渲染仍建议由开发者按原文自行执行一次。
- [x] 7.2 交叉验证 CORS 配置：确认后端白名单已切换到新的前端来源，且旧来源不再被放行。**验证**：`curl -H "Origin: http://localhost:5174"` 直连后端返回 `Access-Control-Allow-Origin: http://localhost:5174`；`curl -H "Origin: http://localhost:5173"` 不返回该头；`cd backend && go test ./internal/platform/middleware/ -run CORS` 六个用例全部通过。**执行方式修正**：原计划"临时绕过转发改前端代码"实无必要——直接以 curl 带 `Origin` 头请求后端即可覆盖同一断言，且不改动任何代码。
- [x] 7.3 后端回归确认：后端测试与格式检查全部通过。**验证**：`make test` 全部 ok；`make fmt` 无未格式化文件。**注**：本变更实际改动了后端（CORS 白名单与内置默认值同步至 5174），故此项是真实回归而非走形式，结果证明改动未破坏任何既有行为。
- [x] 7.4 在 workspace 仓库更新 submodule 指针（第 4 组提交完成之后执行），并提交 workspace 侧的 `Makefile`、`AGENTS.md`、`README.md`、`openspec/config.yaml` 改动与本变更的规划产物。**验证**：`git status` 干净；`git submodule status` 显示的 `frontend` 指针指向 4.1 的提交。
