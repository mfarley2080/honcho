# honcho

Portainer stack configuration for [Honcho](https://github.com/plastic-labs/honcho) — AI memory layer for stateful agents.

Upstream version: **v3.0.7**

## How it works

The image is built locally on the Docker host from the upstream repo, then referenced by name in the Portainer stack. No registry required.

## First-time setup (run on TrueNAS as root)

Copy the repo files to `/mnt/tank/docker/honcho` on TrueNAS (via SCP or SMB share), then:

**1. Build the image**

```bash
cd /mnt/tank/docker/honcho
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
2. Authentication: GitHub personal access token (repo is private)
3. Compose file: `honcho-portainer.yml`
4. Environment file: `stack.env`
5. Add these environment overrides in Portainer (do not commit to git):

| Variable | Description |
|---|---|
| `DB_PASSWORD` | Strong random password for postgres |
| `LLM_API_KEY` | LiteLLM key for LLM calls (deriver, dialectic, summary, dream) |
| `EMBEDDING_API_KEY` | LiteLLM key for embedding calls — can be the same as `LLM_API_KEY` or different |
| `AUTH_JWT_SECRET` | JWT secret — `python3 -c "import secrets; print(secrets.token_hex(32))"` |
| `AUTH_USE_AUTH` | `true` to require JWT auth on all API requests (recommended for production) |

Model and endpoint defaults live in `stack.env` and can be overridden the same way. LLM and embedding endpoints are independent — `LLM_BASE_URL` / `LLM_MODEL` control all reasoning components; `EMBEDDING_BASE_URL` / `EMBEDDING_MODEL` / `EMBEDDING_DIMENSIONS` control the embedding pipeline.

6. Deploy

## Troubleshooting

### StartupValidationError: embedding dim mismatch

Alembic migrations hardcode `vector(1536)` regardless of `EMBEDDING_VECTOR_DIMENSIONS`. If you deploy with a non-default dimension (e.g. 1024 for mxbai-embed-large), the API will refuse to start until the schema is updated.

**Fix (fresh deploy — no real data):**

```bash
docker exec -it honcho-database-1 psql -U postgres postgres -c "
  DROP INDEX IF EXISTS ix_message_embeddings_embedding;
  ALTER TABLE message_embeddings ALTER COLUMN embedding TYPE vector(1024) USING NULL;
  DROP INDEX IF EXISTS ix_documents_embedding;
  ALTER TABLE documents ALTER COLUMN embedding TYPE vector(1024) USING NULL;
"
```

Replace `1024` with your `EMBEDDING_DIMENSIONS` value. Then restart the api service in Portainer.

**Fix (existing data):** Use the upstream migration script, which handles both tables and their HNSW indexes atomically. The API must be reachable to exec into:

```bash
docker exec -it honcho-api-1 uv run python scripts/configure_embeddings.py --yes
```

This script refuses to run if any non-null embeddings exist — re-embedding out-of-band into a fresh deployment is required in that case.

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
