# 容器入口与宿主监督契约验证

局部测试不访问第三方 API，使用 fake Codex CLI 验证容器入口只执行宿主机指定的 action：

```bash
./tests/test_entrypoint.sh
```

验收点：

- `start` action 直接启动第二个 Codex，并传递工作目录和 prompt；
- `resume` action 传递 `resume --last` 和恢复 prompt；
- 非法 action 在容器入口处被拒绝；
- 测试不启动 Docker，也不访问第三方 API。
