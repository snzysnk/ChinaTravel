## Context

动机见 `proposal.md`。此处只记录决定实现方式的环境事实：

- workspace 仓库当前 `main` 分支**尚无任何提交**（`git log` 报 "does not have any commits yet"），
  因此**没有需要保留的历史**。这一点使拆分退化为纯粹的文件搬运，
  无需 `git subtree split` 或 `git filter-repo` 这类历史重写工具。
- 本机**未安装 `gh`**，但已装 Homebrew 6.0.19；`git` 的 `credential.helper` 为 `osxkeychain`。
  仓库创建与推送依赖 `gh`，需先安装并由开发者本人完成交互式登录。
- 三个目标仓库名 `snzysnk/ChinaTravel`、`snzysnk/ChinaTravel-backend`、
  `snzysnk/ChinaTravel-frontend` 经 GitHub API 核实**均未被占用**。
- `backend/bin/server` 是一个 11MB 的构建产物，被现行 `.gitignore` 的 `/backend/bin/` 覆盖，
  本就不在版本控制之内。
- 现行 `.gitignore` 是仓库级文件，其规则同时服务于前后端与仓库根；
  拆分后该文件留在 workspace，后端仓库需要一份属于自己的等价规则。

## Goals / Non-Goals

**Goals:**

- 把前后端源码从 workspace 仓库中剥离为独立仓库，并让 workspace 通过 submodule 引用它们。
- 修正指向不存在 GitHub 账号的 Go module path，使其可被 Go 工具链解析。
- 保证剥离过程中两个端仓库的初始提交**不含**会话态文件与构建产物。
- 保证剥离后 `make test` / `make run-backend` / `make serve-frontend` 三条编排入口继续可用，
  且既有六个能力规格描述的行为不变。

**Non-Goals:**

- 不重写或保留任何既有提交历史（无历史可保留）。
- 不改动 HTTP 接口、响应信封、配置项、日志出口与前端页面行为。
- 不为 CI/CD、发布流水线或版本标签建立机制——本次只建立仓库拓扑。
- 不引入 Go 依赖或前端构建工具链的变化。
- 不清理 `openspec/changes/archive/` 中历史文本对旧 module path 的记载——
  归档是历史记录，改写它等于篡改历史。

## Decisions

### 决策 1：module path 采用 `github.com/snzysnk/ChinaTravel-backend`

**理由**：Go module path 在惯例上应当能被 `go get` 解析，即指向真实存在的仓库。
现有路径 `github.com/xieruixiang/ChinaTravel` 指向一个不存在的 GitHub 账号（API 返回 404），
是既有负债。拆分是修正它的唯一自然时机——此后三个仓库各自独立，再做全局替换的代价只增不减。

**备选方案**：

| 方案 | 取舍 |
|------|------|
| 保持 `xieruixiang` 不变 | 零改动，但模块路径永久指向不存在的账号；本次拆分的"顺带修正"窗口关闭 |
| 中性路径（如 `chinatravel/backend`） | 与 GitHub 账号解耦，但不符合 Go 生态惯例，且牺牲了可解析性 |
| **采用 `snzysnk/ChinaTravel-backend`** | 与真实仓库一一对应、可解析；代价是 14 处 import 改写 |

**影响面**：`go.mod` 1 行 + 13 个 `.go` 文件 14 行 import，
全部是机械替换，不涉及任何逻辑。
另需更新 `openspec/config.yaml` 项目背景中的一处描述。

**对既有决策的推翻**：已归档变更 `backend-project-layout` 的 design.md 中
"约束 5：Go 源码的导入路径不随目录移动而改变"明确记载该次变更**刻意不改** module path，
并把它称为"本方案相对重命名 module 方案的主要优势"。本决策推翻它，理由是
该结论依赖"module path 有效"这一前提，而该前提自始不成立。
`backend-project-layout` 的主 spec 描述的是目录布局，未提及 module path，
因此其 requirement 文本无需因本决策改动。

### 决策 2：先抽出端仓库，最后挂载 submodule

**理由**：`git submodule add` 要求目标路径为空，因此**顺序不可颠倒**。
流程为：先把 `backend/` 与 `frontend/` 各自复制到临时位置并初始化为独立仓库，
**此时不触碰原目录**（保留为回退依据），待三个远端仓库就绪并推送成功后，
再清空 workspace 中的原目录并执行挂载。

```
抽取（原目录保留）        推送          换骨（原目录清空）
backend/  --cp-->  tmp/backend-repo      rm -rf backend/
frontend/ --cp-->  tmp/frontend-repo     git submodule add <url> backend
```

**备选方案**：原地 `git init` 后端目录再挂载——被否决，
因为一旦 `git submodule add` 失败，原目录已被 submodule 机制接管，回退路径不清晰。

### 决策 3：用 `gh repo create --source ... --push` 创建并首推

**理由**：一条命令完成"建远端 + 配 remote + 首推"，避免手工配 remote 与逐仓库 push。
`gh` 仅作为一次性的开发工具使用，**不进入 `go.mod`，不成为构建或运行依赖**。

**备选方案**：手工在网页建库（当前 `gh` 未安装时的默认路径）——
虽可行，但三个仓库需要三次网页操作加三次手工 remote 配置，且每次都要确认不勾选
README/.gitignore（否则远端有初始提交，首推会被拒）。
`gh` 路线把这一串易错的手工步骤收敛为命令。

### 决策 4：`backend/bin/server` 与 `backend/.claude/.cc-writes` 直接丢弃

**理由**：两者都是本机产物，不属于可运行的源代码——
前者是 11MB 构建产物（已被 `.gitignore` 覆盖，本就不该入库），
后者是 Claude Code 的会话态目录（经核查 `backend/.claude/` 下仅有 `.cc-writes` 一项，无实质内容）。

**注意**：workspace 根的 `.claude/`（`settings.json` 与 `commands/opsx/*`）**不丢弃**，
它是仓库级的 AI 协作配置，与 `AGENTS.md` 同级，应留在 workspace 仓库。

### 决策 5：镜像现有规格的结构做拆分

**理由**：现有能力规格（`backend-project-layout` 的「仓库级文件 SHALL 留在仓库根」等）
已经把仓库级与后端级的边界写清楚，本次变更本质上是**给这条既有边界补上版本控制的强制力**。
因此新增的 `workspace-repo-topology` 与既有 `backend-project-layout` 的分工是：
前者管"什么归 workspace 仓库跟踪、挂载点如何对应"，后者管"后端源码在目录上长什么样、
命令在哪跑"。两者不重叠。

**备选方案**：把所有内容并入 `backend-project-layout` 一个能力——
被否决，因为 submodule 与远端仓库是独立于目录布局的一类契约，
混入后该能力的 Purpose 会失焦。

## Risks / Trade-offs

- **[submodule 对协作者有学习成本]** → `README.md` 必须明确写出克隆后初始化 submodule 的命令；
  该要求已写入 `workspace-repo-topology` 规格的第四个 requirement。
- **[推送失败导致工作区处于半拆状态]** → 用决策 2 的顺序控制：
  抽取阶段原目录保持原样，只有三个远端仓库全部推送成功后才执行清空与挂载。
  任一步失败时，中止并保留原目录，仓库停留在"已抽取但未换骨"的可重试状态。
- **[`.gitignore` 锚点未同步导致新后端仓库跟踪构建产物]** → 后端仓库的忽略规则
  必须把 `/backend/bin/` 改为 `/bin/`；验证方式是 `git status` 确认
  `bin/` 未出现在待提交列表中。
- **[module path 改写遗漏某处 import]** → 以全仓检索旧路径的结果条数为基准，
  改写后该检索必须归零；编译与测试通过作为第二重验证。
- **[archive 中的旧 module path 记载造成读者困惑]** → 接受。
  归档是当时决策的忠实记录，本变更的 proposal 与 design 已显式记载推翻关系，
  读者沿着归档 → 本次变更的线索可以理解演进过程。
- **[`backend/` 成为 submodule 后 IDE 索引行为变化]** → 已知取舍。
  开发者此后应在**后端仓库**中打开 IDE 处理后端代码，这反而与既有约束
  "后端 Go 命令必须在后端目录下执行"更一致。
- **[两个端仓库的远端独立导致一致性漂移]** → 本次不建立同步机制（见 Non-Goals），
  接受暂时的手工协调成本。
