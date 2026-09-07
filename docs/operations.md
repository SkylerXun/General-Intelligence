# 运维与迁移

本项目只运行 New API、PostgreSQL、Redis 和 Caddy。生产对外只开放 Caddy 的
`80/443`，应用、数据库和 Redis 不发布原始端口。

## 迁移旧 New API

迁移前先暂停旧 New API 写入，确认旧 PostgreSQL 和 Redis 可用。在旧服务器执行：

```bash
bash scripts/backup.sh prod
```

如果旧服务器不是本项目的 Compose 项目，而是旧 WSL 容器，使用只读备份助手：

```bash
bash scripts/backup-existing-wsl.sh --confirm-existing-runtime-backup /secure/backups
```

它只检查 `new-api`、`postgres`、`redis`，不会读取或打包已废弃服务的数据。

备份目录包含 `newapi.dump`、`redis.rdb`、`newapi_data.tar.gz`、`SHA256SUMS` 和
元数据。只需把这些文件加密传到新服务器。旧服务器的环境文件也要单独保管，因为
`NEWAPI_SESSION_SECRET` 变化会使现有会话失效。

新服务器完成 Docker、仓库和 `env/production.env` 配置后启动 PostgreSQL 和 Redis，
再恢复 New API 数据：

```bash
bash scripts/restore.sh prod /secure/backup/prod-YYYYMMDDTHHMMSSZ \
  --yes-i-understand-this-overwrites-gateway-data
bash scripts/smoke-test.sh prod
```

恢复脚本会重建 `newapi` 数据库并恢复 Redis 快照，随后启动服务。先在新服务器用
原域名以外的临时入口验收登录、用户、余额、渠道、模型和消费记录，再切换 DNS；
确认流量正常后再下线旧服务器。迁移期间必须保留原备份和旧环境文件，直到完成一次
回滚演练。

## 日常操作

定期运行 `scripts/backup.sh prod`，将输出目录放进加密异地存储。恢复是覆盖操作，
只应先在隔离环境演练。更新 New API 时使用明确的提交或 tag：

```bash
bash scripts/update-upstream.sh new-api <commit-or-tag>
git diff --submodule=log
```

上线前检查 HTTPS、管理员 MFA、注册和邮箱验证、余额不足拒绝、模型调用、Redis
持久化以及 PostgreSQL 备份恢复。
