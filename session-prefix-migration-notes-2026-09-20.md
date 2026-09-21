# ## FARLEY: 2026-09-20 - Hermes AI session-prefix migration

## Decision

Enable Hermes `session_ai_peer_prefix` to prevent multiple AI peers from
sharing one gateway session. The resulting session names will be of the form:

```text
<ai-peer>-<original-session-name>
```

## Important behavior

- `SessionUpdate` accepts metadata and configuration only; it cannot rename a
  session because there is no writable session ID field.
- On first use after enabling the prefix, Hermes creates a new empty session
  when the prefixed name does not already exist.
- The old shared session is not renamed, deleted, or migrated automatically.
- Peer cards are peer-scoped and survive the session change.
- Session-scoped messages and history do not automatically carry into the new
  session. This is the context-loss risk for valuable Buck/Jenna history.
- Existing workspace documents/conclusions remain in the database, but a new
  session's context path may not include the old session's raw message history.

## Current data decision

- Preserve Buck and Jenna data.
- Wazuh webhook sessions were removed on 2026-09-20 (88 sessions); the
  filesystem snapshot taken before cleanup is the rollback point.
- Suki remains partially present; only Suki content inside deleted Wazuh
  sessions was removed.
- Do not globally delete peers or documents for Buck/Jenna.

## Safe rollout procedure

1. Keep Hermes stopped and retain the pre-migration snapshot.
2. Enable `session_ai_peer_prefix`.
3. Start Hermes briefly so the new prefixed Buck/Jenna sessions are created.
4. Stop Hermes again before any data copy.
5. Inventory old and new session IDs, message counts, documents, embeddings,
   and session-peer links.
6. Use an API-supported clone/import path, or a separately reviewed
   transactional SQL copy, to bring the required Buck/Jenna history into the
   new sessions. Do not rename rows in place.
7. Verify the new sessions' context and peer cards while the old sessions stay
   intact as rollback copies.
8. Start Hermes normally and monitor new message routing and queue health.

## Validation queries

```sql
SELECT id, name, is_active
FROM sessions
WHERE workspace_name = 'q-hermes'
  AND (name = 'buck' OR name = 'jenna'
       OR name LIKE 'buck-%' OR name LIKE 'jenna-%')
ORDER BY name;

SELECT session_name, peer_name, count(*) AS messages
FROM messages
WHERE workspace_name = 'q-hermes'
  AND (lower(peer_name) IN ('buck', 'jenna')
       OR session_name LIKE 'buck-%'
       OR session_name LIKE 'jenna-%')
GROUP BY session_name, peer_name
ORDER BY session_name, peer_name;
```

