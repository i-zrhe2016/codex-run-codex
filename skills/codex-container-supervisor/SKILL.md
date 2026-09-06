---
name: codex-container-supervisor
description: Use when the host Codex must start and supervise a second Codex CLI in this repository's Docker Compose service. Keeps lifecycle decisions outside the container; do not use it to run the current host Codex inside Docker.
---

# Codex Container Supervisor

Use this skill when the current, host-side Codex needs to delegate work to the second Codex CLI packaged by this repository.

## Runtime boundary

- The first Codex is the host-side supervisor and remains outside Docker.
- The second Codex is the only Codex process inside the container.
- The container performs one action and exits. It must not retry, resume, or maintain a supervisor loop itself.
- While the second Codex is running, the first Codex observes its terminal output and exit status. Do not edit the same workspace concurrently.

## Start the second Codex

Run these commands from the repository root, after the image has been built and `.env` is configured:

```bash
docker compose run --rm codex
```

For a non-interactive delegated task:

```bash
CODEX_MODE=exec CODEX_PROMPT='检查当前工作区并完成任务' \
  docker compose run --rm -T codex
```

Keep the command in the foreground. If the command tool returns a running session, poll that session so the host Codex can observe completion and output.

## Supervise the result

After the second Codex exits:

1. Treat exit code `0` as completion.
2. Treat `130` or `143` as an intentional stop; do not resume automatically.
3. For another non-zero exit, inspect the visible error and recent Compose output before acting.
4. Resume only when the error is plausibly transient and the persisted session should continue:

   ```bash
   CODEX_ACTION=resume docker compose run --rm codex
   ```

5. Stop and report configuration, authentication, permission, or repeated failures instead of blindly retrying forever. The host Codex owns the retry decision and should keep the number of attempts proportional to the evidence.

The `codex_home` named volume must be reused for `resume --last`. Do not use `docker compose down -v` during supervision.

## Fresh sessions and concurrency

- Use `CODEX_ACTION=start` for a new session; this is the default.
- Run only one second Codex at a time against the same workspace and `codex_home` volume.
- Use the existing Compose environment and host-side key-file mount. Do not print or copy API keys into commands, logs, skill files, or documentation.
