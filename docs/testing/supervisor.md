# 监督器验证

局部测试不访问第三方 API，使用 fake Codex CLI 模拟“首次失败、恢复成功”：

```bash
./tests/test_supervisor.sh
```

验收点：

- 首次进程返回非零后进入恢复流程；
- 恢复命令包含 `--last` 和 `继续`；
- 成功后写入 `completed` 状态，后续 Compose 重启不会重复启动新会话；
- 手动中断码 `130`/`143` 不触发自动恢复。
