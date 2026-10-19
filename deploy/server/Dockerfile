# METHOD HORROR self-hosted server: the lobby service plus the headless
# dedicated game server it starts for each room (docs/deployment.md).
# Build context: the repository root, after exporting the
# "Linux Dedicated Server" preset to builds/server/method_horror_server.x86_64.
FROM node:24-bookworm-slim

LABEL org.opencontainers.image.title="METHOD HORROR server" \
      org.opencontainers.image.description="Lobby service and headless dedicated server for self-hosted METHOD HORROR co-op" \
      org.opencontainers.image.source="https://github.com/NorihyDev/method-horror-game" \
      org.opencontainers.image.licenses="NOASSERTION"

WORKDIR /opt/method
COPY services/lobby/package.json services/lobby/package-lock.json lobby/
RUN cd lobby && npm ci --omit=dev && npm cache clean --force
COPY services/lobby/src lobby/src
COPY builds/server/method_horror_server.x86_64 server/method_horror_server.x86_64
RUN chmod 755 server/method_horror_server.x86_64 \
    && useradd --system --home-dir /opt/method method \
    && mkdir -p /data && chown method /data

# No secrets here: METHOD_TICKET_SECRET and METHOD_SERVER_SECRET must be
# passed at run time (the lobby refuses to start in production without them).
ENV NODE_ENV=production \
    LOBBY_HOST=0.0.0.0 \
    LOBBY_PORT=8787 \
    LOBBY_DB_PATH=/data/lobby.sqlite \
    SPAWN_LOCAL_SERVERS=1 \
    GODOT_BIN=/opt/method/server/method_horror_server.x86_64 \
    GAME_PATH= \
    SERVER_PORT_MIN=24600 \
    SERVER_PORT_MAX=24699 \
    LOBBY_URL_FOR_SERVERS=http://127.0.0.1:8787

VOLUME /data
EXPOSE 8787/tcp 24600-24699/udp
USER method
WORKDIR /opt/method/lobby
HEALTHCHECK --interval=30s --timeout=5s CMD node -e "fetch('http://127.0.0.1:8787/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "src/main.ts"]
