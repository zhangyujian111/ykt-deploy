# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-09-10

### 🚀 Java → Go 全面替换 + 单端口边缘网关

将旧版 Java 服务（ykt-admin/xiaozhi-dialogue/xiaozhi-server/xiaozhi-web 4 个
Tomcat 容器 + 老 nginx）替换为 Go 服务栈，统一通过单一 edge-nginx 8088 端口对外。

### Changed

#### 运行时栈
- **ykt-admin** (Spring/Java) → **ykt-admin-go** (Go/Gin)
- **xiaozhi-esp32-server-java** → **xiaozhi-server-go** (Go/Gin)
- **aisaas 内部 SPA** → **ykt-aisaas-portal** (Vue 3 + Element Plus)
- **老 nginx (Java-side)** → **edge-nginx** (nginx:alpine，唯一对外 8088)
- **muliti-toy** (前端 + 部分 API 转发) 保留，承担 `/api/v1` 与 `/api` 转发

#### 部署编排
- 所有容器端口改 `expose:`，仅 edge-nginx `ports: "8088:8088"`
- 加 `dns: 127.0.0.11,223.5.5.5` 修复 Go 容器内 DNS 解析（Ubuntu systemd-resolved 注入 127.0.0.53）
- 禁用并归档旧 cron `/opt/update.sh`（每 5 分钟重启 Java 容器抢占端口），归档到 `/tmp/update.sh.archived.*`
- 新备份脚本 `/opt/backup.sh`：`0 3 * * *` 跑 mysql dump + docker volumes + configs，保留 7 天

#### 路由表（edge.conf）
| 路径 | 目标 |
| --- | --- |
| `/` | muliti-toy (SPA + /api/v1 + /api) |
| `/api/device/ota[/...]` | xiaozhi-server:8080 (ESP32 OTA) |
| `/ws/` | xiaozhi-server:8080 (WebSocket dialogue) |
| `/api/xz/...` | xiaozhi-server:8080 (xiaozhi-admin SPA API) |
| `/api/aisaas/...` | ykt-aisaas:8190 (剥前缀) |
| `/internal/...` | ykt-aisaas:8190 (internal token) |
| `/admin/`, `/admin/assets/` | ykt-admin-console-web (sub_filter + SPA fallback) |
| `/portal/`, `/portal/assets/` | ykt-aisaas-portal-web |
| `/xiaozhi-admin/`, `/xiaozhi-admin/assets/` | ykt-xiaozhi-admin-web |

- sub_filter 把 SPA index.html 的 `/assets/` 重写到 `/<section>/assets/`，避免 JS/CSS 落错上游
- named locations (`@xxx_spa_fallback`) 提供 SPA history 模式回退

### Added

#### 数据迁移
- 老 MySQL 全库 dump → 单库 `ykt`（mysql awk/sed 合并 `ykt_admin` + `xiaozhi` → `ykt`，79 张表）
- ykt_sys_user admin 密码重置为 `admin123`（UI 默认值，bcrypt cost 10）

#### 健康检查
- 11 个容器全部加 healthcheck（wget 探活）
- 之前 mysql/redis/postgres 已有，其他 8 个补齐
- 现在 `docker ps` 全部显示 `(healthy)`

#### 备份
- `/opt/backup.sh` 修复清理 bug：`find \( -name 'ykt_*' -o -name 'dump_*' \)` 同时清理老 cron 的全库 dump
- 历史 `dump_20260903..20260910.sql.gz` 保留在 `/data/backup/`

### Fixed
- **SPA 路径前缀**：admin/portal/xiaozhi-admin 三个 Vue SPA 加 `createWebHistory('/admin/')` 等 base path，避免登录后路由跳出 `/admin/` 前缀
- **aisaas 内网 IP 鉴权**：`internal API` 允许 RFC1918 私网（容器间互通）
- **edge.conf `default.conf.new` 孤儿文件**：旧 nginx 容器内残留文件被 include，干扰 location 匹配；清掉后 SPA 静态资源才能正确返回

### Security
- JWT keypair (`/opt/ykt-deploy/keys/aisaas/jwt_{private,public}.pem`) 挂载到 ykt-aisaas 容器 `/app/keys/`
- bcrypt cost 10 (ykt-admin-go `bcrypt.DefaultCost`)

### Verified
- `/admin/`、`/portal/`、`/xiaozhi-admin/` 三个 SPA 都渲染正常
- `POST /api/login admin/admin123` → 200 + JWT
- `/api/xz/healthz` → 200
- `/internal/api/v1/models` → 200 (with X-Internal-Token)
- 内存 1.5G / 7.1G（21%），磁盘 32G / 99G（34%）

## [1.0.0] - 2026-09-03

### 🎉 首个生产就绪版本

This is the first production-ready release of the YKT IoT AI Platform with full V2 architecture redesign. After 6 iterative development cycles (V0, V3, V4, V5, V6), the system is now enterprise-grade with:

- ✅ Multi-tenant SaaS architecture
- ✅ Production-grade observability (OTel + Prometheus + Grafana)
- ✅ Progressive delivery (Argo Rollouts + KEDA)
- ✅ Zero-trust security (mTLS + WebAuthn + MFA)
- ✅ AI-powered insights (XGBoost + A/B Testing)
- ✅ Chaos engineering (Chaos Mesh)
- ✅ Full internationalization (zh-CN / en-US / ja-JP)
- ✅ PWA support

### Added

#### Core Platform (V0)
- **ykt-aisaas**: Centralized AI gateway with 5 modules (memory/persona/session/MCP/OTA)
- **xiaozhi-server-go**: New IoT protocol server (replaces xiaozhi-esp32-server-golang)
- **ykt-admin**: Enhanced multi-tenant admin console
- **22 database migrations** covering all schema needs
- **~215 files / ~29500 LOC**

#### Audio & Vision (V3)
- Opus codec with 16kHz mono VoIP optimization
- Energy-based VAD (RMS threshold + hysteresis)
- WebRTC-style AEC (NLMS 256-tap + spectral subtraction + AGC)
- Vision understanding (OpenAI + Qwen-VL + GLM-4V)
- Streaming video via SSE + FFmpeg keyframe extraction
- **46 files / 5700 LOC**

#### Observability (V4-O)
- OTel three pillars: traces + metrics + logs
- 18 business metrics (HTTP/AI/Quota/DB/Outbox/WebSocket)
- Grafana dashboard (aisaas-dashboard.json)
- Anomaly detection rules engine (4 rule types + 3 severity + 3 channels)
- **55 files / 3000 LOC**

#### Enterprise (V4-R + V5-F + V6-P)
- SSO multi-tenant RBAC (SAML 2.0 + OIDC + super admin)
- MFA (TOTP + SMS + Email + 8 backup codes)
- WebAuthn / Passkeys (biometric auth)
- **43 files / 3000 LOC**

#### AI & ML (V5-M + V6-X)
- Isolation Forest anomaly detection (8 features, 100 trees)
- XGBoost upgrade (12 features, GPU, SHAP explainability)
- Hybrid detection chain (XGBoost → Isolation Forest → rules)
- A/B Testing platform (Z-test + sticky assignment + React SDK)
- **35 files / 3700 LOC**

#### Deployment & Reliability (V5-D + V5-E)
- Argo Rollouts (5-stage canary + auto-rollback)
- KEDA auto-scaling (4 triggers: QPS/latency/CPU/memory)
- Chaos Mesh (Pod/Network/Stress/Time chaos)
- NetworkPolicy + PodDisruptionBudget
- **22 files / 850 LOC**

#### Security & Compliance (V3 + V5-S + V6-P)
- mTLS service mesh (cert-manager + cert-rotator + CRL + SAN)
- OAuth 2.1 (PKCE mandatory + DPoT + PAR)
- SCIM v2 (11 endpoints for automated provisioning)
- AES-256-GCM + HKDF key derivation
- UUID v7 trace IDs

#### Frontend & UX (V4-T + V5-C)
- Playwright E2E (39 tests / 6 scenarios / 3 browsers)
- i18n (zh-CN / en-US / ja-JP)
- Dark mode (light/dark/auto with system preference)
- PWA (manifest + Service Worker + offline cache)
- **24 files / 1200 LOC**

### Changed

- **BREAKING**: `xiaozhi-esp32-server-golang` is no longer supported. Use `xiaozhi-server-go` instead.
- **BREAKING**: API authentication migrated to OAuth 2.1 (PKCE mandatory).
- **BREAKING**: Java admin backend `xiaozhi-esp32-server-java` archived.
- **BREAKING**: Memory storage migrated to MySQL graph (was Redis-only).
- Default log level changed from DEBUG to INFO.

### Deprecated

- Old API Key authentication (will be removed in 1.2.0)
- Basic Auth (will be removed in 2.0.0)
- SHA-256-based HKDF (replaced by HMAC-SHA256)

### Removed

- `xiaozhi-esp32-server-golang` codebase (archived)
- Mock frontend components (replaced by real API integration)
- TOTP-only MFA enforcement (now optional when WebAuthn available)

### Fixed

- Vision SSE stub replaced with real provider calls
- CameraVideoMsg type missing in protocol
- SAN domain validation in mTLS handshake
- OTel Tracer activation in observability
- Vision streaming response handling

### Security

- TLS 1.2+ enforced on all service-to-service communication
- mTLS with cert rotation every 90 days
- WebAuthn Origin validation prevents phishing
- Counter validation prevents replay attacks
- HKDF replaces SHA-256 for key derivation
- AES-256-GCM for all sensitive data at rest

### Documentation

- **DESIGN-V2-ARCHITECTURE.md** V1.0 (system architecture)
- **docs/V0-PROGRESS.md** (V2 implementation progress)
- **docs/V3-PROGRESS.md** (V3 features)
- **docs/V4-PROGRESS.md** (V4 features)
- **docs/V5-PROGRESS.md** (V5 features)
- **docs/V6-PROGRESS.md** (V6 features)
- **docs/RUNBOOK.md** + 6 sub-runbooks (operations)
- **docs/P3-CUTOVER-*.md** (cutover procedures)
- **docs/V5-GRADUAL-DEPLOY.md** (progressive delivery)
- **docs/V6-AI-TRACING.md** (distributed tracing)
- **~12000 lines of documentation**

### Statistics

- **Total files**: ~420
- **Total LOC**: ~46800
- **Total docs**: ~12000 LOC
- **Database migrations**: 22
- **Test coverage**: 39 E2E + 28 unit + 6 integration
- **Services**: 15 (3 app + 2 data + 4 observability + 1 viz + 1 ML + 3 GitOps + 1 elastic)
