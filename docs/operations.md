# 运维与验收

## 运行边界

- 本地项目在 `D:\gateway`，Docker Engine 在 WSL Ubuntu。当前旧栈不属于本
  项目，也不会被本项目脚本停止、修改或复用。
- 本地 Compose 项目名固定为 `gateway-local`，端口只绑定 `127.0.0.1:3100`
  和 `127.0.0.1:8180`。生产项目名为 `gateway`，只由 Caddy 发布 `80/443`。
- PostgreSQL、Redis、New API、Sub2API 不发布原始主机端口。生产防火墙仅允许
  对外 `80/443`；SSH 和 Sub2API 管理应使用 Tailscale 等私有管理网络。
- Redis 的 `1gb` 是最大内存上限而不是预分配。约 100 个用户的初期单机可用一
  个 Redis 实例；观察 `used_memory`、`evicted_keys`、延迟和连接数后再扩容。
  `noeviction` 下 `evicted_keys` 必须始终为 0，内存不足会显式拒绝写入而不是
  静默淘汰状态。

## 初次本地启动

从 PowerShell 调用 WSL：

```powershell
wsl -d Ubuntu -- bash /mnt/d/gateway/scripts/init-local.sh
wsl -d Ubuntu -- bash /mnt/d/gateway/scripts/local-up.sh
wsl -d Ubuntu -- bash /mnt/d/gateway/scripts/smoke-test.sh local
```

首次 `local-up.sh` 从固定子模块提交构建两个镜像，时间和网络消耗都明显。它
不会停止当前 6 个容器；已知 WSL 目前约 3.8 GB 内存，若旧栈也在运行，构建或
新栈启动可能因资源不足失败。此时保留旧栈不动，先释放 WSL 可用内存或在另一
台测试机执行，而不是修改本项目为复用旧数据库。

基础连通性通过后，依次在后台完成：

1. New API 初始管理员设置，品牌、条款、客服和管理员 MFA。
2. 配置 SMTP，发送并实际验收邮箱验证；开启公开注册、密码注册和邮箱验证。
3. 配置 Cloudflare Turnstile 站点密钥/密钥，开启验证后用真实浏览器测试注册。
4. 设置新用户默认余额为 0，关闭任何可消费的自动赠送额度。
5. 在 Sub2API 建立管理员 MFA、内部服务用户、专用 API Key、账号组、并发和
   冷却策略；固定 JWT/TOTP 密钥已经由环境文件提供，重启不能更换它们。
6. 通过 Sub2API 支持的 UI 或 API 导入账号。若导出格式不匹配，逐项导入；绝
   不直接写 PostgreSQL 或 Redis。导入文件是敏感凭证，不能提交、截图或粘贴到
   日志中。
7. 在 New API 建立指向 `http://sub2api:8080` 的内部渠道，并使用该内部服务
   用户的专用 Key；官方 API Key 类上游另外建立直接渠道。
8. 按 [路由与计费边界](routing-and-pricing.md) 配置模型映射、售价、分组倍率
   和最大输出限制；新渠道先测试后上架。

## 旧栈与账号迁移

旧 `D:\new-api` 的未提交改动必须先审计，不直接带入本项目。新主仓库只记录
两个官方上游子模块的固定提交，定制先放入 `patches/` 并有可回滚说明。

旧 WSL 运行环境只保留 Sub2API 账号资产：先用其支持的导出路径制作加密备份，
并保留旧 Compose 配置、PostgreSQL 与 Redis 卷备份。旧 New API 的用户、余额、
订单、消费和 Redis 状态不迁入新栈。现有账号导出文件属于敏感材料，只能由
有权限管理员在导入时读取，不能将其复制到 Git 仓库或直接写数据库。

在 WSL 文件系统健康、旧 6 个容器仍可访问时，可执行一次以下命令以只读方式
导出其 PostgreSQL 逻辑备份和所有命名卷；脚本不会停止旧容器，但输出含有敏感
数据，必须立即转入加密异地存储。旧 Compose 文件须由管理员从其原位置单独保留。

```bash
bash scripts/backup-existing-wsl.sh --confirm-existing-runtime-backup
```

## 生产部署

1. 在大陆 Linux VPS 安装 Docker Engine 与 Compose 插件，将整个 Git 仓库按
   固定提交检出，初始化子模块。
2. 从 `env/production.env.example` 创建未跟踪的 `env/production.env`，用安全
   随机值替换全部占位符，并设置为 `chmod 600`。
3. 填写实际 `APP_DOMAIN`、Caddy 邮箱和独占 Docker 子网。仅为 `APP_DOMAIN`
   创建公网 DNS 记录；Sub2API 仅监听 `127.0.0.1:8180`，不创建管理域名或公网
   防火墙规则。
4. 将 `NEWAPI_TRUSTED_PROXIES` 设为 `CADDY_INTERNAL_IP`。这使 New API 只信任
   自己的 Caddy 容器传来的转发头，而不是所有私有网段。
5. 完成域名解析、ICP备案及适用的隐私/数据/支付合规要求后执行：

```bash
cd /srv/gateway
docker compose --project-name gateway --env-file env/production.env \
  -f docker/compose.yaml -f docker/compose.prod.yaml up -d --build
bash scripts/smoke-test.sh prod
```

6. 在 VPS 与管理员设备登录同一 Tailscale 网络，执行 `tailscale serve --https=443
   http://127.0.0.1:8180`，仅通过其私有 HTTPS 地址验收 Sub2API 管理端。再验收
   公网 HTTPS、New API 门户、注册、邮箱、Turnstile、人工充值、余额不足拒绝、
   至少一个 Sub2API 模型和一个官方 API Key 模型。正式上线初期仅开放已验证模型
   和低额度用户。

## 备份、恢复与更新

定期执行 `scripts/backup.sh local` 或 `scripts/backup.sh prod`。备份包含两个
PostgreSQL 数据库和 Redis RDB 快照，目录应立即放入加密的异地存储；生产密钥
环境文件另行以受限方式备份。恢复脚本要求精确确认参数，并会停止本项目的应用
服务、重建两个数据库和覆盖 Redis 状态：

```bash
bash scripts/restore.sh prod /secure/backup/prod-YYYYMMDDTHHMMSSZ \
  --yes-i-understand-this-overwrites-gateway-data
```

恢复只应先在隔离环境演练。验证 PostgreSQL 备份的最低要求是：对独立测试栈
恢复后，登录后台、查看模型/渠道且不泄漏账号凭证；Redis 重启后 AOF 正常恢复，
并检查 `evicted_keys=0`。

上游更新从不自动跟随 `main` 或 `latest`。使用明确提交或 tag：

```bash
bash scripts/update-upstream.sh new-api <commit-or-tag>
git diff --submodule=log
```

在独立环境完成冒烟、计费、失败结算和回滚演练后，才提交新的子模块指针并部署。
`docker/Dockerfile.new-api` 是为中国大陆网络提供 Go 模块代理的构建覆盖层，不
改变运行时业务代码；每次更新 New API 子模块时都要与其上游 Dockerfile 比较并
复审该覆盖层。`GO_PROXY` 与 `GO_SUMDB` 必须使用组织批准的模块源。

## 发布验收清单

- 空目录、固定根仓库提交和环境文件可以重建新栈。
- Sub2API 账号导入、失效处理、限流、冷却和凭证保护正常。
- New API 经 Sub2API 可调用至少一个已授权账号池模型，并可调用至少一个官方
  API Key 模型。
- 注册经邮箱与 Turnstile 验证；用户初始余额为 0，能创建和禁用自己的 API Key。
- 余额不足请求被拒绝；成功请求按公开模型价格结算；失败、断流和异常不发生双扣
  或重复退款。
- 人工充值有外部流水号和审计记录；没有个人二维码自动到账路径。
- Redis AOF 恢复、`evicted_keys=0`、PostgreSQL 还原演练均通过。
- 外网端口扫描仅见 Caddy 的 `80/443`，应用、数据库和 Redis 原始端口不可达。
