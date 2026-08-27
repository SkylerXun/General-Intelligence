# 本地配置与上云 Checklist

> 配套文档：[operations.md](docs/operations.md)、[routing-and-pricing.md](docs/routing-and-pricing.md)、[manual-topup-runbook.md](docs/manual-topup-runbook.md)

## 一、当前本地状态（已跑通）

| 服务 | 地址 | 状态 |
|---|---|---|
| New API（客户门户/计费） | `http://localhost:3100` | ✅ healthy |
| Sub2API（内部账号池） | `http://localhost:8180` | ✅ healthy |
| PostgreSQL | `127.0.0.1:54329` | ✅ healthy |
| Redis | 内部（不对外） | ✅ healthy |

**Sub2API 管理员登录：**
- 账号：`admin@sub2api.local`
- 密码：见 `env/local.env` 的 `SUB2API_ADMIN_PASSWORD`（该文件 chmod 600，仅本机可读）

---

## 二、本地配置流程（按顺序做）

### Step 1 · New API 初始管理员（浏览器 `http://localhost:3100`）
首次访问引导创建初始管理员。完成后：
- 设置系统名、Logo、页脚、服务条款、隐私说明、客服联系方式
- 管理员启用 MFA

### Step 2 · 邮箱验证 + 注册策略
- 配置 SMTP，发送并**实际验收**邮箱验证邮件
- 开启公开注册、密码注册、邮箱验证
- 未配置 SMTP 前，注册功能不可用

### Step 3 · Cloudflare Turnstile
- 配置站点密钥/密钥，开启验证后用**真实浏览器**测试注册

### Step 4 · 用户余额策略
- 新用户默认余额设为 **0**
- **关闭**任何自动赠送可消费额度

### Step 5 · Sub2API 内部配置（浏览器 `http://localhost:8180`）
- 建立管理员 MFA
- 创建**内部服务用户** + 专用 API Key（最小权限、可撤销，**不分发给客户**）
- 建立账号组、并发策略、冷却策略
- 通过 Sub2API 支持的 UI/API **导入账号**（敏感凭证，不提交/不截图）
  - 若导出格式不匹配，逐项导入；**绝不直接写 PostgreSQL 或 Redis**

### Step 6 · New API 渠道
- 建立指向 `http://sub2api:8080` 的**内部渠道**，使用 Step 5 的专用 Key
- 官方 API Key 类上游另外建立直接渠道
- `RetryTimes` 第一期保持 **0**（禁止自动跨渠道重试）

### Step 7 · 模型/价格/路由
按 [routing-and-pricing.md](docs/routing-and-pricing.md)：
- 为每个可售模型：先测连通 → 定公开别名 → 建映射（API类型/真实模型名/渠道/最大输出）→ 定价（分计量项）→ 测试（正常/流式/余额不足/4xx/429/5xx/中断）→ 上架
- 新渠道**先测试后上架**

---

## 三、上云 Checklist

### A. 准备（大陆 Linux VPS）
- [ ] 安装 Docker Engine + Compose 插件
- [ ] 按固定提交检出整个 Git 仓库，`git submodule update --init --recursive`
- [ ] 从 `env/production.env.example` 创建未跟踪的 `env/production.env`，**全部占位符换成安全随机值**，`chmod 600`

### B. 生产环境配置项
- [ ] 填 `APP_DOMAIN`、`ADMIN_DOMAIN`（**必须与主域名不同**，建议 DNS-only，不经过 CDN 代理后放行）
- [ ] Caddy 邮箱（用于自动签发 TLS 证书）
- [ ] 管理员固定出口 IP/CIDR
- [ ] 独占 Docker 子网
- [ ] `NEWAPI_TRUSTED_PROXIES` 设为 `CADDY_INTERNAL_IP`（只信任自己 Caddy 容器的转发头）

### C. 合规（大陆上线必需）
- [ ] 域名 ICP 备案
- [ ] 适用隐私/数据/支付合规要求

### D. 部署
```bash
cd /srv/gateway
docker compose --project-name gateway --env-file env/production.env \
  -f docker/compose.yaml -f docker/compose.prod.yaml up -d --build
bash scripts/smoke-test.sh prod
```

### E. 验收（对应 operations.md 发布清单）
- [ ] 空目录 + 固定提交 + 环境文件可重建新栈
- [ ] Sub2API 账号导入、失效处理、限流、冷却、凭证保护正常
- [ ] New API 经 Sub2API 可调用至少一个已授权账号池模型 + 一个官方 API Key 模型
- [ ] 注册经邮箱 + Turnstile 验证；初始余额 0；用户能创建/禁用自己 API Key
- [ ] 余额不足拒绝；成功请求按公开价结算；失败/断流/异常无双扣或重复退款
- [ ] 人工充值有外部流水号 + 审计记录；无个人二维码自动到账
- [ ] Redis AOF 恢复、`evicted_keys=0`、PostgreSQL 还原演练通过
- [ ] 外网端口扫描仅见 Caddy 的 `80/443`，应用/数据库/Redis 原始端口不可达

### F. 上线初期
- [ ] 仅开放已验证模型 + 低额度用户

---

## 四、关键原则（务必遵守）

1. **客户余额只以 New API 为权威**；Sub2API 只做账号池，绝不为客户加余额
2. **账号凭证只留 Sub2API** 受保护数据卷，不进渠道备注/截图/Git
3. **导入文件是敏感凭证**，不提交、不截图、不粘贴到日志
4. **禁止用 SQL/Redis/开发者工具/Sub2API 直接改余额**
5. 上游更新用 `scripts/update-upstream.sh <name> <commit|tag>`，**不自动跟随 main/latest**
6. 定期 `scripts/backup.sh local|prod`，备份立即转加密异地存储
