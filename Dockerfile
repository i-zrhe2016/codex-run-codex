FROM node:22-bookworm-slim

ARG CODEX_CLI_VERSION=0.151.0

ENV HOME=/home/node \
    CODEX_HOME=/home/node/.codex \
    CODEX_WORKDIR=/workspace \
    NODE_ENV=production

RUN npm install --global --omit=dev "@openai/codex@${CODEX_CLI_VERSION}" \
    && npm cache clean --force

RUN mkdir -p /home/node/.codex /workspace \
    && chown -R node:node /home/node /workspace

COPY scripts/codex-entrypoint.sh /usr/local/bin/codex-entrypoint
COPY scripts/codex-supervisor.sh /usr/local/bin/codex-supervisor

RUN chmod 755 /usr/local/bin/codex-entrypoint /usr/local/bin/codex-supervisor \
    && codex --version

USER node
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/codex-entrypoint"]
CMD []
