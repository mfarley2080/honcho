# ## FARLEY: 2026-09-20 - Honcho deriver and Ollama embedding incident

## Summary

Honcho database-backed queries initially stalled for approximately 30 seconds because the API exhausted its PostgreSQL connection pool. After the API was rebuilt and redeployed, the deriver remained alive but embedding work became effectively wedged: LiteLLM forwarded embedding requests to Ollama, and Ollama took several minutes per request. The deriver timed out waiting for embeddings, so queue completion stopped while pending work grew.

The later Ollama upgrade exposed a separate regression: the new service no longer inherited the previous remote bind and Intel iGPU settings. Ollama briefly listened only on localhost and dropped the integrated GPU, causing CPU fallback. Those settings were restored.

## Timeline and evidence

- Health and docs endpoints were fast; DB-backed Honcho endpoints returned 500 after roughly 30 seconds.
- PostgreSQL logs identified connection-pool exhaustion (`QueuePool ... timeout 30.00`).
- Honcho v3.2.0 was built with the Starlette security patch (1.0.0 -> 1.6.0).
- The deriver started normally, but an embedding batch timed out after retries.
- Ollama logs showed requests from LiteLLM (`10.0.1.250`) taking 3-8 minutes, later up to 27-29 minutes. This was the original deriver failure state; Vulkan was active at that time.
- The deriver was stopped to prevent more work from entering the backlog.
- Ollama was upgraded from 0.24.0 to 0.34.2.
- After the upgrade, Ollama logged `dropping integrated GPU; to enable, set OLLAMA_IGPU_ENABLE=1` and fell back to CPU. The service also listened on `127.0.0.1:11434`, preventing LiteLLM from reaching it remotely.
- The service override was restored with:

  ```ini
  [Service]
  Environment="OLLAMA_KEEP_ALIVE=-1"
  Environment="OLLAMA_NUM_PARALLEL=4"
  Environment="OLLAMA_MAX_LOADED_MODELS=1"
  Environment="OLLAMA_IGPU_ENABLE=1"
  Environment="OLLAMA_VULKAN=1"
  Environment="OLLAMA_MAX_QUEUE=128"
  Environment="OLLAMA_HOST=http://0.0.0.0:11434"
  ```

- The model directory also changed with the service-user transition. Existing models were under `/root/.ollama/models`; the `ollama` service saw `/usr/share/ollama/.ollama/models`. `mxbai-embed-large` was pulled into the service-owned directory.
- Final verification: Ollama listened on `*:11434`, `mxbai-embed-large` reported `100% GPU`, and LiteLLM-originated embedding requests returned HTTP 200 in approximately 50 ms and 950 ms.

## Current conclusions

- The original deriver incident was provider saturation/backlog, not the later CPU fallback or localhost bind regression.
- The Ollama upgrade introduced a distinct configuration regression that temporarily masked the original behavior.
- `vector_store_ids` warnings appear in Ollama logs but are non-fatal; embedding requests still return HTTP 200.
- Concurrency was not changed during recovery. Current Ollama settings remain `OLLAMA_NUM_PARALLEL=4` and `OLLAMA_MAX_QUEUE=128`.

## Follow-up

- Monitor Honcho queue completion and pending counts until the accumulated backlog is gone.
- Consider reducing Ollama parallelism or the effective embedding batch size if latency regresses under backlog.
- Keep the Ollama systemd override under configuration management so upgrades preserve `OLLAMA_HOST`, `OLLAMA_VULKAN`, and `OLLAMA_IGPU_ENABLE`.
- Do not delete the old `/root/.ollama/models` copy until the service-owned model set has been verified and any required models are confirmed present.
