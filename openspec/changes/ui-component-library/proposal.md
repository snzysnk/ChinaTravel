## Why

前端已由 `frontend-stack-and-toolchain` 变更建立了 Vue 3 + TypeScript + Vite 工程骨架，
但界面仍是手写 CSS 的裸 DOM 结构：当前页面 `DestinationHome.vue`（142 行）只有列表、
状态胶囊与按钮，样式在 `assets/page.css` 与组件 `<style scoped>` 中逐条手写。
随着目的地详情、搜索筛选、行程表单等功能进入，每个表格、表单、弹窗都要手写一套
「结构 + 样式 + 交互 + 校验」，成本随功能数线性增长，且手写实现缺乏统一的交互语义
（键盘可达性、禁用态、加载态、错误态）。

本变更决定**直接引入 Element Plus** 作为组件库。**该决策在知情前提下作出**：
`frontend-stack-and-toolchain` 的 `design.md` 决策 5 明确规定「出现表单、表格等成规模的
交互组件时评估 UI 库」，而当前尚未出现这类组件——需求方明确知晓 YAGNI 条款仍选择提前引入。
提前引入的代价是真实的（依赖体积、主题定制成本、组件库版本升级负担），此处如实记录，
不将其粉饰为「已到触发条件」。

## What Changes

- 引入 **Element Plus** 作为前端 UI 组件库，替代手写 DOM 结构 + 手写样式。
- 收敛既有页面 `DestinationHome.vue` 的手写实现：状态展示、空态、错误提示改用组件库组件，
  视觉与交互流程**不改变**（沿用 `frontend-stack-and-toolchain` 决策 7 的「原样搬运」原则）。
- 确立**按需引入**（unplugin-vue-components + unplugin-auto-import），避免全量注册导致
  产物体积与首屏加载成本失控。
- 确立**中文语言包全局配置**（`zh-cn` locale），使日期选择、分页等组件的内置文案为中文，
  与国内中后台场景一致。
- 确立**主题定制入口**：全站设计变量的唯一覆盖位置，避免样式散落在各组件中导致失控。
- 明确**同时引入 Element Plus 官方图标包** `@element-plus/icons-vue`，并约定**不**全局注册
  （页面按需引用）——依据见 `design.md` 决策 3 的修订说明。
- **BREAKING**：无。本变更不修改任何既有 spec 的行为要求；`frontend-toolchain` 的
  「目录约定」要求由组件层目录填充，属对该要求的落地而非改写。既有 `frontend-api-integration`
  与 `api-response-envelope` 契约不受影响。

## Capabilities

### New Capabilities

- `frontend-ui-library`：前端 UI 组件库的选型结论、引入方式（按需加载）、语言包与主题约定、
  组件使用与目录落位规则。

### Modified Capabilities

<!-- 无。本变更不改变既有能力的可观察行为：
     - frontend-toolchain 的「前端 SHALL 遵循统一的目录约定」已规定「可复用组件」位于约定目录，
       本变更是对该目录的填充，不新增或改写要求；
     - frontend-api-integration / api-response-envelope 契约为组件库替换所不动。
     如评审认为「组件库的中文语言包」构成对既有能力的实质补充，可在 propose 评审阶段提出，
     届时改为新增一条 MODIFIED 要求。 -->

## Impact

**新增依赖**（依 `openspec/config.yaml` 的 YAGNI 条款逐项说明理由）：

- `element-plus`：本变更的核心目标物。选型依据为需求方在四个维度（AI 生成质量、
  源码容易更改、复杂场景表现、国内适配程度）上的打分比较，过程与实测数据见 `design.md`。
- `@element-plus/icons-vue`：与组件库配套的官方图标集，独立包发布，且**本就是
  element-plus 自身的直接依赖**。声明它使页面写图标时有与组件库同一套、版本对齐的图标可用；
  **不全局注册**——全局注册全部图标实测使产物增大 165,967 B（+53.7%），而在没有页面
  使用图标时这部分全是死代码（依据见 `design.md` 决策 3）。
- `unplugin-vue-components` + `unplugin-auto-import`（开发期依赖）：实现按需引入。
  不使用它们就必须全量注册组件，产物会纳入全部组件样式与代码；这两个插件是 Element Plus
  官方文档推荐的按需引入方案。
- **不引入**：`vue-router`、`Pinia`、CSS 框架（Tailwind / UnoCSS）、前端测试框架。
  其触发条件不变（见 `frontend-stack-and-toolchain` 的 `design.md` 决策 5）。特别说明
  **不引入 CSS 框架**：Element Plus 自带完整的样式与设计变量体系，再叠加一层原子化
  CSS 框架会造成两套样式体系并存、覆盖优先级难以推理，与「源码容易更改」的目标相反。

**受影响的代码与目录**：

- `frontend/`（**独立仓库** `github.com/snzysnk/ChinaTravel-frontend`，**全部改动落在此仓库**）：
  - `frontend/package.json`：新增上述依赖。
  - `frontend/vite.config.ts`：挂载两个按需引入插件。**注意**：该文件当前已承载
    `BACKEND_PORT` 与 `DEV_SERVER_PORT` 两个常量，且 `frontend-toolchain` 规格规定
    「转发目标 SHALL 与权威来源一致」。新增插件配置**不得触碰**这两个常量。
  - `frontend/src/main.ts`：挂载 Element Plus 的中文语言包。
  - `frontend/src/views/DestinationHome.vue`：既有手写结构替换为组件库组件，行为不变。
  - `frontend/src/assets/`：设计变量覆盖位置；`page.css` 中与组件库职责重叠的
    手写样式（按钮、空态、错误提示）相应移除，避免两套样式并存。
  - **待定**：主题覆盖文件的确切路径（候选 `src/assets/theme.css` 或
    `src/styles/element.css`），在 `tasks.md` 中给出依据后确定，不在此处编造。
- `backend/`：**无改动**。组件库替换不触及接口契约、CORS 白名单或后端配置。
- `Makefile`（workspace 仓库）：**无改动**。
- workspace 仓库：仅 `openspec/` 下本变更的规划产物，以及 `frontend` submodule 指针更新。

**对既有验收链路的影响**：`DestinationHome.vue` 当前是「前端 → 后端接口 → 领域层」链路的
人工验收载体。组件替换后该链路必须仍然完整——验收标准是替换前后页面行为逐项一致
（健康状态三态、列表三态、空集合、失败态、重新加载），而非「看起来更好看」。
