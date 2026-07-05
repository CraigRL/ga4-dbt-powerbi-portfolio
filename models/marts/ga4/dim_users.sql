{{ config(
    materialized = 'view'
) }}

WITH sessions AS (
    SELECT
        user_pseudo_id,
        session_number,
        session_start,
        session_end,
        session_duration_seconds
    FROM {{ ref('fct_sessions') }}
),

users AS (
    SELECT
        user_pseudo_id,

        -- First session
        MIN(session_number) AS first_session_number,
        MIN(session_start) AS first_session_start,

        -- Most recent session
        MAX(session_number) AS last_session_number,
        MAX(session_end) AS last_session_end,

        -- Activity metrics
        COUNT(*) AS total_sessions,
        SUM(session_duration_seconds) AS total_session_duration_seconds
    FROM sessions
    GROUP BY user_pseudo_id
)

SELECT
    user_pseudo_id,
    first_session_number,
    first_session_start,
    last_session_number,
    last_session_end,
    total_sessions,
    total_session_duration_seconds
FROM users
ORDER BY user_pseudo_id