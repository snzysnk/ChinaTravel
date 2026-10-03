# ChinaTravel 开发任务编排。
#
# 约定：前三项是日常开发最常用的入口，放在最前面；
# 端口与 configs/config.yaml 中的 cors.allow_origins 白名单必须对应，
# 改了这里记得同步改配置，否则浏览器会拦掉请求。

# 前端开发服务器端口（Vite）。必须出现在 configs/config.yaml 的 cors.allow_origins 里。
# 5174 是前端唯一端口；旧版零构建静态页面的 5173 已随前端工程化退役。
FRONTEND_PORT ?= 5174

# 后端监听端口，仅用于提示信息（真实端口由配置与环境变量决定）。
# 权威来源是 backend/configs/config.yaml 的 server.port，本值必须与之一致；
# 改了后端配置记得同步这里，以及前端页面 index.html 中的 API_BASE。
BACKEND_PORT ?= 18080

# 顶层目录名。前后端各自占一个平级目录，见 openspec/specs/backend-project-layout/。
# 显式声明而非在各目标里硬编码 "backend"/"frontend"，是为了让"后端根在哪"这件事
# 在编排层唯一可见——后端命令必须在该目录下执行，否则读不到配置文件（见下方 run-backend）。
BACKEND_DIR := backend
FRONTEND_DIR := frontend

# 构建产物路径（.gitignore 已忽略 /backend/bin/）。
# 注意：该值相对 $(BACKEND_DIR)，不是相对仓库根——build 目标会先 cd 进
# $(BACKEND_DIR) 再使用它，写成 "$(BACKEND_DIR)/bin/server" 会得到嵌套的
# backend/backend/bin/server。
BIN := bin/server

# 默认目标：列出全部可用命令。用 .DEFAULT_GOAL 显式声明，
# 避免"第一个目标即默认目标"的隐式规则在调整顺序时被意外破坏。
.DEFAULT_GOAL := help

.PHONY: help run-backend serve-frontend test build fmt typecheck-frontend

## help: 列出全部可用命令
help:
	@echo "ChinaTravel 可用命令："
	@echo ""
	@echo "  make run-backend      在 $(BACKEND_DIR)/ 下启动后端（go run ./cmd/server/），监听 $(BACKEND_PORT)（可通过 APP_SERVER_PORT 覆盖）"
	@echo "  make serve-frontend   在 $(FRONTEND_DIR)/ 下启动前端开发服务器，监听 $(FRONTEND_PORT)，并把 /api 转发到后端"
	@echo "  make test             在 $(BACKEND_DIR)/ 下运行全部 Go 测试（go test ./...）"
	@echo "  make build            在 $(BACKEND_DIR)/ 下构建后端可执行文件到 $(BACKEND_DIR)/$(BIN)"
	@echo "  make fmt              在 $(BACKEND_DIR)/ 下检查 Go 代码格式（gofmt -l .），有未格式化文件时列出并失败"
	@echo "  make typecheck-frontend  在 $(FRONTEND_DIR)/ 下检查前端 TypeScript 类型（vue-tsc --noEmit）"
	@echo ""
	@echo "典型用法：终端 A 执行 make run-backend，终端 B 执行 make serve-frontend，"
	@echo "然后浏览器访问 http://localhost:$(FRONTEND_PORT) 做端到端验收。"
	@echo ""
	@echo "首次使用前端前需先装依赖：cd $(FRONTEND_DIR) && npm install。"
	@echo ""
	@echo "注意：后端命令必须以后端目录为工作目录执行（本 Makefile 已通过 cd $(BACKEND_DIR) 保证）。"
	@echo "直接从仓库根执行 go run/test/build 会导致配置文件读不到、静默回落到内置默认值。"

## run-backend: 启动后端服务（前台运行，Ctrl-C 优雅关闭）
# 必须先 cd 进 $(BACKEND_DIR)：配置文件的默认路径 "configs/config.yaml" 相对
# 进程工作目录解析，而文件读不到时服务静默回落到内置默认值、不报任何错。
run-backend:
	cd $(BACKEND_DIR) && go run ./cmd/server/

## serve-frontend: 启动前端开发服务器（前台运行，Ctrl-C 停止）
# 进入 $(FRONTEND_DIR) 执行前端仓库自身的 npm 脚本，本层不复制其命令细节——
# 具体命令由 frontend/package.json 的 scripts 定义（当前为 vite）。
#
# 开发服务器承担两件事：提供带热更新的页面，以及把 /api 转发到后端
# （见 frontend/vite.config.ts）。因此前端不再需要静态服务，也不持有后端端口。
# 首次使用需先装依赖：cd $(FRONTEND_DIR) && npm install。
serve-frontend:
	cd $(FRONTEND_DIR) && npm run dev

## typecheck-frontend: 检查前端类型（与后端 fmt 同属"只检查不改写"的目标）
typecheck-frontend:
	cd $(FRONTEND_DIR) && npm run typecheck

## test: 运行全部 Go 测试
test:
	cd $(BACKEND_DIR) && go test ./...

## build: 构建后端可执行文件
build:
	cd $(BACKEND_DIR) && go build -o $(BIN) ./cmd/server/

## fmt: 检查格式，输出未格式化的文件列表
# 刻意用 -l 而不是 -w：本目标只做检查，不悄悄改写工作区。
fmt:
	@cd $(BACKEND_DIR) && unformatted=$$(gofmt -l .); \
	if [ -n "$$unformatted" ]; then \
		echo "以下文件未格式化，请执行 gofmt -w："; \
		echo "$$unformatted"; \
		exit 1; \
	fi; \
	echo "全部 Go 文件格式正确。"
