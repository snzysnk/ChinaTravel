# 通用规则

- 所有计划类文件放在 `docs/plan/` 中
- `PROJECT_ROOT` 代指本项目的根目录
- 每个方法必须有注释；对不易理解的业务逻辑补充解释性注释
- 遵循 KISS/DRY：没有性能问题的前提下可读性优先

# 项目规范

架构已由 `bootstrap-gin-fullstack-skeleton` 变更确立，前端技术栈由
`frontend-stack-and-toolchain` 变更确立。以下为常驻约定。
详细契约以 `openspec/specs/` 下的能力规格为准（随变更归档增量生长），
此处只记"代码放哪、接口长什么样"这类每次都需要的定位信息。

**技术栈**：后端 Go 1.24 + Gin（依赖仅 `gin` 与 `yaml.v3`）；前端 Vue 3 + TypeScript + Vite。
后端**保持 Gin** 是经比较后的结论（对比 GoFrame、Beego，维度见 `frontend-stack-and-toolchain`
变更的 `design.md` 决策 8）：既有约定资产（响应信封、三个自研中间件、垂直分包）已在 Gin 之上建成，
且 Gin 的语料密度显著更高，利于「AI 生成、人工审阅」的协作模式。除非出现大量 CRUD 与
复杂 ORM 的规模化需求，否则不重新评估。

## 目录分层（领域垂直分包）

| 路径 | 职责 |
|------|------|
| `backend/cmd/server/` | 进程入口。只负责加载配置、调用装配、启动监听、处理终止信号 |
| `backend/internal/bootstrap/` | 对象图装配。中间件挂载、路由注册、404 处理器；**新增领域时唯一需要改动的既有文件** |
| `backend/internal/platform/` | 跨领域公共机制：`config`（配置）、`logger`（日志出口）、`response`（响应信封）、`middleware`（访问日志 / CORS / 恢复） |
| `backend/internal/<领域>/` | 业务领域，自包含 handler + service + repository + model，如 `health`、`destination` |
| `backend/configs/` | 配置文件。只放与环境无关的默认值，密钥走环境变量 |
| `backend/go.mod` | Go 模块定义。**仓库根不是 Go 模块根**，IDE 需在 `backend/` 打开或在根手动配置模块 |
| `frontend/` | 前端独立仓库。Vue 3 + TypeScript + Vite 工程，源码在 `frontend/src/` |

## 前端（Vue 3 + TypeScript + Vite）

技术栈已由 `frontend-stack-and-toolchain` 变更确立。**前端根就是前端仓库根**，
依赖装在 `frontend/node_modules/`（不入库），构建产物在 `frontend/dist/`（不入库）。

| 路径 | 职责 |
|------|------|
| `frontend/src/api/` | 接口层。`types.ts` 声明信封与各接口的数据结构，`request.ts` 是唯一的信封解析点，`index.ts` 暴露接口方法 |
| `frontend/src/views/` | 页面。只做渲染与交互编排，接口经 `src/api/` 调用 |
| `frontend/src/assets/` | 样式。`main.css` 全局，`page.css` 页面级 |
| `frontend/vite.config.ts` | 构建与开发服务器配置。`/api` 转发目标与开发服务器端口在此声明 |
| `frontend/src/App.vue` | 根组件。当前无路由，出现第二个需跳转的页面时再引入 |

**必须遵守**：

- **前端源码 SHALL NOT 声明后端地址或端口**。请求一律以相对路径（如 `/api/destinations`）
  发起，开发期由 Vite 转发、生产环境由反向代理转发。后端端口的权威来源仍是
  `backend/configs/config.yaml` 的 `server.port`，前端只有 `vite.config.ts` 的
  转发目标引用它。此约束取代了先前的 `API_BASE` 常量做法——端口取值在多处重复时，
  任一处漂移都不会产生信号，页面只会静默地连不上后端。
- **接口响应类型是手工同步的**，不是从后端生成的：后端改动信封或接口数据结构时，
  必须同步检查 `frontend/src/api/types.ts`，否则前端不会报错。
- **前端命令在 `frontend/` 下执行**：`npm run dev`（开发服务器）、`npm run build`
  （类型检查 + 构建）、`npm run typecheck`。首次使用需先 `npm install`。
- **新代码按上表落位**：新增接口改 `src/api/`，新增页面放 `src/views/`。当前未引入
  路由、状态管理与 UI 库（YAGNI）；引入的触发条件见该变更的 `design.md` 决策 5。

仓库级文件留在仓库根，不随后端下移：`Makefile`（编排前后端）、`AGENTS.md`（协作与 AI 约定）、
`README.md`、`.gitignore`、`openspec/`（规格与变更流程）。

## 必须遵守的约定

- **响应信封**：所有接口经由 `backend/internal/platform/response` 构造响应，HTTP 状态码恒为 200，
  业务成败由响应体 `code` 表达（五位分段，`0` 成功、`404xx` 资源不存在、`500xx` 服务端错误）。
  处理函数不得手写 JSON 字面量，业务失败不得改成真实 HTTP 状态码。
- **配置**：从 `backend/configs/config.yaml` 读默认值，`APP_` 前缀环境变量覆盖同名项，
  数组型配置以英文逗号分隔。密钥一律走环境变量，不写进配置文件。
- **日志**：只经由 `backend/internal/platform/logger` 暴露的 `log/slog` 出口，不得引入第二套日志库，
  也不得让框架默认日志与之并存（`gin` 以 `ReleaseMode` 启动、使用 `gin.New()` 而非 `gin.Default()`）。
- **依赖方向**：领域包之间互不引用；领域包可以依赖 `backend/internal/platform`，反向不允许。
  service 层依赖 repository 的**接口**而非具体实现，替换数据来源只需改装配处。
- **工作目录**：后端 Go 命令（构建、运行、测试、格式检查）**必须在 `backend/` 目录下执行**。
  原因：配置默认路径 `configs/config.yaml`（相对后端根）相对**进程工作目录**解析，而配置文件读不到时
  `config.applyFile` 对"文件不存在"返回 nil——**不报错、不告警，直接回落到内置默认值**。
  更麻烦的是，内置默认值与 `backend/configs/config.yaml` 中的取值**当前恰好一致**，
  所以从仓库根误启动时一切看起来都正常，只有当你改了配置文件却发现不生效时才会暴露。
  `Makefile` 的全部后端目标已通过 `cd $(BACKEND_DIR)` 保证这一点；新增 CI 步骤、IDE 运行配置或
  容器启动命令时，必须同样先切到 `backend/`。

## 新增一个业务领域的步骤

1. 新建 `backend/internal/<领域>/` 包，自包含 `model.go`、`repository.go`、`service.go`、`handler.go`。
2. 在 `backend/internal/bootstrap/app.go` 的 `registerRoutes` 中构造依赖并调用该领域的 `Register(api)`。
3. 为 handler 层补 HTTP 契约测试（断言状态码 200 与信封的 `code`/`data` 结构）。

# 开发流程（harness）

本项目采用 spec-driven 的开发流程，按下面的分岔选择入口。**不要跳过前置环节直接写代码。**

| 情况 | 入口 | 说明 |
|------|------|------|
| 需求模糊，不知道要做成什么样 | `superpowers:brainstorming` | 苏格拉底式提问打磨需求，产出设计文档 |
| 需求清楚，但需要先摸清现有代码 | `/opsx:explore` | 探索现状（读代码、理调用链），产出喂给下一步 |
| 需求清楚，直接开工 | `/opsx:propose <change-id>` | 落 spec：proposal + specs + tasks |
| 实现阶段 | `/opsx:apply` | 按 tasks.md 逐条实现 |
| 写测试 / 修 bug | `superpowers:test-driven-development` / `superpowers:systematic-debugging` | 先写失败测试；调试走 4 阶段根因分析 |
| 收尾 | `/opsx:archive` | spec 归档，`openspec/specs/` 增量生长 |

典型链路：

```
需求模糊 → brainstorming
              ↓
需求清楚 → /opsx:propose
              ↓
需要读码 → /opsx:explore（可选，穿插在 propose 前后）
              ↓
实现     → /opsx:apply + test-driven-development
              ↓
收尾     → /opsx:archive
```

## 分工约定

- **brainstorming 负责"想清楚要什么"**（需求层面），**`/opsx:explore` 负责"看清现在是什么"**（代码层面）。两者不重叠。
- 需求模糊时**先 brainstorm**，不要用 explore 代替需求澄清。
- 需求已明确、只是需要了解代码时，直接 `/opsx:explore`，不必 brainstorm。

## 自动化校验

- **spec 一致性**：`openspec validate --all` 做结构校验；`openspec list` 查看在途变更。

## 相关文件

- `openspec/config.yaml` — 项目上下文与各 artifact 的写作规则
- `openspec/specs/` — 系统规格（随每次变更增量生长）
- `openspec/changes/` — 在途变更；已完成的归档到 `openspec/changes/archive/`
- `.claude/commands/opsx/` — OpenSpec 工作流命令（`/opsx:explore`、`/opsx:propose`、`/opsx:apply`、`/opsx:archive` 等）
