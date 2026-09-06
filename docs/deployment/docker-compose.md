# Docker Compose 部署

## 配置

复制环境模板并填写第三方 OpenAI 兼容接口：

```bash
cp .env.example .env
```

至少设置 `CODEX_PROVIDER_BASE_URL`、`CODEX_MODEL` 和 API key。API key 可直接写入 `CODEX_API_KEY`，生产环境建议把 key 放入宿主机文件，并将 `CODEX_API_KEY_FILE` 指向该文件。Compose 只会把这个文件以只读方式挂载到容器。

## 构建

```bash
./scripts/docker-build.sh codex-run-codex:local .
```

构建后，由宿主机第一个 Codex 加载 [`codex-container-supervisor`](../../skills/codex-container-supervisor/SKILL.md) skill，并在前台启动第二个 Codex：

```bash
docker compose run --rm codex
```

`docker compose run` 是一次性前台调用，退出码会返回给第一个 Codex。不要依赖 Compose 的后台 restart 机制代替宿主机监督。

非交互任务可以使用：

```bash
CODEX_MODE=exec CODEX_PROMPT='检查当前工作区并完成任务' \
  docker compose run --rm -T codex
```

构建脚本使用 CPU 感知的 Buildx builder；不需要在 Compose 中额外调用 `--build`。如果第一个 Codex 需要查看正在运行的调用，可保留 `docker compose run` 的前台会话，或另开终端查看：

```bash
docker compose logs -f codex
```

会话保存在 Compose named volume `codex_home`。因此容器结束后，第一个 Codex 可以使用同一个 volume 执行恢复：

```bash
CODEX_ACTION=resume docker compose run --rm codex
```

恢复是否合理由第一个 Codex 根据退出状态和日志判断；容器不会自行循环重试。
除非确认要删除会话历史，否则不要使用 `docker compose down -v`。

## 新建会话

明确开始新会话时，使用默认的 `start` action：

```bash
CODEX_ACTION=start docker compose run --rm codex "继续处理当前工作区的任务"
```

同一工作区和 `codex_home` volume 同时只允许一个第二 Codex 调用，避免两个 CLI 同时操作同一个会话：

```bash
docker compose ps
CODEX_ACTION=start docker compose run --rm codex "你的新任务"
```
