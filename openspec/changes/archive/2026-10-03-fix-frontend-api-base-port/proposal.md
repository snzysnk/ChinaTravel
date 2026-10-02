## Why

前端页面与后端之间存在一处**未被任何规格约束**的耦合：页面里硬编码了一个后端地址，
而这个地址与后端实际监听的端口不一致，导致页面的服务连通检测必然失败。

现状（本次变更前）：

| 位置 | 取值 |
|------|------|
| `frontend/index.html` 的 `API_BASE` | `http://localhost:8080` |
| `backend/configs/config.yaml` 的 `server.port` | `18080` |
| `Makefile` 的 `BACKEND_PORT` | `8080`（注释自述"仅用于提示信息"） |

三处对同一个事实各说各话，且没有任何一处是权威。浏览器打开页面后，
健康检查与列表请求都会连向 8080 而失败，页面停在"服务不可用"。

根因不是"端口写错了"，而是**这条跨仓库的取值约定从未被规格化**，
因此没有任何机制在它漂移时发出信号。本次变更既要修正当前取值，
更要把"前端从何处得知后端地址"这条约定写成规格。

## What Changes

- 前端页面调用的后端地址由 `8080` 改为后端**实际监听的端口** `18080`，
  使页面在默认配置下端到端可用。
- 新增一条能力规格，明确"前端后端地址的唯一权威来源"这一约定：
  后端监听端口以 `backend/configs/config.yaml` 的 `server.port` 为准，
  前端 `API_BASE` 与该 `Makefile` 的提示值都 SHALL 与之保持一致。
- `Makefile` 的 `BACKEND_PORT` 由 `8080` 改为 `18080`，使其提示信息不再误导。

**BREAKING**：无。这是修正一处既有的不一致，HTTP 接口、响应信封、
配置项名与后端行为均不变，前端页面结构也不变。

## Capabilities

### New Capabilities

- 无。本变更的性质是**为既有行为补一条缺失的规格**，而不是引入新的行为类别。
  相关行为在概念上仍属于"前端对接后端接口"，因此规格补进既有能力，
  见下方 Modified Capabilities。

### Modified Capabilities

- `frontend-api-integration`: 新增一条 requirement，规定前端后端地址的来源约定——
  该地址 SHALL 与后端配置中的监听端口保持一致，并指出后端配置文件是该事实的权威来源。
  这是补一条**既有行为缺失的约束**，不是改变既有 requirement 的语义；
  现有 5 条 requirement 全部不变。

## Impact

- **前端仓库**（`snzysnk/ChinaTravel-frontend`）：`index.html` 一处常量——
  `const API_BASE = 'http://localhost:8080';` 改为 `18080`，注释同步说明权威来源。
- **workspace 仓库**（`snzysnk/ChinaTravel`）：`Makefile` 的 `BACKEND_PORT` 由 `8080` 改为 `18080`。
- **规格**：`openspec/specs/frontend-api-integration/spec.md` 新增 1 条 requirement。
- **不涉及**：`backend/` 下任何文件。后端配置的取值 `18080` 是正确的，
  本次是让前端与编排向它看齐，而非反过来。后端仓库不产生提交。
- **跨仓库操作提示**：本次变更同时触及前端仓库与 workspace 仓库，
  提交必须分别落在各自仓库；workspace 仓库还需更新 submodule 指针
  （见 `workspace-repo-topology` 规格的"只改后端并提交"场景的同类要求）。
