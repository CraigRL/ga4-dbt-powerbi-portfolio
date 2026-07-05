{{ config(
    materialized = 'view'
) }}

WITH events AS (
    SELECT
        user_pseudo_id,
        event_timestamp,
        event_name,
        event_date
    FROM {{ ref('stg_ga4_events') }}
),

-- Order events and compute time difference
ordered AS (
    SELECT
        user_pseudo_id,
        event_timestamp,
        event_name,
        event_date,
        LAG(event_timestamp) OVER (
            PARTITION BY user_pseudo_id
            ORDER BY event_timestamp
        ) AS prev_event_ts
    FROM events
),

-- Identify session boundaries (gap > 30 minutes)
sessionized AS (
    SELECT
        *,
        CASE
            WHEN prev_event_ts IS NULL THEN 1
            WHEN TIMESTAMP_DIFF(
                TIMESTAMP_MICROS(event_timestamp),
                TIMESTAMP_MICROS(prev_event_ts),
                MINUTE
            ) > 30 THEN 1
            ELSE 0
        END AS is_new_session
    FROM ordered
),

-- Generate synthetic session numbers
sessions AS (
    SELECT
        *,
        SUM(is_new_session) OVER (
            PARTITION BY user_pseudo_id
            ORDER BY event_timestamp
        ) AS session_number
    FROM sessionized
)

SELECT
    user_pseudo_id,
    event_timestamp,
    event_name,
    event_date,
    session_number
FROM sessions
ORDER BY user_pseudo_id, event_timestamp