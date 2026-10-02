## 1. 前置：工具与远端仓库

- [x] 1.1 安装 GitHub CLI 并完成登录。
      执行：`brew install gh`，随后 `gh auth login`（交互式，由开发者本人在终端完成，
      选择 HTTPS 或 SSH 并完成授权）。
      验证：`gh auth status` 输出已登录账号 `snzysnk`，退出码为 0。
      结果：已安装（`/opt/homebrew/bin/gh`），已登录 `snzysnk`，协议 https，token 具备 `repo` 权限。

- [x] 1.2 确认三个目标仓库名仍未被占用。
      执行：`for r in ChinaTravel ChinaTravel-backend ChinaTravel-frontend; do gh repo view snzysnk/$r; done`。
      验证：三个均报"未找到"；若有任一已存在，暂停并重新确认命名。
      结果：GitHub API 对三者均返回 404，确认可用。

## 2. 抽取后端仓库（原目录保持不动）

- [x] 2.1 把 `backend/` 复制到工作区外的临时目录，并剔除本机产物。
      源目录：`/Users/xieruixiang/Workspace/go/ChinaTravel/backend/`；
      目标：`$TMPDIR/ChinaTravel-backend/`。
      复制后删除其中的 `bin/`（11MB 构建产物）与 `.claude/`（会话态目录）。
      验证：目标目录内 `bin` 与 `.claude` 均不存在，`go.mod`、`go.sum`、`cmd/`、
      `configs/`、`internal/` 五项齐全。
      结果：五项齐全，`bin/` 与 `.claude/` 均已剔除。

- [x] 2.2 在后端仓库中改写 Go module path。
      改动文件：`$TMPDIR/ChinaTravel-backend/go.mod` 的 `module` 指令，
      以及其中 13 个 `.go` 文件共 14 行 import——
      `cmd/server/main.go`（2）、`internal/bootstrap/app.go`（6）、
      `internal/bootstrap/app_test.go`（1）、`internal/health/handler.go`（1）、
      `internal/destination/handler.go`（1）、
      `internal/platform/middleware/recovery.go`（1）、
      `internal/platform/logger/logger.go`（1）、
      `internal/platform/logger/logger_test.go`（1）。
      由 `github.com/xieruixiang/ChinaTravel` 改为 `github.com/snzysnk/ChinaTravel-backend`。
      验证：`grep -rn "xieruixiang" .` 结果为 0 条；
      在 `$TMPDIR/ChinaTravel-backend/` 下执行 `go build ./... && go test ./...` 通过。
      结果：改写前旧路径 15 处（1 处 go.mod + 14 处 import），改写后残留 0 条；
      `go build ./...` 通过，`go test ./...` 8 个包全部 ok。

- [x] 2.3 为后端仓库补一份自己的 `.gitignore`。
      新建文件：`$TMPDIR/ChinaTravel-backend/.gitignore`。
      内容：以 workspace 现行 `.gitignore` 为蓝本，但构建产物规则由 `/backend/bin/`
      改为 `/bin/`（后端仓库根即模块根，路径锚点随之改变），
      并保留 `*.test`、`*.out`、`.DS_Store`、`.idea/`、`.claude/settings.local.json` 等条目。
      验证：在仓库内执行 `git status --short`，`bin/` 不出现在待提交列表中。
      结果：已新建，并额外补了 `go.work` / `go.work.sum` 两项；
      `git status --short` 确认 `bin/` 未出现。

- [x] 2.4 初始化后端仓库并创建首个提交。
      执行：在 `$TMPDIR/ChinaTravel-backend/` 下 `git init -b main`、`git add -A`、
      `git commit`。
      验证：`git log --oneline` 恰好 1 条提交；`git ls-files | wc -l` 计数与源目录
      剔除后的文件数一致；`git ls-files | grep -E "^bin/|^\.claude/"` 为 0 条。
      结果：提交 `f40d015`，跟踪 27 个文件（与源目录剔除 `bin/server`、`bin` 目录本身
      及 `.claude/.cc-writes` 后的文件数一致），无 `bin/`、无 `.claude/`。

## 3. 抽取前端仓库（原目录保持不动）

- [x] 3.1 把 `frontend/` 复制到临时目录并补齐仓库级文件。
      源目录：`/Users/xieruixiang/Workspace/go/ChinaTravel/frontend/`；
      目标：`$TMPDIR/ChinaTravel-frontend/`。
      内容为 `index.html`，另新建一份 `.gitignore`（忽略 `.DS_Store`、`.idea/`）。
      验证：目标目录内 `index.html` 与 `.gitignore` 存在，无其他残留文件。
      结果：源目录仅 1 个文件（`index.html`），暂存区无残留；已补 `.gitignore`。

- [x] 3.2 初始化前端仓库并创建首个提交。
      执行：在 `$TMPDIR/ChinaTravel-frontend/` 下 `git init -b main`、`git add -A`、`git commit`。
      验证：`git log --oneline` 恰好 1 条提交；`git ls-files` 列出 `index.html` 与 `.gitignore`。
      结果：提交 `0bb3472`，跟踪 `.gitignore` 与 `index.html` 两项。

## 4. 创建远端仓库并首推

- [x] 4.1 创建并推送后端仓库。
      执行：在 `$TMPDIR/ChinaTravel-backend/` 下
      `gh repo create snzysnk/ChinaTravel-backend --public --source=. --push`。
      验证：`gh repo view snzysnk/ChinaTravel-backend --json visibility,defaultBranchRef`
      返回 public 且默认分支为 main；`git ls-remote --heads origin main` 有输出。
      结果：https://github.com/snzysnk/ChinaTravel-backend 已创建，visibility=PUBLIC，
      默认分支 main，远端 SHA `f40d015` 与本地一致。

- [x] 4.2 创建并推送前端仓库。
      执行：在 `$TMPDIR/ChinaTravel-frontend/` 下
      `gh repo create snzysnk/ChinaTravel-frontend --public --source=. --push`。
      验证：`gh repo view snzysnk/ChinaTravel-frontend --json visibility,defaultBranchRef`
      返回 public 且默认分支为 main。
      结果：https://github.com/snzysnk/ChinaTravel-frontend 已创建，visibility=PUBLIC，
      默认分支 main，远端 SHA `0bb3472` 与本地一致。

## 5. workspace 换骨

- [x] 5.1 删除 workspace 中的原目录。
      改动：删除 `/Users/xieruixiang/Workspace/go/ChinaTravel/backend/` 与
      `/Users/xieruixiang/Workspace/go/ChinaTravel/frontend/`。
      前置条件：第 2、3、4 组任务全部完成且两个远端仓库已确认可访问。
      验证：仓库根下 `backend/` 与 `frontend/` 均不存在；`Makefile`、`AGENTS.md`、
      `CLAUDE.md`（符号链接）、`README.md`、`.gitignore`、`openspec/`、`.claude/` 仍在。
      结果：删除前已确认两个远端仓库 API 返回 200、本地暂存区各含 1 次提交；
      删除后七个仓库级文件/目录全部保留。

- [x] 5.2 以 submodule 形式挂载两个端仓库。
      执行：在仓库根依次执行
      `git submodule add https://github.com/snzysnk/ChinaTravel-backend.git backend`
      与 `git submodule add https://github.com/snzysnk/ChinaTravel-frontend.git frontend`。
      验证：`.gitmodules` 中两个挂载点的 `path` 分别为 `backend`、`frontend`，
      `url` 与之对应；`git submodule status` 两行均以空格开头（非 `-` 或 `+`）。
      结果：`.gitmodules` 与 `.git/config` 中 path/url 均正确；
      `git submodule status` 两行均以空格开头，指向 `f40d015`（backend）与
      `0bb3472`（frontend），与端仓库 main 一致。
      注：首次执行时 `.git/config` 被沙箱拒绝写入（`could not lock config file`），
      命令已克隆子仓库并写入索引、但漏写 `.gitmodules`；后续用
      `git rm --cached` 清除索引条目后重跑，一次完成。

- [x] 5.3 更新 `openspec/config.yaml` 中的项目背景硬约束。
      改动文件：`/Users/xieruixiang/Workspace/go/ChinaTravel/openspec/config.yaml`。
      把"已建立 Go 模块 `github.com/xieruixiang/ChinaTravel`"改为
      `github.com/snzysnk/ChinaTravel-backend`，并补充一句仓库拓扑说明：
      workspace 仓库只承载仓库级文件，前后端以 submodule 挂载。
      验证：文件内不再出现 `xieruixiang`；上下文描述与第 5.2 步的实际拓扑一致。
      结果：旧路径残留 0 条；已补充「仓库拓扑」硬约束条目，并在顶层布局条目中
      说明后端目录本身即后端仓库根与 Go 模块根；`openspec list --specs` 正常解析该文件。

- [x] 5.4 更新 `README.md` 记载克隆后获取完整工作区的方式。
      改动文件：`/Users/xieruixiang/Workspace/go/ChinaTravel/README.md`。
      补充 `git clone --recurse-submodules <url>` 的用法，
      以及已克隆仓库补拉 submodule 的命令
      `git submodule update --init --recursive`。
      验证：README 中包含上述命令，且两个 submodule 的地址指向正确仓库。
      结果：README 新增「仓库拓扑」「获取完整工作区」「开发」三节，
      含上表地址与两条 submodule 命令。

- [x] 5.5 创建 workspace 仓库的首个提交。
      执行：`git add -A`、`git commit`。
      验证：`git log --oneline` 恰好 1 条提交；`git ls-files | grep -E "^(backend|frontend)/"`
      只返回两个 submodule 路径本身，不返回其内部任何文件。
      结果：提交 `bd4f5b0`，44 个跟踪文件；
      `git ls-files | grep -E "^(backend|frontend)"` 恰好返回 `backend`、`frontend` 两行。

- [x] 5.6 创建并推送 workspace 远端仓库。
      执行：`gh repo create snzysnk/ChinaTravel --public --source=. --push`。
      验证：`gh repo view snzysnk/ChinaTravel --json visibility` 返回 public；
      GitHub 仓库页面上 `backend` 与 `frontend` 条目显示为 submodule 链接。
      结果：https://github.com/snzysnk/ChinaTravel 已创建，visibility=PUBLIC，
      默认分支 main，远端 SHA `bd4f5b0` 与本地一致。
      注：`gh repo create` 因 origin 已存在而跳过配 remote（非致命），
      随后用 `git push -u origin main` 完成推送。

## 6. 端到端验收

- [x] 6.1 验证后端测试在 submodule 路径下仍可运行。
      执行：`cd /Users/xieruixiang/Workspace/go/ChinaTravel && make test`。
      验证：全部 Go 测试通过，退出码 0。
      结果：8 个包全部 ok（`github.com/snzysnk/ChinaTravel-backend/...`）。

- [x] 6.2 验证后端可启动且配置被正常加载。
      执行：`cd /Users/xieruixiang/Workspace/go/ChinaTravel && make run-backend`，
      另开一处请求健康检查接口。
      验证：服务监听 8080；接口返回 HTTP 200 且响应体 `code` 为 0
      （证明 `configs/config.yaml` 被加载，未静默回落到内置默认值）。
      结果：服务启动成功；实际监听 **18080**（以 `backend/configs/config.yaml`
      中的 `server.port: 18080` 为准，内置默认值 8080 未被使用——这正好证明配置
      被正常加载），`GET http://localhost:18080/api/health` 返回
      `{"code":0,"msg":"成功","data":{"status":"ok"}}`、HTTP 200。
      注：任务描述中的「监听 8080」依据的是配置文件**内置默认值**，
      与仓库实际配置不符，已按实际配置执行验证。

- [x] 6.3 验证前端页面可访问且能连上后端。
      执行：`cd /Users/xieruixiang/Workspace/go/ChinaTravel && make serve-frontend`，
      浏览器访问 `http://localhost:5173`。
      验证：页面正常渲染，页面发起的接口请求未被 CORS 拦截。
      结果：静态服务在 5173 正常返回页面（HTTP 200）；以 `Origin:
      http://localhost:5173` 向后端 18080 发起的 CORS 预检返回 204 且
      `Access-Control-Allow-Origin: http://localhost:5173`，未被拦截。
      **遗留不一致（本变更范围外，未修改）**：`frontend/index.html:119` 的
      `API_BASE` 硬编码为 `http://localhost:8080`，而实际后端端口为 18080
      （`backend/configs/config.yaml` 的 `server.port`），浏览器端健康检查因此
      会连接失败。该不一致在本变更之前即已存在，与仓库拓扑无关，
      按「不 silently 扩大范围」原则未在此处修复。

- [x] 6.4 验证全新克隆可获得完整工作区。
      执行：把 workspace 远端仓库克隆到一个全新临时目录
      （`git clone --recurse-submodules https://github.com/snzysnk/ChinaTravel.git`），
      在其中执行 `make test`。
      验证：两个挂载点被填充为端仓库内容，测试通过——
      证明 `workspace-repo-topology` 规格的"克隆即可获得完整工作区"要求成立。
      结果：克隆时两个 submodule 自动注册并按 `f40d015`/`0bb3472` 检出；
      `backend/` 含 `.gitignore`、`cmd`、`configs`、`go.mod`、`go.sum`、`internal`，
      `frontend/` 含 `index.html`；新克隆中 `make test` 8 个包全部 ok。

- [x] 6.5 验证规格一致性。
      执行：`cd /Users/xieruixiang/Workspace/go/ChinaTravel && openspec validate --all`。
      验证：全部通过，0 失败。此为本次变更收尾、可进入 `/opsx:archive` 的判据。
      结果：7 项全部通过（6 个主 spec + 本变更），0 失败。
