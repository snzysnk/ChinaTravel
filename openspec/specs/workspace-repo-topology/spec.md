## Purpose

定义 workspace 仓库的拓扑契约：仓库根只承载仓库级文件，前端与后端各自作为独立 Git 仓库以 submodule 形式挂载，使两端的版本演进互相独立，同时保证克隆 workspace 即得到可运行的完整工作区。

## Requirements

### Requirement: workspace 仓库根 SHALL 只承载仓库级文件

workspace 仓库 SHALL 只直接跟踪作用于整个项目的文件与目录，包括任务编排文件、协作者与 AI 助手共用的约定文件、项目说明、忽略规则、规格与变更管理目录。前端与后端的源码 SHALL NOT 作为普通文件被 workspace 仓库跟踪。

#### Scenario: 查看 workspace 仓库跟踪的文件

- **WHEN** 查看 workspace 仓库的跟踪文件清单
- **THEN** 其中只包含仓库级文件，前端与后端目录以 submodule 指针（gitlink）形式出现，而非普通文件条目

#### Scenario: 新增一个仅属于某一端的文件

- **WHEN** 需要新增一个仅作用于前端或后端的文件
- **THEN** 该文件提交到对应的端仓库，workspace 仓库不产生该文件的普通条目

### Requirement: 前后端 SHALL 各自作为独立 Git 仓库存在并可独立提交

前端与后端 SHALL 各自拥有独立的 Git 仓库与远端，任一端的提交、分支与发布 SHALL NOT 要求另一端的仓库发生变化。两个端仓库的地址 SHALL 记录在 workspace 仓库的 submodule 配置中。

#### Scenario: 只改后端并提交

- **WHEN** 开发者修改后端代码并在后端仓库中提交与推送
- **THEN** 该提交落在后端仓库，workspace 仓库的变更仅限于 submodule 指针的更新

#### Scenario: 端的仓库描述与 workspace 记录一致

- **WHEN** 核对 submodule 配置中记录的地址与挂载点
- **THEN** 每个挂载点恰好对应一个端仓库地址，且地址指向实际存在的仓库

### Requirement: submodule 挂载点 SHALL 沿用前后端平级的顶层目录名

两个端仓库 SHALL 分别挂载在 workspace 仓库根的 `backend/` 与 `frontend/`，二者 SHALL 位于同一层级且 SHALL NOT 互相嵌套。挂载点名称 SHALL 与既有布局约定保持一致，使既有编排文件与文档中的路径引用无需改动。

#### Scenario: 从目录树辨认挂载点

- **WHEN** 查看 workspace 仓库根目录
- **THEN** `backend/` 与 `frontend/` 同时存在、互为平级，且各自是 submodule 挂载点

#### Scenario: 既有编排文件的路径引用仍成立

- **WHEN** 编排文件以 `backend/` 或 `frontend/` 作为工作目录执行命令
- **THEN** 该路径解析到对应的 submodule 挂载点，命令正常执行

### Requirement: 克隆 workspace SHALL 足以获得可运行的完整工作区

workspace 仓库 SHALL 使初次克隆的开发者只需一步补充操作即可获得完整的、可运行的前后端工作区，SHALL NOT 要求逐个手工克隆端仓库。仓库级说明文件 SHALL 记载该操作方式。

#### Scenario: 首次克隆并初始化

- **WHEN** 开发者克隆 workspace 仓库后执行 submodule 初始化与更新
- **THEN** 两个挂载点被填充为端仓库对应提交的内容，工作区完整

#### Scenario: 说明文件记载初始化方式

- **WHEN** 开发者阅读 workspace 仓库的说明文件
- **THEN** 其中给出了克隆后获得完整工作区所需的命令
