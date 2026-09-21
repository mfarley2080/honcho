BEGIN;

-- Confirm the target session.
SELECT id AS session_row_id,
       name,
       is_active
FROM sessions
WHERE workspace_name='q-hermes'
  AND name='agent-main-homeassistant-channel-ha_events-homeassistant';

-- Confirm queue ownership and verify every matching row has a session_id.
SELECT task_type,
       processed,
       count(*) AS count,
       count(*) FILTER (WHERE session_id IS NULL) AS missing_session_id
FROM queue
WHERE workspace_name='q-hermes'
  AND session_id = (
    SELECT id
    FROM sessions
    WHERE workspace_name='q-hermes'
      AND name='agent-main-homeassistant-channel-ha_events-homeassistant'
  )
GROUP BY task_type, processed
ORDER BY task_type, processed;

-- This should be zero before proceeding.
SELECT count(*) AS active_claims
FROM active_queue_sessions
WHERE work_unit_key LIKE '%agent-main-homeassistant-channel-ha_events-homeassistant%';

-- All queued work for this session is junk. Stored messages and conclusions are untouched.
DELETE FROM queue
WHERE workspace_name='q-hermes'
  AND session_id = (
    SELECT id
    FROM sessions
    WHERE workspace_name='q-hermes'
      AND name='agent-main-homeassistant-channel-ha_events-homeassistant'
  )
RETURNING id, task_type, processed;

COMMIT;

-- Verify no queued work remains for this session.
SELECT count(*) AS remaining_queue_rows
FROM queue
WHERE workspace_name='q-hermes'
  AND work_unit_key LIKE '%agent-main-homeassistant-channel-ha_events-homeassistant%';
