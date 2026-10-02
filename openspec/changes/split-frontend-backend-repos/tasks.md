## 1. 前置：工具与远端仓库

- [ ] 1.1 安装 GitHub CLI 并完成登录。
      执行：`brew install gh`，随后 `gh auth login`（交互式，由开发者本人在终端完成，
      选择 HTTPS 或 SSH 并完成授权）。
      验证：`gh auth status` 输出已登录账号 `snzysnk`，退出码为 0。

- [ ] 1.2 确认三个目标仓库名仍未被占用。
      执行：`for r in ChinaTravel ChinaTravel-backend ChinaTravel-frontend; do gh repo view snzysnk/$r; done`。
      验证：三个均报"未找到"；若有任一已存在，暂停并重新确认命名。

## 2. 抽取后端仓库（原目录保持不动）

- [ ] 2.1 把 `backend/` 复制到工作区外的临时目录，并剔除本机产物。
      源目录：`/Users/xieruixiang/Workspace/go/ChinaTravel/backend/`；
      目标：`$TMPDIR/ChinaTravel-backend/`。
      复制后删除其中的 `bin/`（11MB 构建产物）与 `.claude/`（会话态目录）。
      验证：目标目录内 `bin` 与 `.claude` 均不存在，`go.mod`、`go.sum`、`cmd/`、
      `configs/`、`internal/` 五项齐全。

- [ ] 2.2 在后端仓库中改写 Go module path。
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

- [ ] 2.3 为后端仓库补一份自己的 `.gitignore`。
      新建文件：`$TMPDIR/ChinaTravel-backend/.gitignore`。
      内容：以 workspace 现行 `.gitignore` 为蓝本，但构建产物规则由 `/backend/bin/`
      改为 `/bin/`（后端仓库根即模块根，路径锚点随之改变），
      并保留 `*.test`、`*.out`、`.DS_Store`、`.idea/`、`.claude/settings.local.json` 等条目。
      验证：在仓库内执行 `git status --short`，`bin/` 不出现在待提交列表中。

- [ ] 2.4 初始化后端仓库并创建首个提交。
      执行：在 `$TMPDIR/ChinaTravel-backend/` 下 `git init -b main`、`git add -A`、
      `git commit`。
      验证：`git log --oneline` 恰好 1 条提交；`git ls-files | wc -l` 计数与源目录
      剔除后的文件数一致；`git ls-files | grep -E "^bin/|^\.claude/"` 为 0 条。

## 3. 抽取前端仓库（原目录保持不动）

- [ ] 3.1 把 `frontend/` 复制到临时目录并补齐仓库级文件。
      源目录：`/Users/xieruixiang/Workspace/go/ChinaTravel/frontend/`；
      目标：`$TMPDIR/ChinaTravel-frontend/`。
      内容为 `index.html`，另新建一份 `.gitignore`（忽略 `.DS_Store`、`.idea/`）。
      验证：目标目录内 `index.html` 与 `.gitignore` 存在，无其他残留文件。

- [ ] 3.2 初始化前端仓库并创建首个提交。
      执行：在 `$TMPDIR/ChinaTravel-frontend/` 下 `git init -b main`、`git add -A`、`git commit`。
      验证：`git log --oneline` 恰好 1 条提交；`git ls-files` 列出 `index.html` 与 `.gitignore`。

## 4. 创建远端仓库并首推

- [ ] 4.1 创建并推送后端仓库。
      执行：在 `$TMPDIR/ChinaTravel-backend/` 下
      `gh repo create snzysnk/ChinaTravel-backend --public --source=. --push`。
      验证：`gh repo view snzysnk/ChinaTravel-backend --json visibility,defaultBranchRef`
      返回 public 且默认分支为 main；`git ls-remote --heads origin main` 有输出。

- [ ] 4.2 创建并推送前端仓库。
      执行：在 `$TMPDIR/ChinaTravel-frontend/` 下
      `gh repo create snzysnk/ChinaTravel-frontend --public --source=. --push`。
      验证：`gh repo view snzysnk/ChinaTravel-frontend --json visibility,defaultBranchRef`
      返回 public 且默认分支为 main。

## 5. workspace 换骨

- [ ] 5.1 删除 workspace 中的原目录。
      改动：删除 `/Users/xieruixiang/Workspace/go/ChinaTravel/backend/` 与
      `/Users/xieruixiang/Workspace/go/ChinaTravel/frontend/`。
      前置条件：第 2、3、4 组任务全部完成且两个远端仓库已确认可访问。
      验证：仓库根下 `backend/` 与 `frontend/` 均不存在；`Makefile`、`AGENTS.md`、
      `CLAUDE.md`（符号链接）、`README.md`、`.gitignore`、`openspec/`、`.claude/` 仍在。

- [ ] 5.2 以 submodule 形式挂载两个端仓库。
      执行：在仓库根依次执行
      `git submodule add https://github.com/snzysnk/ChinaTravel-backend.git backend`
      与 `git submodule add https://github.com/snzysnk/ChinaTravel-frontend.git frontend`。
      验证：`.gitmodules` 中两个挂载点的 `path` 分别为 `backend`、`frontend`，
      `url` 与之对应；`git submodule status` 两行均以空格开头（非 `-` 或 `+`）。

- [ ] 5.3 更新 `openspec/config.yaml` 中的项目背景硬约束。
      改动文件：`/Users/xieruixiang/Workspace/go/ChinaTravel/openspec/config.yaml`。
      把"已建立 Go 模块 `github.com/xieruixiang/ChinaTravel`"改为
      `github.com/snzysnk/ChinaTravel-backend`，并补充一句仓库拓扑说明：
      workspace 仓库只承载仓库级文件，前后端以 submodule 挂载。
      验证：文件内不再出现 `xieruixiang`；上下文描述与第 5.2 步的实际拓扑一致。

- [ ] 5.4 更新 `README.md` 记载克隆后获取完整工作区的方式。
      改动文件：`/Users/xieruixiang/Workspace/go/ChinaTravel/README.md`。
      补充 `git clone --recurse-submodules <url>` 的用法，
      以及已克隆仓库补拉 submodule 的命令
      `git submodule update --init --recursive`。
      验证：README 中包含上述命令，且两个 submodule 的地址指向正确仓库。

- [ ] 5.5 创建 workspace 仓库的首个提交。
      执行：`git add -A`、`git commit`。
      验证：`git log --oneline` 恰好 1 条提交；`git ls-files | grep -E "^(backend|frontend)/"`
      只返回两个 submodule 路径本身，不返回其内部任何文件。

- [ ] 5.6 创建并推送 workspace 远端仓库。
      执行：`gh repo create snzysnk/ChinaTravel --public --source=. --push`。
      验证：`gh repo view snzysnk/ChinaTravel --json visibility` 返回 public；
      GitHub 仓库页面上 `backend` 与 `frontend` 条目显示为 submodule 链接。

## 6. 端到端验收

- [ ] 6.1 验证后端测试在 submodule 路径下仍可运行。
      执行：`cd /Users/xieruixiang/Workspace/go/ChinaTravel && make test`。
      验证：全部 Go 测试通过，退出码 0。

- [ ] 6.2 验证后端可启动且配置被正常加载。
      执行：`cd /Users/xieruixiang/Workspace/go/ChinaTravel && make run-backend`，
      另开一处请求健康检查接口。
      验证：服务监听 8080；接口返回 HTTP 200 且响应体 `code` 为 0
      （证明 `configs/config.yaml` 被加载，未静默回落到内置默认值）。

- [ ] 6.3 验证前端页面可访问且能连上后端。
      执行：`cd /Users/xieruixiang/Workspace/go/ChinaTravel && make serve-frontend`，
      浏览器访问 `http://localhost:5173`。
      验证：页面正常渲染，页面发起的接口请求未被 CORS 拦截。

- [ ] 6.4 验证全新克隆可获得完整工作区。
      执行：把 workspace 远端仓库克隆到一个全新临时目录
      （`git clone --recurse-submodules https://github.com/snzysnk/ChinaTravel.git`），
      在其中执行 `make test`。
      验证：两个挂载点被填充为端仓库内容，测试通过——
      证明 `workspace-repo-topology` 规格的"克隆即可获得完整工作区"要求成立。

- [ ] 6.5 验证规格一致性。
      执行：`cd /Users/xieruixiang/Workspace/go/ChinaTravel && openspec validate --all`。
      验证：全部通过，0 失败。此为本次变更收尾、可进入 `/opsx:archive` 的判据。
