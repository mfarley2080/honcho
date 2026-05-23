# honcho

Portainer stack configuration for [Honcho](https://github.com/plastic-labs/honcho) — AI memory layer for stateful agents.

Upstream version: **v3.0.7**

## How it works

GitHub Actions builds the upstream Honcho image and pushes it to `ghcr.io/mfarley2080/honcho`. Portainer pulls from there — same pattern as the other stacks.

After the first Actions run you must make the GHCR package public:
**GitHub → Packages → honcho → Package settings → Change visibility → Public**

## Prerequisites

- Traefik running with `traefik-frontend` network and `production` cert resolver
- TrueNAS host directories created (one-time):

```bash
mkdir -p /mnt/tank/docker/honcho/{postgres,redis}
chown 999:999 /mnt/tank/docker/honcho/postgres
chown 999:999 /mnt/tank/docker/honcho/redis
```

Both `pgvector/pgvector:pg15` (postgres) and `redis:8.2` run as UID/GID **999:999**.

## Portainer stack setup

1. Add stack → Git repository → `https://github.com/mfarley2080/honcho`
2. Compose file: `honcho-portainer.yml`
3. Environment file: `stack.env`
4. Add these environment overrides in Portainer (do not commit to git):

| Variable | Description |
|---|---|
| `DB_PASSWORD` | Strong random password for postgres |
| `LLM_OPENAI_API_KEY` | OpenAI API key (or use `LLM_ANTHROPIC_API_KEY` / `LLM_GEMINI_API_KEY`) |
| `AUTH_JWT_SECRET` | JWT secret — generate with `python -c "import secrets; print(secrets.token_hex(32))"` |
| `AUTH_USE_AUTH` | Set to `true` to require JWT auth on all API requests (recommended for production) |

5. Deploy

## Updating upstream version

Edit `UPSTREAM_TAG` in `.github/workflows/build.yml`, commit to main, and re-pull in Portainer.

## Services

| Service | Image | Role |
|---|---|---|
| api | ghcr.io/mfarley2080/honcho | FastAPI server on port 8000 |
| deriver | ghcr.io/mfarley2080/honcho | Background memory worker |
| database | pgvector/pgvector:pg15 | PostgreSQL + pgvector extension |
| redis | redis:8.2 | Cache and job queue |

`pgvector` is a PostgreSQL extension that adds a vector data type and similarity search — Honcho uses it to store AI embeddings for semantic memory retrieval.
