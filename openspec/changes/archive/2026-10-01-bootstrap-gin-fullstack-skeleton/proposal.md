## Why

ChinaTravel 目前是一个只有流程约定的空仓库：没有 `go.mod`，没有任何 Go 代码，目录分层、Web 框架与依赖约定全部未定。这导致后续所有业务开发都没有可落脚的骨架——每加一个功能都要先临时决定一次"代码放哪、接口长什么样、配置从哪读"。

本次变更为项目搭建**第一个可运行的前后端骨架**，并借此把长期约束（目录分层、API 契约、配置加载、日志出口）一次性固化下来，使后续业务功能可以"照着往上码"而不必反复重议地基。

范围刻意收敛为**最小闭环**：只打通 `前端页面 -> Gin API -> 领域层` 一条链路，**不引入数据库、ORM、认证与任何业务建模**。目标是用最低成本提前撞上分离式前后端的集成问题（跨域、契约格式），同时不把持久化选型过早锁死。

## What Changes

- 建立 Go 模块 `github.com/xieruixiang/ChinaTravel`，接入 Gin 作为 HTTP 框架。
- 确立**领域垂直分包**的目录结构：`cmd/server`（进程入口）+ `internal/<领域>`（按业务分包）+ `internal/platform`（跨领域公共机制）+ `configs/` + `frontend/`。
- 引入**统一响应信封**：HTTP 状态码恒为 200，真实结果由响应体 `code` 表达，`code` 采用分段编码（前 3 位表 HTTP 语义，后 2 位表业务序号）。
- 提供**配置加载**：`configs/config.yaml` 作为默认值来源，`APP_*` 环境变量可覆盖（含数组型配置的逗号分隔约定）。
- 提供**统一日志出口**：以标准库 `log/slog` 为唯一日志入口，替换 Gin 默认的请求日志输出。
- 提供三个自研中间件：访问日志、CORS 白名单校验、panic 恢复（**必须输出信封格式**，否则前端解析崩溃）。
- 提供**两个示例接口**打通链路：`GET /api/health`（纯连通性）与 `GET /api/destinations`（内存数据，验证 `handler -> service -> repository` 全链路与 JSON 序列化）。
- 提供**静态前端页面**：原生 HTML/JS，通过 `fetch` 调用上述接口并渲染结果，由独立静态服务托管（非同源部署）。
- 提供 **Makefile** 编排后端启动、前端静态服务、测试、构建四类命令。
- 建立**可自动化验证的测试基线**：仅针对 handler 层编写 HTTP 契约测试，守住信封格式。

**BREAKING**：无。本变更在空仓库上新增内容，不涉及既有代码或既有 spec 的修改。

## Capabilities

### New Capabilities

- `api-response-envelope`：统一响应信封的格式、`code` 分段编码规则，以及成功与各类错误的响应约定。这是前端解析的唯一契约。
- `http-server-bootstrap`：HTTP 服务的启动生命周期（配置加载、对象图装配、路由注册、中间件链、优雅关闭）与领域垂直分包的目录结构约定。
- `cross-origin-access`：分离式部署下，浏览器跨域请求按白名单被 CORS 中间件放行或拒绝的约定，含预检请求处理。
- `observability-baseline`：应用日志统一出口（`slog`）与 HTTP 访问日志的字段约定，确保 Gin 不再产生格式不一致的独立日志流。
- `frontend-api-integration`：静态前端页面从真实 origin 调用后端接口并渲染响应的约定，作为前后端链路的验收载体。

### Modified Capabilities

无。项目当前不存在任何已归档的 spec（`openspec/specs/` 为空），本次为首次引入能力。

## Impact

**新增依赖**（依 `openspec/config.yaml` 的 YAGNI 条款逐项说明理由）：

- `github.com/gin-gonic/gin`：本次变更的核心目标即"基于 Gin 搭建框架"，属于需求本身，非遗留可选项。
- `gopkg.in/yaml.v3`：用于解析 `configs/config.yaml`。理由：纯 YAML 方案需要它；相较 viper 等配置库，它无传递依赖、体积小，属于"最小代价的配置加载"。
- **不引入** 日志库（zap/zerolog）、ORM、测试断言库（testify）、依赖注入工具（wire/fx）——当前阶段收益为零，符合 YAGNI。

**受影响的代码与目录**：

- 新建：`go.mod`、`Makefile`、`configs/config.yaml`、`cmd/server/`、`internal/bootstrap/`、`internal/platform/`、`internal/health/`、`internal/destination/`、`frontend/`。
- 修改：`openspec/config.yaml` 的项目背景表述（当前仍写着"未确定 Web 框架"，本变更后该表述过期）。
- 修改：`AGENTS.md` 的「项目规范」章节（当前标注"架构未定"，本变更后需指向新的常驻规范）。

**受影响的接口**：新增 `GET /api/health`、`GET /api/destinations` 两个 HTTP 接口，均遵循统一信封。

**不在本次范围内的系统**：数据库/持久化、认证与鉴权、业务领域建模、前端构建工具链、容器化与部署编排。这些留给后续变更。
