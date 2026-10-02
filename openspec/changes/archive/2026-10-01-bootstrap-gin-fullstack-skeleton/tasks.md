## 1. 模块与配置基础

- [x] 1.1 初始化 Go 模块：在 `go.mod` 声明 `module github.com/xieruixiang/ChinaTravel` 与 `go 1.24`，并引入 `github.com/gin-gonic/gin`、`gopkg.in/yaml.v3` 两个依赖。验证：`go mod tidy && go list -m all | grep -E 'gin-gonic|yaml.v3'` 两条依赖均被列出，且 `go.mod` 中模块路径正确。
- [x] 1.2 创建 `configs/config.yaml`：包含 `server.port`（默认 8080）、`server.shutdown_timeout_seconds`（默认 10）、`cors.allow_origins`（默认包含一个本地前端来源）、`log.level`。验证：`cat configs/config.yaml` 内容可读，且用 `python3 -c "import yaml,sys;yaml.safe_load(open('configs/config.yaml'))"` 解析无异常（若本机无 pyyaml 则以 `go run` 的解析测试代替）。
- [x] 1.3 实现配置加载 `internal/platform/config/config.go`：定义与 YAML 结构对应的 `Config` 结构体、默认值填充函数，以及 `APP_` 前缀环境变量的覆盖逻辑（含数组型配置的逗号分隔解析）；每个导出函数必须带注释。验证：新增 `internal/platform/config/config_test.go` 覆盖三个场景——仅 YAML、YAML 被环境变量覆盖、两者皆缺时回落到默认值——`go test ./internal/platform/config/` 通过。

## 2. 公共机制（internal/platform）

- [x] 2.1 实现日志出口 `internal/platform/logger/logger.go`：基于标准库 `log/slog` 提供统一的日志构造入口，日志级别由配置决定，输出到单一目标流。验证：`go build ./internal/platform/logger/` 通过，且 `internal/platform/logger/logger_test.go` 中断言不同级别配置下低级别日志不被输出。
- [x] 2.2 实现响应信封 `internal/platform/response/envelope.go`：定义信封结构体、按需定义的 `code` 常量（当前只需成功码与一个 `404xx` 资源不存在码，分段规则以注释记录），以及"成功携带数据""失败携带错误码与提示"两个构造函数；构造函数与结构体字段均需注释。验证：`internal/platform/response/envelope_test.go` 断言成功响应的 `code` 为 0 且 `data` 非空、失败响应的 `data` 为 `null`，`go test ./internal/platform/response/` 通过。
- [x] 2.3 实现访问日志中间件 `internal/platform/middleware/accesslog.go`：替换框架默认日志，为每个请求输出恰好一条包含方法、路径、状态码、耗时、客户端地址的 `slog` 日志；需说明为何不使用框架默认日志中间件。验证：`internal/platform/middleware/accesslog_test.go` 用 `httptest` 发起一次请求，断言捕获到的日志恰好一条且包含全部五个字段。
- [x] 2.4 实现 CORS 中间件 `internal/platform/middleware/cors.go`：按配置中的白名单校验 `Origin`、正确处理 `OPTIONS` 预检（返回允许的方法/请求头/有效期且不进入业务处理）、声明允许携带凭据、对无 `Origin` 的同源请求放行且不加跨域头；需注释说明为何允许凭据时来源不能为通配符。验证：`internal/platform/middleware/cors_test.go` 覆盖"白名单内被放行""白名单外不被放行""预检被正确响应""无 Origin 请求不受影响"四个场景，`go test ./internal/platform/middleware/` 通过。
- [x] 2.5 实现 panic 恢复中间件 `internal/platform/middleware/recovery.go`：捕获 panic、记录含 panic 信息与请求路径的错误日志、并返回**信封格式**的服务端错误响应（不得为空 body）。验证：`internal/platform/middleware/recovery_test.go` 构造一个必然 panic 的处理函数并断言响应体可被解析为信封且 `code` 属于 `500xx` 分段。

## 3. 装配与进程入口

- [x] 3.1 实现装配模块 `internal/bootstrap/app.go`：导出 `Build(cfg *config.Config) *gin.Engine`，在其中完成各构件的创建与注入（仓储→服务→处理函数）、中间件挂载（访问日志、CORS、恢复）、路由注册与 404 处理器设置；不得在其中绑定端口。验证：`go build ./internal/bootstrap/` 通过，且 `internal/bootstrap/app_test.go` 断言 `Build` 返回的处理器可被 `httptest` 调用而不占用真实端口。
- [x] 3.2 实现进程入口 `cmd/server/main.go`：加载配置、调用 `bootstrap.Build`、绑定端口启动，并通过 `signal.NotifyContext` 捕获 `SIGINT`/`SIGTERM` 执行带超时上限的优雅关闭；需注释说明关闭流程。验证：`go build ./cmd/server/` 通过；`go run ./cmd/server/` 启动后 `curl -s http://localhost:8080/api/health` 返回信封，向进程发送 `SIGINT` 后进程在超时上限内退出。

## 4. 领域实现

- [x] 4.1 实现健康检查领域 `internal/health/handler.go`：提供 `GET /api/health`，返回成功信封且 `data` 中含服务状态信息；需注释说明该接口的用途。验证：`go test ./internal/health/` 中的 `httptest` 用例断言状态码为 200、`code` 为 0、`data` 中存在状态字段。
- [x] 4.2 实现示例领域的数据模型与仓储 `internal/destination/model.go`、`internal/destination/repository.go`：定义 `Destination` 模型、仓储接口、内存实现（含示例数据，注释中显式标注"示例数据，非持久化，进程重启即丢失"）；每个方法需注释。验证：`internal/destination/repository_test.go` 断言内存实现按预期返回全部条目及按标识查询的结果，`go test ./internal/destination/` 通过。
- [x] 4.3 实现示例领域的服务层 `internal/destination/service.go`：对外暴露列表查询（及按标识查询，若被处理函数使用），依赖仓储接口而非具体实现；每个方法需注释。验证：`go build ./internal/destination/` 通过，且 `service` 的构造函数只接受仓储接口类型（可用 `go vet ./internal/destination/` 与代码审查确认依赖方向）。
- [x] 4.4 实现示例领域的处理函数 `internal/destination/handler.go`：`GET /api/destinations` 返回列表信封，资源不存在时返回 `404xx` 错误信封（`data` 为 `null`）；不得硬编码数据、不得手写 JSON 字面量。验证：`internal/destination/handler_test.go` 断言成功场景下 `code` 为 0 且 `data` 为数组、其长度与仓储条目数一致，失败场景下 HTTP 状态码仍为 200 而 `code` 非零且 `data` 为 `null`，`go test ./internal/destination/` 通过。
- [x] 4.5 在 `internal/bootstrap/app.go` 中注册 `internal/health` 与 `internal/destination` 的路由，并确认这是本变更中唯一需要为新增领域改动的既有文件。验证：`go test ./...` 全部通过，且 `curl -s http://localhost:8080/api/destinations` 返回包含数据项的信封。

## 5. 前端与任务编排

- [x] 5.1 创建静态前端 `frontend/index.html`：包含统一的信封解析函数（先判 `code`、为零取 `data`、非零展示 `msg`）、调用健康检查接口展示连通状态、调用列表接口逐项渲染并支持空集合的空状态提示、后端不可达时页面不崩溃；文件顶部注释写明"以文件协议打开不受支持"与"页面逻辑增长时应评估迁移到带构建的前端工程"。验证：人工启动两个服务后打开页面，健康状态与列表条目均正确渲染；停掉后端刷新页面，页面展示服务不可用且控制台无未捕获异常。
- [x] 5.2 创建 `Makefile`：提供 `run-backend`（`go run ./cmd/server/`）、`serve-frontend`（在 `frontend/` 目录下以 `npx serve` 在约定端口启动静态服务）、`test`（`go test ./...`）、`build`（`go build -o bin/server ./cmd/server/`）、`fmt`（`gofmt -l .`）五个目标，并设一个默认 `help` 目标列出全部命令；需注释说明各目标用途。验证：`make help` 列出全部目标；`make test` 与 `make build` 成功；`make build` 后在 `bin/server` 生成可执行文件（`.gitignore` 已忽略 `/bin/`）。

## 6. 端到端验收与项目文档同步

- [x] 6.1 执行分离式部署的人工端到端验收：终端 A 执行 `make run-backend`，终端 B 执行 `make serve-frontend`；浏览器访问前端地址后，在开发者工具 Network 面板中确认——列表请求存在 `OPTIONS` 预检且预检响应头包含允许的方法与请求头、正式请求响应头包含允许来源、响应体为信封且 `code` 为 0。验证：三项观察结果均成立并记录实际响应头，作为本变更的验收证据。
  - **执行方式**：由用户按原步骤人工执行——终端 A `make run-backend`，终端 B `make serve-frontend`，浏览器打开 `http://localhost:5173` 并在 Network 面板观察。下方报文为后端 18080（`APP_SERVER_PORT` 覆盖）上复现的同一组请求，与浏览器观察结果一致。
  - **一项与原任务的偏差（重要）**：原任务假定列表请求会触发 `OPTIONS` 预检，实测**没有预检**，且这是正确行为。页面发出的 `GET /api/destinations` 只带 `Accept: application/json`（`frontend/index.html`），属 CORS 简单请求——方法在允许之列、请求头全是安全列表头，浏览器不发送预检。因此正式请求的响应头中也不会出现 `Access-Control-Allow-Methods` / `Access-Control-Allow-Headers` / `Access-Control-Max-Age`（这三项只出现在预检响应中），属预期而非缺失。
  - **预检行为的独立验证**：`cross-origin-access` 规格中"预检请求 SHALL 被正确响应"这一条，需用一个非简单请求单独触发——例如携带自定义请求头 `X-Probe` 的跨域请求。浏览器将先发预检，报文如下（经 curl 复现，与浏览器行为一致）：

    ```
    OPTIONS /api/destinations
    Origin: http://localhost:5173
    Access-Control-Request-Method: GET
    Access-Control-Request-Headers: x-probe

    -> HTTP/1.1 204 No Content
    Access-Control-Allow-Origin: http://localhost:5173
    Access-Control-Allow-Credentials: true
    Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS
    Access-Control-Allow-Headers: Content-Type, Authorization
    Access-Control-Max-Age: 43200
    Vary: Origin
    ```
    预检返回 204 且无业务信封，符合"不进入业务处理"的要求；允许的方法、请求头与有效期均已声明。**已知边界**：`Access-Control-Allow-Headers` 未包含 `x-probe`，故该探针请求的正式请求会被浏览器拦下——这不影响本变更（正式请求只带 `Accept`，属安全列表头），但若将来前端需携带自定义头，须先扩充 `internal/platform/middleware/cors.go` 中的 `allowedHeaders`。
  - **验收证据（正式请求）**：

    ```
    GET /api/destinations  Origin: http://localhost:5173
    HTTP/1.1 200 OK
    Access-Control-Allow-Origin: http://localhost:5173
    Access-Control-Allow-Credentials: true
    Vary: Origin

    {"code":0,"msg":"成功","data":[{"id":"beijing",...},{"id":"xian",...},{"id":"guilin",...}]}
    ```
    响应头包含允许来源，响应体为信封且 `code` 为 0，页面上连通状态与三条目的地均正确渲染。
- [x] 6.2 执行跨域拒绝验收：将前端静态服务换到一个**不在** `configs/config.yaml` 白名单内的端口启动，浏览器访问后确认请求被浏览器拦截、页面展示服务不可用（证明白名单确实生效，而非全量放行）。验证：Network 面板中该请求标记为 CORS 失败，且页面未渲染出数据。
  - **执行方式**：由用户按原步骤人工执行——后端保持 6.1 的运行状态不动，终端 B 改为 `cd frontend && npx --yes serve -l 6000 .`，浏览器打开 `http://localhost:6000` 并硬刷新（规避 6.1 遗留的 12 小时预检缓存）后在 Network / Console 面板观察。**全程未修改白名单**，仅更换前端 origin。
  - **验收证据（浏览器观察）**：
    - Network 面板中该请求的响应头**不含** `Access-Control-Allow-Origin`（只有 `Vary: Origin`），未被授予跨域读取权限；
    - Console 报 CORS 拦截，原因为响应缺少 `Access-Control-Allow-Origin`；
    - 页面目的地列表**未渲染出任何数据**，连通状态显示"服务不可用"。
  - **对照判据**：同一后端、同一份代码、同一个页面，仅 Origin 由 `http://localhost:5173` 换成 `http://localhost:6000`，结果即从"正常渲染三条数据"变为"被浏览器拦截且页面为空"。据此排除"失败源于其他因素"，确认白名单确实生效而非全量放行。
  - **补充说明（避免误判）**：该请求在 Network 面板中可能仍显示 `200`——服务端照常处理并返回合法信封，这是信封契约（HTTP 恒 200）的既定后果，`design.md` 决策 2 已记录该代价。故通过与否的判据是**响应头是否授予来源**与**页面是否渲染出数据**，而非请求状态码。
  - **服务端侧复现（curl，非白名单来源）**：

    ```
    GET /api/destinations  Origin: http://localhost:6000
    HTTP/1.1 200 OK
    Vary: Origin                     <- 仅声明缓存随来源变化，无任何 Access-Control-Allow-* 头

    {"code":0,"msg":"成功","data":[...]}
    ```
    与浏览器观察一致：响应体是合法信封，但不含任何跨域授权头。另验证同源（无 `Origin`）请求不受影响，正常返回同一信封且不带跨域头，符合"同源请求 SHALL 不受影响"。
- [x] 6.3 更新 `openspec/config.yaml` 的项目背景表述：将"尚未建立 go.mod，也未确定目录分层、Web 框架与依赖约定"改写为反映本变更后的实际状态（已建立模块、已定 Gin、目录分层见变更归档后的主 spec）。验证：`openspec validate --all` 通过，且 `grep -n "未确定\|未建立" openspec/config.yaml` 不再命中过期表述。
- [x] 6.4 更新 `AGENTS.md` 的「项目规范」章节：移除"架构未定阶段"的说明，改为指向本变更确立的常驻约定（目录分层、信封契约、配置与日志约定），并把 `.agents/specs/` 的挂载示例替换为真实存在的规范文件名。验证：`cat AGENTS.md` 中「项目规范」章节不再出现"架构未定"，且所引用的文件路径真实存在。
- [x] 6.5 运行全量一致性校验：执行 `openspec validate --all` 与 `go test ./...`。验证：两条命令均无错误输出；若变更已归档，则 `openspec list --specs` 能列出本变更引入的五个能力。
