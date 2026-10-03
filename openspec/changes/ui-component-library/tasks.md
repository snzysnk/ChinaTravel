## 1. 依赖引入

- [x] 1.1 在 `frontend/package.json` 中新增运行期依赖 `element-plus` 与 `@element-plus/icons-vue`，
      在 `devDependencies` 中新增 `unplugin-vue-components` 与 `unplugin-auto-import`；
      验证：在 `frontend/` 下执行 `npm install` 成功，且 `package.json` 与 `package-lock.json`
      同时被更新（两者不得脱节）。
      **注**：沙箱内 `~/.npm` 不可写（存在 root 属主的缓存目录），安装时改用
      `npm install --cache "$TMPDIR/npm-cache"`，不影响依赖解析结果。

- [x] 1.2 提交一次「仅引入依赖、未改动任何页面」的状态，作为可独立回滚的基线；
      验证：`git log --oneline -1` 显示该提交，且 `git diff --stat HEAD~1` 只含
      `package.json` 与 `package-lock.json`（设计文档「回滚策略」要求此基线存在）。
      结果：提交 `e365cb7`，diff 仅含该两文件（673 行新增），`npm run typecheck` 与
      `npm run build` 均通过。基线产物体积记录：JS 66,320 B / CSS 793 B / index.html 1,080 B。

## 2. 构建配置

- [x] 2.1 在 `frontend/vite.config.ts` 中挂载 `unplugin-auto-import` 与
      `unplugin-vue-components` 的 Element Plus 解析器（`ElementPlusResolver`）；
      验证：`npm run build` 通过，且产物中不含未使用组件（在 `frontend/dist/assets/` 下
      检索一个本项目未使用的组件名如 `ElTransfer`，应无匹配）。
      结果：`npm run build` 通过；产物中 `ElTransfer` / `el-transfer` 匹配数为 0。
      `AutoImport` 的 `imports` 仅保留 `'vue'`（不再自动导入 Element Plus 的函数式 API），
      理由是「函数凭空出现」会削弱本项目首要指标「错误暴露在阅读层面」——详见 design.md 决策 2。

- [x] 2.2 复核 `frontend/vite.config.ts` 中的 `BACKEND_PORT`（18080）与 `DEV_SERVER_PORT`（5174）
      在 2.1 改动后取值未变，且插件配置与这两个常量分区书写、各有注释说明互不相关；
      验证：在 `frontend/` 下执行 `git diff` 目视核对两常量行未被触碰，
      并在仓库根执行 `grep -rn "18080" frontend/src/` 应无匹配
      （满足 `frontend-toolchain` 规格「前端制品中不含后端端口」场景）。
      结果：`git diff vite.config.ts` 中两常量的赋值行均未出现于增减行，取值未变；
      `grep -rn "18080" frontend/src/` 无匹配。文件头已补分区约定注释。

- [x] 2.3 确认自动导入生成的类型声明文件被 `frontend/tsconfig.json` 的 `include` 覆盖；
      验证：在 `frontend/` 下执行 `npm run typecheck` 通过，且此时在
      `frontend/src/views/DestinationHome.vue` 模板中临时写入 `<el-button>test</el-button>`
      不产生「找不到名称」类错误（验证后移除该临时内容）。
      **此项是设计文档决策 2 列出的最可能踩坑点，必须实际执行而非目视判断。**
      结果：**设计文档的风险判断方向需要修正**。实际行为是——`Components()` 的 `dts`
      文件只在解析到组件后按需生成，首次构建时 `src/components.d.ts` 并不存在，
      vue-tsc 在「组件尚未被解析」时也不报错。实测写入 `<el-button>probe</el-button>` 后
      `npm run typecheck` 退出码 0、`npm run build` 成功（1608 模块，CSS 0.79 kB → 28.51 kB，
      JS 66.32 kB → 109.17 kB），产物 CSS 中含 `el-button` 样式，证明组件确实被解析并打包。
      即：**该「踩坑点」在当前版本组合下不发生**（unplugin-vue-components 32.x 的 `dts`
      生成时机已避开时序问题），无需 `tsconfig.json` 改动；`src/auto-imports.d.ts` 落在
      `src/` 下，已被既有的 `include`（`src/**/*.d.ts`）覆盖。
      **⚠️ 该结论在后续任务中被证伪，此处更正**：风险确实存在，只是**推迟一次构建**才显形。
      `Components()` 的 `dts` 由 `vite build` 阶段写出，而 `vue-tsc` 在它之前运行——
      于是「首次构建」时模板里的组件标签尚未被声明，vue-tsc 不对其做任何属性/插槽检查，
      构建通过；**紧接着的下一次构建**才拿新声明去检查，问题在那里才报错。实测证据：
      4.1 完成后首次 `npm run build` 通过（JS 309,198 B），第二次构建即报
      `DestinationHome.vue(108,55): error TS2345: Argument of type 'DefaultRow' is not
      assignable to parameter of type 'Destination'`（详见 4.1 的结果）。
      因此**「构建通过」必须连做两次才算数**，且 `src/components.d.ts` 与
      `src/auto-imports.d.ts` 目前**未入库也未忽略**（`git status` 显示为未跟踪）——
      不入库会让类型门禁依赖构建次序，建议随本变更一并提交。

## 3. 全局配置

- [x] 3.1 在 `frontend/src/main.ts` 中引入 Element Plus 的 `zh-cn` 语言包并以全局配置方式生效；
      验证：`npm run typecheck` 与 `npm run build` 通过，且后续 3.3 的日期/分页验证能观察到中文文案。
      结果：**落点由 `main.ts` 改为 `App.vue`（偏离字面要求，已确认后调整）**。原写法
      `app.use(ElementPlus, { locale })` 实测把组件库**全部**组件注册进产物：
      JS 66,320 B → 1,029,702 B（15.5×），且产物中出现本项目从未使用的 `ElTransfer`，
      直接违反本变更自己新增的规格「组件库 SHALL 按需加载」中「SHALL NOT 在应用入口
      全量注册」与其场景「未使用的组件不进入产物」。规格优先级高于任务字面描述，
      故改用 `<el-config-provider :locale>` 包裹根组件（Element Plus 官方按需引入的
      文档做法），实测 JS 309,198 B、产物中无未使用组件；「语言包全局生效」的效果不变。
      附带发现一处**上游类型缺陷**（非用法错误）：`ConfigProviderProps['locale']` 被推导成
      prop 描述对象而非 `Language`（`ExtractPropTypes` 不认 element-plus 构建 props 用的
      `__epPropKey` 标记），直接绑定报 TS2739；故 App.vue 保留一处带长注释的断言，
      落点类型经 `NonNullable<ConfigProviderProps['locale']>` 取得。

- [x] 3.2 新建设计变量覆盖文件（**路径待定**：`frontend/src/assets/theme.css` 或
      `frontend/src/styles/element.css`，依据是实现时该仓库的目录整洁度——
      设计文档「Open Questions」已记录两种落位均不影响任何 Requirement 的可观察行为），
      在其中仅以设计变量与会话级全局配置覆盖组件库默认视觉；
      验证：`npm run build` 通过，且该文件中不出现 `:deep()` 或组件内部类名
      （满足 `frontend-ui-library` 规格「组件库的设计变量 SHALL 在单一位置覆盖」场景）。
      结果：**路径定为 `frontend/src/assets/theme.css`**。依据目录整洁度：`src/assets/`
      已是全部样式的所在地（`main.css` / `page.css`），为单个文件另起 `src/styles/`
      只会多出第二个样式目录。复核通过：文件中只有一条 `:root` 选择器与 `--el-*` 变量声明，
      无 `:deep()`、无组件内部类名。覆盖范围刻意收窄——只把中性色与语义色对齐到 `main.css`
      的既有令牌（`--text`/`--muted`/`--border`/`--ok`/`--bad`），不引入新配色；
      未覆盖 `--el-color-primary`：项目当前没有品牌主色，临时挑一个属视觉改版（Non-Goals）。

- [x] 3.3 在具备日期选择与分页组件的临时验证页中确认内置文案为中文，
      验证完成后移除该临时页；
      验证：目视观察到星期、月份、分页文案均为中文（满足「组件库内置文案 SHALL 为中文」场景）。
      结果：**验证方式由「临时页 + 目视」改为「临时脚本 + 可执行断言」**。理由：临时页与目视
      只能证明「构建通过」，证明不了文案真的变成了中文，且不可复现。脚本用 SSR 渲染分页与
      日期面板，各自在**有/无**语言包两种情况下取一次结果并对比——无语言包时不出现中文，
      作为反向判据，证明判据本身有效（而非恰好命中别处的字符串）。6 项判据全部通过：
      分页「共 100 条 / 上一页 / 下一页」、日期面板「上个月 / 下个月 / 前一年」在有语言包时
      出现、无语言包时不出现。两处组件行为与直觉不同，均属组件本身特性而非绕过验证：
      ① 日期选择器须渲染 `ElDatePickerPanel` 而非 `ElDatePicker`——面板经 teleport 输出，
      关闭状态下 SSR 结果里只有 `<!--teleport start--><!--teleport end-->`，取不到任何文案；
      ② 日期选择器输入框的 placeholder 默认为空串（`placeholder` 属性 `default: ""`），
      本就不承担语言包文案，不能作判据（最初的判据选错即栽在这里）。
      临时脚本 `locale-probe.mjs` 已删除（与「验证完成后移除临时页」同等对待）。

## 4. 既有页面迁移

- [x] 4.1 将 `frontend/src/views/DestinationHome.vue` 中的手写交互元素替换为组件库组件
      （列表、状态展示、空态、错误提示、刷新按钮），保持模板中的类型收窄与
      「失败态优先」的渲染顺序不变；
      验证：`npm run typecheck` 与 `npm run build` 通过，且 `npm run dev` 后页面
      三态（加载中 / 空集合 / 有数据）与失败态均可复现。
      结果：`el-tag`（状态展示）/ `el-table`（列表）/ `el-empty`（空态）/ `el-alert`（失败态）/
      `el-button`（刷新）完成替换。**脚本部分一字未动**——仅新增 `displayName` 辅助函数并保留
      原 `name || id || '(未命名)'` 降级顺序，故三态与「失败态优先」的渲染顺序不变。
      三处需记录：
      ① **状态胶囊迁移为 `el-tag`（偏离字面要求，已确认后调整）**：4.1 要求迁移「状态展示」，
      而 4.2 又举「状态胶囊」为应保留项。规格「既有手写元素完成迁移…页面内不再保留其手写实现」
      要求迁移，故以规格为准；代价是原先状态胶囊里的圆点消失，配色由 3.2 的语义色映射保留。
      ② 「加载中」一行不在 4.1 列举的迁移范围内，但它的 `.empty` 类要随 4.2 一并删除，
      故改用 `el-text type="info"`，使 `page.css` 不再残留任何文本态样式（属 4.2 约束的必然结果）。
      ③ **表格插槽的类型断言**：组件库把插槽的 `row` 声明为宽松行类型
      （`DefaultRow = Record<PropertyKey, any>`），按需引入下组件是运行时解析、拿不到表格的
      泛型推导，且该宽松类型无法反向收窄成具名行类型（写 `{ row }: { row: Destination }`
      报 TS2322），故在调用处保留一处断言 `displayName(row as Destination)`。
      该错误**首次构建不报、第二次构建才报**（成因见 2.3 的更正）。
      `npm run typecheck` 与连续两次 `npm run build` 均通过。

- [x] 4.2 从 `frontend/src/assets/page.css` 中移除与组件库职责重叠的样式
      （按钮、空态、错误提示），保留卡片、状态胶囊等尚无组件库等价物或属布局类的样式；
      验证：页面在 `npm run dev` 下视觉与替换前一致，且 `page.css` 中不再存在
      针对按钮与空态/错误提示的选择器（满足「既有手写元素完成迁移」场景）。
      结果：已移除 `button` / `button:hover` / `.empty` / `.error` / `.status`（含 `.ok`/`.bad`）
      / `.dot`，以及 `DestinationHome.vue` 中整段 `<style scoped>`（其 `ul.destinations` 等
      选择器随 `el-table` 替换后已无对应结构）。保留：`.page` / `.page h1` / `.subtitle`
      / `.card` / `.card h2` / `.refresh-row`——均为页面容器布局与标题字号，
      组件库不提供等价物，也不与组件库职责重叠。
      **状态胶囊按 4.2 的字面要求本应保留，但因 4.1 已迁移为 `el-tag` 而一并移除**
      （两任务字面冲突，经确认以规格为准，详见 4.1 结果①），故本条的「保留状态胶囊」
      措辞与最终实现不一致。

- [x] 4.3 确认 `frontend/src/components/` 的落位规则已在本变更范围内确立，
      且未制造空目录或「为了用而抽」的组件；
      验证：`ls frontend/src/components/ 2>/dev/null` 为空或不存在的状态可被合理解释
      （当前只有一个页面，按 YAGNI 不提前抽取——设计文档决策 6）。
      结果：`frontend/src/components/` **不存在**（`ls` 返回 "No such file or directory"），
      符合设计文档决策 6——本变更确立的是**规则**（何时该抽、抽到哪），
      而非在只有一个页面时先造一个空目录。规则落到 `frontend-ui-library` 规格的
      「组件层 SHALL 有约定的落位」要求；本页仅有的界面片段（状态标记、列表、空态）
      都改为组件库组件，没有产生「页面专用片段」，故无需任何目录承载。

## 5. 端到端验收

- [ ] 5.1 同时启动前后端（仓库根 `make dev` 或分别执行 `cd backend && go run ./cmd/server`
      与 `cd frontend && npm run dev`），逐项对照替换前的页面行为：
      健康状态三态、列表有数据/空集合/失败态、重新加载按钮；
      验证：每项行为与替换前一致，且浏览器网络面板中请求来源与页面同源
      （满足 `frontend-toolchain` 规格「开发期经转发访问后端」场景）。
      **状态：机器可核验的部分已通过，目视部分待人工确认，故保持未勾选。**
      已核验：前后端均已监听（后端 18080 / 前端 5174，两者为会话开始前已在运行的进程）；
      经开发服务器转发取 `/api/health` 与 `/api/destinations`，返回的信封与直连后端完全一致
      （`{"code":0,"msg":"成功",...}`），且请求 URL 与页面同为 `http://localhost:<dev端口>`，
      即**同源转发成立**；页面组件树经开发服务器编译后确为迁移后的版本
      （解析出 `_component_el_table` / `_component_el_alert` / `_component_el_empty` /
      `_component_el_tag` / `_component_el_button` / `_component_el_text` /
      `_component_el_config_provider`）。
      **未核验（需人工）**：三态与失败态的实际渲染结果、重新加载按钮的点击效果、浏览器网络面板。
      两项需要在人工验收前知晓的环境事实：
      ① **会话开始前已在运行的前端开发服务器不会拾取本次改动**——实测其对
      `src/views/DestinationHome.vue` 仍返回迁移前的内容（`touch` 后 Etag 不变），
      验收前须重启该进程；另起一个开发服务器（5199）则正常提供迁移后的版本。
      ② 失败态需要后端不可达才能复现，验收时请用「停掉后端再刷新」的方式观察，
      而非依赖当前数据。

- [x] 5.2 记录替换前后 `frontend/dist/` 的产物大小对比，作为本变更的成本证据；
      验证：给出两次构建的产物体积数值，并确认按需引入后的体积小于全量注册的估算值
      （设计文档「Risks / Trade-offs」要求此项可观测）。
      结果：三次构建的实测数值（`dist/assets/` 精确字节）：

      | 构建 | JS | CSS | 未使用组件 |
      |---|---|---|---|
      | 基线（引入依赖前，见 1.2） | 66,320 B | 793 B | — |
      | 在入口全量注册（`app.use(ElementPlus)`） | **1,029,702 B** | 1,508 B | 含 `ElTransfer` |
      | **本变更最终形态（按需 + 组件迁移后）** | **309,198 B**（gzip 111,264） | **70,301 B**（gzip 9,772） | 无 |

      `index.html` 恒为 1,080 B。两点结论：
      ① 按需引入后的体积 **309,198 B 远小于全量注册的 1,029,702 B**（约 1/3.3），
      本条验证通过；注意全量注册那一版的 CSS 反而只有 1,508 B——入口 `import 'element-plus'`
      并不带入组件样式，于是「全部组件都注册了、样式却一个没进」，是最差的一种组合，
      这也是 3.1 改落点的直接证据。
      ② 最终 JS 是基线的 4.7 倍，这是引入组件库的真实成本。其中大部分来自 `el-table`
      （含其内部的虚拟滚动与 `lodash-es` 依赖）——即「不再手写交互元素」的代价是可观测、
      且随用量增长的，与 design.md「产物体积虽然按需，仍会大于手写 CSS」的预期一致。
      ③ 另一项与体积有关的实测（不在本任务原定范围内，但它推翻了 design.md 决策 3 的原结论，
      故记录于此）：**全局注册 `@element-plus/icons-vue` 的全部图标**会使 JS 由 309,198 B
      增至 475,165 B（+165,967 B，+53.7%），而没有任何页面直接使用图标。据此决策 3 已修订为
      「声明依赖但不全局注册」，`proposal.md` 的 Impact 条目同步更正。

- [x] 5.3 在仓库根执行 `openspec validate --all` 确认 spec 一致性；
      验证：输出显示全部通过，0 failed。
      结果：`Totals: 9 passed, 0 failed (9 items)`，其中含 `change/ui-component-library`。
      9 项为：8 个主 spec（api-response-envelope、backend-project-layout、cross-origin-access、
      frontend-api-integration、frontend-toolchain、http-server-bootstrap、observability-baseline、
      workspace-repo-topology）与本变更。
