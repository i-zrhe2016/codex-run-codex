# Docker Compose 部署

## 配置

复制环境模板并填写第三方 OpenAI 兼容接口：

```bash
cp .env.example .env
```

至少设置 `CODEX_PROVIDER_BASE_URL`、`CODEX_MODEL` 和 API key。API key 可直接写入 `CODEX_API_KEY`，生产环境建议把 key 放入宿主机文件，并将 `CODEX_API_KEY_FILE` 指向该文件。Compose 只会把这个文件以只读方式挂载到容器。

## 构建和启动

```bash
./scripts/docker-build.sh codex-run-codex:local .
docker compose up -d
docker compose attach codex
```

构建脚本使用 CPU 感知的 Buildx builder；不需要在 Compose 中额外调用 `--build`。查看后台日志：

```bash
docker compose logs -f codex
```

会话保存在 Compose named volume `codex_home`。因此容器重启后，监督器可以用 `codex resume --last` 找回最近会话。
除非确认要删除会话历史，否则不要使用 `docker compose down -v`。

## 新建会话

服务正常结束后，状态文件会标记为 `completed`，避免 Compose 重启时重复执行。明确要开始新会话时：

```bash
CODEX_RESET_SESSION=1 docker compose run --rm codex "继续处理当前工作区的任务"
```

如果已有 `codex` 服务在运行，应先停止它，避免两个 CLI 同时操作同一个会话：

```bash
docker compose stop codex
CODEX_RESET_SESSION=1 docker compose run --rm codex "你的新任务"
```
