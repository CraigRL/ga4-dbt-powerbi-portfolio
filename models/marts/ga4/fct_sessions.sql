{{ config(
    materialized = 'view'
) }}

WITH sessions AS (
    SELECT
        user_pseudo_id,
        event_timestamp,
        event_name,
        event_date,
        session_number
    FROM {{ ref('stg_ga4_sessions') }}
),

session_rollup AS (
    SELECT
        user_pseudo_id,
        session_number,

        -- Convert INT64 microseconds → TIMESTAMP
        MIN(TIMESTAMP_MICROS(event_timestamp)) AS session_start,
        MAX(TIMESTAMP_MICROS(event_timestamp)) AS session_end,

        TIMESTAMP_DIFF(
            MAX(TIMESTAMP_MICROS(event_timestamp)),
            MIN(TIMESTAMP_MICROS(event_timestamp)),
            SECOND
        ) AS session_duration_seconds,

        COUNT(*) AS event_count,
        COUNTIF(event_name = 'user_engagement') AS engaged_event_count,

        -- Keep event_date for BI tools
        MIN(event_date) AS session_date
    FROM sessions
    GROUP BY 1,2
)

SELECT
    user_pseudo_id,
    session_number,
    session_start,
    session_end,
    session_duration_seconds,
    event_count,
    engaged_event_count,

    PARSE_DATE('%Y%m%d', session_date) AS session_date
FROM session_rollup
ORDER BY user_pseudo_id, session_number