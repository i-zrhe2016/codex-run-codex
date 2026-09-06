# Codex Run Codex

一个由宿主机第一个 Codex 通过 skill 调度的轻量 Compose runner。第二个 Codex CLI 在容器内执行一次；第一个 Codex 读取退出状态和日志，并在确认需要时显式执行 `resume --last`。

![运行架构](docs/diagrams/codex-run-codex.svg)

## 特性

- 宿主机第一个 Codex 使用 [`codex-container-supervisor`](skills/codex-container-supervisor/SKILL.md) skill 启动并监督容器内第二个 Codex；
- 第三方 provider 通过环境变量配置，启动时生成隔离的 `config.toml`；
- API key 支持环境变量或宿主机文件，认证文件只写入 Compose 持久卷；
- 容器只执行单次 Codex 调用，不包含内部自动重试或第二层 supervisor；
- 工作区以 bind mount 提供，`CODEX_HOME` 以 named volume 持久化；
- 容器以非 root 用户运行，并启用只读根文件系统和能力裁剪。

## 快速开始

```bash
cp .env.example .env
# 编辑 .env：CODEX_PROVIDER_BASE_URL、CODEX_MODEL、CODEX_API_KEY
./scripts/docker-build.sh codex-run-codex:local .
# 由宿主机第一个 Codex 使用 skill 执行并观察
docker compose run --rm codex
```

如果不想把 key 放进 `.env`，例如：

```dotenv
CODEX_API_KEY_FILE=/absolute/path/to/codex-api-key
CODEX_API_KEY=
```

第三方接口需要兼容 Codex 支持的 `responses` 或 `chat` wire API。`CODEX_PROVIDER_BASE_URL` 应填写接口要求的 base URL，例如是否包含 `/v1` 由供应商定义。

需要恢复最近会话时，由宿主机第一个 Codex 执行：

```bash
CODEX_ACTION=resume docker compose run --rm codex
```

详细的启动、观察和恢复约定见 [容器 Codex 监督 skill](skills/codex-container-supervisor/SKILL.md) 和[Compose 部署说明](docs/deployment/docker-compose.md)。

## 文档

- [架构说明](docs/architecture/overview.md)
- [Docker Compose 部署](docs/deployment/docker-compose.md)
- [监督器测试](docs/testing/supervisor.md)
- [容器 Codex 监督 skill](skills/codex-container-supervisor/SKILL.md)
- [PlantUML 架构源文件](docs/diagrams/codex-run-codex.puml)
