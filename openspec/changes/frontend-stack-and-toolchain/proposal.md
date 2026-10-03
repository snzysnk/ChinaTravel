## Why

后端已由 `bootstrap-gin-fullstack-skeleton` 与 `backend-project-layout` 固化了 `platform`
四件套（配置、日志、信封、中间件）与目录约定，而前端至今只有一个 8987 字节的零构建
`index.html`——它自己在文件头注释里写明「页面逻辑增长时应评估迁移到带构建的前端工程」，
且 `bootstrap-gin-fullstack-skeleton` 的「不在本次范围内」已把前端构建工具链单列。

这个不对称会在单人开发中持续制造成本：新增页面时没有「代码该放哪」的既有答案，每加一个
功能都要临时决定一次目录、类型与请求封装的位置。同时，零构建意味着没有类型检查——在
「AI 生成、人工审阅」的协作模式下，AI 幻觉出的接口方法只能在运行时报错暴露，而类型系统
能在阅读代码之前就拦住它。

## What Changes

- 前端引入 **Vue 3 + TypeScript + Vite** 构建工具链，替代当前的零构建单文件形态。
- 确立前端目录约定（页面、组件、接口封装、类型声明各自的位置）。
- 接口响应的信封类型在前端以显式 TypeScript 类型声明，与后端 `response.Envelope` 契约对齐。
- **开发期跨域改为经 Vite proxy 同源转发**：前端不再持有后端端口，转而由转发配置声明目标。
  这从机制上消除「端口取值多处重复、任一处漂移都无信号」的问题（该类问题已实际发生过，
  见 `fix-frontend-api-base-port` 变更及前端仓库 commit `a03714d`）。
- 现有 `index.html` 的界面与交互**原样迁移**到新工程，不借迁移之机改视觉或加功能——
  迁移后页面行为应与迁移前一致，便于验证链路未断。
- **BREAKING**：现有 `frontend-api-integration` 规格中「前端调用的后端地址 SHALL 与后端
  监听端口一致」这条 Requirement 被 proxy 方案取代（前端不再声明端口），且该规格中
  「前端资源 SHALL 无需构建步骤」这条 Requirement 与本变更直接冲突，将被替换。

## Capabilities

### New Capabilities

- `frontend-toolchain`：前端的构建工具链、语言、目录约定、类型声明与开发期跨域转发方式。

### Modified Capabilities

- `frontend-api-integration`：跨域方式由「前端声明后端地址 + 后端 CORS 白名单」改为
  「开发期经代理同源转发」；「无需构建步骤」的要求被构建工具链取代；信封解析的要求保留并
  补充类型声明约定。

## Impact

**新增依赖**（依 `openspec/config.yaml` 的 YAGNI 条款逐项说明理由）：

- `vue`：本次变更的核心目标即「引入 Vue 3」。选型理由见 `design.md` 决策 1，属需求本身。
- `vite` + `@vitejs/plugin-vue`：Vue 官方推荐的构建工具，提供开发服务器、热更新与生产构建。
  它是本次「引入构建工具链」这一目标的直接实现手段，非遗留可选项。
- `typescript` + `vue-tsc`：类型检查是本次变更的**实质目标之一**（拦 AI 幻觉接口），
  而非附带的开发体验优化，因此属于需求本身。
- **不引入** 路由库（vue-router）、状态管理（Pinia）、UI 组件库、CSS 框架、测试框架——
  当前只有一个页面、两个接口，上述依赖收益为零，符合 YAGNI 条款。

**受影响的代码与目录**：

- `frontend/`（**独立仓库** `github.com/snzysnk/ChinaTravel-frontend`）：新增工程化目录结构、
  构建配置、类型声明；现有 `index.html` 的内容迁移进新工程。
- `backend/`（**独立仓库**，**执行期新增的范围**）：`configs/config.yaml` 的 CORS 白名单与
  `internal/platform/config/config.go` 的内置默认值同步为前端新端口 `5174`，相关测试夹具一并更新。
  **范围说明**：此项在规划阶段不在本变更范围内。执行期间确认前端开发服务器端口取 5174
  （而非旧静态服务的 5173），为使「转发来源」与「后端白名单」保持一致而必须同步，
  否则白名单指向一个已退役的来源。前端仅与后端之间无其他耦合，改动限于端口取值。
- `Makefile`（workspace 仓库）：`serve-frontend` 目标从 `npx serve` 改为调用前端仓库的
  开发服务器命令；新增 `typecheck-frontend` 目标；`FRONTEND_PORT` 由 5173 改为 5174，
  其语义从「静态服务端口」变为「前端开发服务器端口」。
- `AGENTS.md`（workspace 仓库）：当前把 `frontend/` 描述为「零构建的静态前端」，
  该表述在本变更后过期；新增前端目录约定与「不得声明后端端口」等约束，
  并把「后端保持 Gin」的选型结论记入技术栈描述。
- `README.md`（workspace 仓库）：补充前端首次安装依赖的步骤、命令变化与技术栈表。
- `openspec/config.yaml`（workspace 仓库）：项目背景补充前端技术栈与目录约定，
  硬约束补充两条（前端不声明后端端口、接口类型手工同步）。

**受影响的接口**：无。后端接口契约不变，本变更只改变前端消费接口的方式。

**不在本次范围内的系统**：

- 容器化与部署编排（含 Docker healthcheck 探针）。理由：响应信封「HTTP 状态码恒为 200」
  使基于状态码的健康检查失效，探针方案需在后端仓库落地，属跨仓库的独立变更。
- 前端路由、状态管理与 UI 组件库。待页面与状态确实增多时按需引入。
- 后端技术栈调整。选型结论为保持 Gin，理由见 `design.md` 决策 8。
