# Gateway

## Multi-device checkout

This repository keeps `new-api` and `sub2api` as pinned Git submodules. The root
repository stores their commit pointers; their source files are fetched from the
URLs in `.gitmodules` during recursive checkout.

Clone with submodules enabled:

```powershell
git clone --recurse-submodules https://github.com/SkylerXun/General-Intelligence.git gateway
```

If the root repository was already cloned and those directories are empty:

```powershell
git -C gateway submodule update --init --recursive
```

Do not commit runtime secrets. `env/*.env` is intentionally ignored.

New API 是客户门户、客户 API、余额账本和消费日志；Sub2API 是仅供内部调用的
账号池。两个上游以固定提交的 Git submodule 纳入本仓库，业务定制优先使用后台
配置，补丁记录在 `patches/`，不直接把旧工作目录的未提交改动带进来。

## 本地完整体验

Docker Engine 运行在 WSL Ubuntu 时，从 PowerShell 执行：

```powershell
wsl -d Ubuntu -- bash /mnt/d/gateway/scripts/init-local.sh
wsl -d Ubuntu -- bash /mnt/d/gateway/scripts/local-up.sh
wsl -d Ubuntu -- bash /mnt/d/gateway/scripts/smoke-test.sh local
```

本地入口为 New API `http://localhost:3100` 和仅供管理员验收的 Sub2API
`http://localhost:8180`。新栈使用独立 Compose 项目、独立卷和不同端口，不会
改动当前运行中的旧容器。首次构建需要访问上游镜像和依赖源。

停止本地栈但保留数据卷：

```powershell
wsl -d Ubuntu -- bash /mnt/d/gateway/scripts/local-down.sh
```

不要把 `local-down.sh -v` 用于需要保留测试数据的环境。

在已验证当前镜像与固定子模块提交一致、且仅需重新构建 Sub2API 时，可使用
`GATEWAY_SKIP_NEWAPI_BUILD=true` 临时复用现有 New API 镜像；常规验收仍应执行
完整构建。

迁移后的本地 demo 可复用已有 `postgres:18-alpine`，生产 Compose 仍固定使用
`postgres:16-alpine`。PostgreSQL 18 使用其新的父级数据目录挂载；上线前必须在
生产版本完成一次完整验收。

旧 WSL 运行时的只读备份命令见 [operations.md](docs/operations.md)；不要在当前
WSL 文件系统报 I/O 错误时执行任何 Docker 写入、清理或重启操作。

## 配置与迁移

- `env/local.env` 和 `env/production.env` 含有密码和密钥，已被 Git 忽略。
- New API 的品牌、Turnstile、SMTP、注册策略、模型/渠道/价格和人工余额调整在
  后台设置；Sub2API 的账号使用其支持的 UI/API 导入。具体步骤见
  [operations.md](docs/operations.md)。
- 关于账号池、路由、计费和失败边界见
  [routing-and-pricing.md](docs/routing-and-pricing.md)。
- 人工充值限制与审计流程见
  [manual-topup-runbook.md](docs/manual-topup-runbook.md)。

生产部署使用同一个仓库加 `docker/compose.prod.yaml`，只由 Caddy 发布 HTTPS。
生产前必须填写域名、SMTP、Turnstile、管理员出口 IP、备案和合规所需信息，不能
使用示例占位符上线。
