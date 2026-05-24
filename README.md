# honcho

Portainer stack configuration for [Honcho](https://github.com/plastic-labs/honcho) — AI memory layer for stateful agents.

Upstream version: **v3.0.7**

## How it works

The image is built locally on the Docker host from the upstream repo, then referenced by name in the Portainer stack. No registry required.

## First-time setup (run on TrueNAS as root)

**1. Build the image**

```bash
bash build.sh
```

Clones `plastic-labs/honcho` at the pinned tag and builds `honcho:latest` locally.

**2. Create host directories and set ownership**

```bash
bash setup.sh
```

Creates `/mnt/tank/docker/honcho/{postgres,redis,logs}` with correct ownership:

| Directory | Owner | Who |
|---|---|---|
| `postgres` | 999:999 | postgres runtime user |
| `redis` | 999:999 | redis runtime user |
| `logs` | 100:101 | honcho app runtime user |

## Portainer stack setup

1. Add stack → Git repository → `https://github.com/mfarley2080/honcho`
2. Compose file: `honcho-portainer.yml`
3. Environment file: `stack.env`
4. Add these environment overrides in Portainer (do not commit to git):

| Variable | Description |
|---|---|
| `DB_PASSWORD` | Strong random password for postgres |
| `LLM_API_KEY` | LiteLLM key for LLM calls (deriver, dialectic, summary, dream) |
| `EMBEDDING_API_KEY` | LiteLLM key for embedding calls — can be the same as `LLM_API_KEY` or different |
| `AUTH_JWT_SECRET` | JWT secret — `python3 -c "import secrets; print(secrets.token_hex(32))"` |
| `AUTH_USE_AUTH` | `true` to require JWT auth on all API requests (recommended for production) |

Model and endpoint defaults live in `stack.env` and can be overridden the same way. LLM and embedding endpoints are independent — `LLM_BASE_URL` / `LLM_MODEL` control all reasoning components; `EMBEDDING_BASE_URL` / `EMBEDDING_MODEL` / `EMBEDDING_DIMENSIONS` control the embedding pipeline.

5. Deploy

## Updating upstream version

Edit the `TAG` variable in `build.sh`, re-run it on TrueNAS, then re-pull the stack in Portainer.

## Services

| Service | Image | Role |
|---|---|---|
| api | honcho:latest | FastAPI server on port 8000 |
| deriver | honcho:latest | Background memory worker |
| database | pgvector/pgvector:pg15 | PostgreSQL + pgvector extension |
| redis | redis:8.2 | Cache and job queue |

`pgvector` is a PostgreSQL extension that adds a vector data type and similarity search — Honcho uses it to store AI embeddings for semantic memory retrieval.
