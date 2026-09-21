-- ## FARLEY: 2026-09-20 - Selective peer/session migration runbook
--
-- Purpose:
--   Preserve valuable Buck/Jenna history while preparing to rewrite their
--   active Hermes sessions with session_ai_peer_prefix. The current disposable
--   target is the old Wazuh webhook-session family; Suki remains unmodified.
--
-- Safety:
--   1. Run the READ-ONLY section first and save the output.
--   2. Review the generated disposable_session_ids below.
--   3. Do not add Buck/Jenna IDs to the deletion list.
--   4. Take/retain the Honcho filesystem snapshot before COMMIT.

-- =====================
-- READ-ONLY INVENTORY
-- =====================
\pset pager off
\x off

SELECT id, workspace_name, name, is_active
FROM sessions
WHERE workspace_name = 'q-hermes'
ORDER BY name;

SELECT peer_name, count(*) AS message_count
FROM messages
WHERE workspace_name = 'q-hermes'
GROUP BY peer_name
ORDER BY peer_name;

SELECT observer, observed, count(*) AS live_conclusions
FROM documents
WHERE workspace_name = 'q-hermes'
  AND deleted_at IS NULL
GROUP BY observer, observed
ORDER BY observer, observed;

-- =====================
-- PRESERVATION CHECK
-- =====================
-- These must remain present. Record the result before any delete.
SELECT 'buck_or_jenna_messages' AS check_name, count(*) AS rows
FROM messages
WHERE workspace_name = 'q-hermes'
  AND lower(peer_name) IN ('buck', 'jenna');

SELECT 'buck_or_jenna_live_conclusions' AS check_name, count(*) AS rows
FROM documents
WHERE workspace_name = 'q-hermes'
  AND deleted_at IS NULL
  AND (lower(observer) IN ('buck', 'jenna')
       OR lower(observed) IN ('buck', 'jenna'));

-- ==========================================================
-- TARGETED WAZUH WEBHOOK CLEANUP (DO NOT RUN UNTIL COUNTS ARE VERIFIED)
-- ==========================================================
-- Replace the placeholder UUIDs with exact disposable Suki session IDs.
-- Leave this empty if there are no Suki sessions to remove.
BEGIN;

CREATE TEMP TABLE disposable_session_ids (id text PRIMARY KEY);

-- Wazuh sessions are deliberately selected by their stable old-session name.
INSERT INTO disposable_session_ids (id)
SELECT id::text
FROM sessions
WHERE workspace_name = 'q-hermes'
  AND name LIKE 'agent-main-webhook-%wazuh%';

-- Optional future Suki cleanup: add exact session IDs only after review.
-- INSERT INTO disposable_session_ids (id) VALUES ('EXACT-SUKI-SESSION-ID');

SELECT s.id, s.name
FROM sessions s
JOIN disposable_session_ids d ON d.id = s.id::text
ORDER BY s.name;

-- Refuse to proceed if a protected peer appears in the selected sessions.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM messages m
    JOIN sessions hs ON hs.name = m.session_name
    JOIN disposable_session_ids s ON s.id = hs.id::text
    WHERE lower(m.peer_name) IN ('buck', 'jenna')
  ) THEN
    RAISE EXCEPTION 'Aborting: selected Suki session contains Buck/Jenna messages';
  END IF;
END $$;

-- Queue work first, so no stale pending tasks remain for deleted sessions.
DELETE FROM queue q
USING disposable_session_ids s
WHERE q.session_id::text = s.id;

-- Remove message embeddings and messages for the explicitly selected sessions.
DELETE FROM message_embeddings e
USING disposable_session_ids s
WHERE e.message_id IN (
  SELECT m.public_id
  FROM messages m
  JOIN sessions hs ON hs.name = m.session_name
  WHERE hs.id::text = s.id
);

DELETE FROM messages m
USING disposable_session_ids s, sessions hs
WHERE hs.id::text = s.id
  AND hs.name = m.session_name;

-- Remove documents/conclusions whose source session is selected. Preserve all other
-- conclusions, including every conclusion involving Buck or Jenna.
DELETE FROM documents c
USING disposable_session_ids s, sessions hs
WHERE hs.id::text = s.id
  AND hs.name = c.session_name;

DELETE FROM session_peers sp
USING disposable_session_ids s, sessions hs
WHERE hs.id::text = s.id
  AND sp.workspace_name = hs.workspace_name
  AND sp.session_name = hs.name;

DELETE FROM sessions s
USING disposable_session_ids x
WHERE s.id::text = x.id;

-- Verify protected data still exists before committing.
SELECT 'protected_messages_after' AS check_name, count(*) AS rows
FROM messages
WHERE workspace_name = 'q-hermes'
  AND lower(peer_name) IN ('buck', 'jenna');

SELECT 'protected_conclusions_after' AS check_name, count(*) AS rows
FROM documents
WHERE workspace_name = 'q-hermes'
  AND deleted_at IS NULL
  AND (lower(observer) IN ('buck', 'jenna')
       OR lower(observed) IN ('buck', 'jenna'));

-- Review DELETE counts and verification output, then choose one:
-- COMMIT;
-- ROLLBACK;
