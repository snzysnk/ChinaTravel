## 1. 前端仓库：修正后端地址

- [x] 1.1 修正 `index.html` 中的后端地址常量。
      改动文件：`/Users/xieruixiang/Workspace/go/ChinaTravel/frontend/index.html`
      （该文件位于前端 submodule 内，提交落在 `snzysnk/ChinaTravel-frontend`）。
      把 `const API_BASE = 'http://localhost:8080';` 改为
      `const API_BASE = 'http://localhost:18080';`；
      同时修正上方注释，说明该取值以后端配置文件 `configs/config.yaml` 的
      `server.port` 为权威来源，改动端口时需同步本行。
      验证：`grep -n "API_BASE" frontend/index.html` 显示的端口为 18080，
      且文件中不再出现 `8080`。
      结果：`index.html:122` 已改为 18080；注释补充了权威来源、
      需同步 workspace 的 `BACKEND_PORT`、以及 `APP_SERVER_PORT` 覆盖时不会自动跟随。
      `grep -n "8080"` 仅命中新值 `18080` 的子串，无独立的 8080 取值。

- [x] 1.2 在前端仓库中提交并推送。
      执行：进入 submodule 目录 `frontend/`，
      `git add index.html && git commit && git push`。
      验证：`cd frontend && git log --oneline -1` 产生新提交；
      `git status --short` 干净；`git ls-remote --heads origin main` 的 SHA
      与该新提交一致。
      结果：提交 `a03714d`；工作区干净；远端 `main` SHA 与本地逐字符一致
      （`a03714d8c9c5c93729b31c70a17c1bace9cfb9dd`）。

## 2. workspace 仓库：对齐编排提示值并更新指针

- [x] 2.1 修正 `Makefile` 的提示端口。
      改动文件：`/Users/xieruixiang/Workspace/go/ChinaTravel/Makefile`。
      把 `BACKEND_PORT ?= 8080` 改为 `BACKEND_PORT ?= 18080`，
      并在其注释中指明权威来源是后端配置文件的 `server.port`。
      验证：`grep -n "BACKEND_PORT" Makefile` 显示取值为 18080；
      执行 `make help` 输出的提示中出现 18080。
      结果：`Makefile:13` 已改为 18080，注释补明权威来源与两处需同步的位置；
      `make help` 输出显示「监听 18080」。

- [x] 2.2 确认 workspace 中不再存在过时的端口取值。
      执行：`grep -rn "8080" --include="*.md" --include="Makefile" --include="*.yaml" .`
      （排除 `openspec/changes/archive/`）。
      验证：无残留的 `8080`；归档目录中的历史记载不改写。
      结果：**前端常量与 Makefile 提示值两处功能性取值均已消除**（唯一剩余命中
      是 `18080` 的子串与本次变更 artifacts 中的前后对照记载）。
      另有三处**正当出现，不属残留，未改动**：
      ① `backend/internal/platform/config/config.go:30` 的 `defaultServerPort = 8080`
         ——它是配置读不到时的编译期兜底值，与"权威来源"是两回事；
      ② `backend/internal/platform/config/config_test.go:84` 的测试输入
         ——测的是 YAML 解析，取值本身无语义；
      ③ `openspec/specs/http-server-bootstrap/spec.md:18` 的示例值
         ——该 scenario 演示 `APP_` 覆盖机制，用 8080→9090 作对照，与权威端口无关。
      本次只改"应当与权威来源一致却已漂移"的取值，不改这三类正当出现。

- [ ] 2.3 提交 workspace 改动，包含 submodule 指针更新。
      改动：`Makefile`、`openspec/` 下本次变更的 artifacts，
      以及 `frontend` 的 submodule 指针（指向第 1.2 步的新提交）。
      执行：`git add -A && git commit && git push`。
      验证：`git submodule status` 中 `frontend` 一行**不以 `+` 开头**
      （`+` 表示指针落后于子仓库 HEAD）；
      `git ls-files | grep -E "^frontend/"` 仍只返回 `frontend` 一行。

## 3. 端到端验收

- [ ] 3.1 验证默认配置下页面能连上后端。
      执行：`cd /Users/xieruixiang/Workspace/go/ChinaTravel && make run-backend`，
      另开一处 `make serve-frontend`，浏览器访问 `http://localhost:5173`。
      验证：页面「服务连通状态」显示为**可用**（而非"检测中…"或"不可用"）；
      「目的地列表」渲染出条目或空状态提示，不显示连接失败文案
      （即不出现 `index.html` 中"无法连接后端服务"的提示）。
      注：后端配置文件 `server.port` 为 18080，故服务监听 18080；
      CORS 白名单 `http://localhost:5173` 已覆盖页面来源。

- [ ] 3.2 验证规格一致性。
      执行：`cd /Users/xieruixiang/Workspace/go/ChinaTravel && openspec validate --all`。
      验证：全部通过，0 失败。此为本次变更收尾、可进入 `/opsx:archive` 的判据。
