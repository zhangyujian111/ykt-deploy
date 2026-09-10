# ykt-deploy

四个项目（`muliti-toy`、`xiaozhi-server-go`、`ykt-admin-go`、`ykt-aisaas`）的生产编排仓库。

## 仓库内容

```
ykt-deploy/
├── docker-compose.yml               # 4 业务服务 + MySQL + Redis + PostgreSQL
├── .env.example                     # 环境变量模板（拷贝为 .env 后填值）
├── deploy.sh                        # 一键部署
├── sync-migrations.sh               # 把 ykt-aisaas 的 SQL 同步到 mysql init 目录
├── configs/
│   ├── xiaozhi-server-go/config.yaml
│   ├── ykt-admin-go/config.yaml
│   └── ykt-aisaas/config.yaml
└── migrations/
    └── init/                        # 首次启动时 MySQL 自动执行
```

## 部署流程

### 1. 准备环境

```bash
# 在服务器上
cp .env.example .env
vi .env     # 填入 MYSQL_ROOT_PASSWORD / REDIS_PASSWORD / POSTGRES_PASSWORD / LLM_API_KEY / 阿里云 ACR 凭证
chmod +x deploy.sh sync-migrations.sh
```

### 2. 同步 SQL 初始化脚本

```bash
./sync-migrations.sh
# 或者指定源目录
SRC=/opt/ykt-aisaas/migrations ./sync-migrations.sh
```

### 3. 启动

```bash
./deploy.sh up          # 首次：拉镜像 + 启动 + MySQL 初始化
./deploy.sh logs ykt-aisaas
./deploy.sh restart ykt-aisaas
./deploy.sh down
```

## 端口分配

| 服务                    | 容器端口 | 宿主机端口 |
|------------------------|---------|----------|
| muliti-toy（统一入口）   | 80      | 80       |
| xiaozhi-server         | 8080    | 8080     |
| xiaozhi-server-admin   | 80      | 8082     |
| ykt-admin-go           | 8090    | 8090     |
| ykt-admin-console      | 80      | 8083     |
| ykt-aisaas             | 8190    | 8190     |
| ykt-aisaas-portal      | 80      | 8191     |
| MySQL                  | 3306    | 13306    |
| Redis                  | 6379    | 16379    |
| PostgreSQL + pgvector  | 5432    | 15432    |

## 镜像源

由四个上游仓库的 GitHub Actions 构建并推送到阿里云 ACR：

- `muliti-toy`：`zhangyujian111/muliti-toy`
- `xiaozhi-server` + `xiaozhi-server-admin`：`zhangyujian111/xiaozhi-server-go`
- `ykt-admin-go` + `ykt-admin-console`：`zhangyujian111/ykt-admin-go`
- `ykt-aisaas` + `ykt-aisaas-portal`：`zhangyujian111/ykt-aisaas`

镜像 tag：`latest`（默认分支）+ `git-<sha>`（每次提交）。服务器与 ACR 同地域时使用内网地址（`registry.cn-hangzhou-internal.aliyuncs.com`）。

## 单库架构

所有业务数据统一进 MySQL `ykt` 库，包括：

- `ykt_sys_*`（租户、用户、角色、菜单、部门、字典等）
- `sys_*`（设备）
- `ykt_alert_*` / `ykt_event_*`
- `ykt_aisaas_*`（AI 计费、计费单、人设、记忆、会话、模型注册等）

PostgreSQL 仅用于 RAG 向量检索（pgvector），由 `ykt-aisaas` 独占使用，与业务数据隔离。

## 跨服务调用（docker 网络名）

| 调用方                | 被调方           | 地址                          |
|---------------------|----------------|-----------------------------|
| xiaozhi-server       | ykt-aisaas     | `http://ykt-aisaas:8190`    |
| ykt-admin-console    | ykt-admin-go   | `http://ykt-admin-go:8090`  |
| xiaozhi-server-admin | xiaozhi-server | `http://xiaozhi-server:8080`|
| muliti-toy          | ykt-admin-go   | `http://ykt-admin-go:8090`  |
| muliti-toy          | ykt-aisaas     | `http://ykt-aisaas:8190`    |

## 已知差异与未解决问题

1. **ykt-admin-go 的 Config.Redis 没有 Password 字段**（`cmd/admin/main.go:29`），但生产用 Redis 启用了 `requirepass`。当前生产配置通过 DSN 走的是 docker 网络，密码未配置；如需启用密码需修改 main.go。
2. **xiaozhi-server-go 的配置全部从 config.yaml 读取，不支持环境变量**（`config.Load()` 用了 viper 自动 env，但容器内若挂载文件则 env 不生效）。
3. **Java 项目（xiaozhi-esp32-server-java、ykt-admin）**：已下线，迁移脚本 `scripts/migrate/*.up.sql` 作为一次性数据迁移使用。
