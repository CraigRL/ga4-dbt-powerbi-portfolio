{{ config(
    materialized = 'view'
) }}

WITH pageviews AS (
    SELECT
        user_pseudo_id,
        session_number,
        page_location,
        page_title,
        page_referrer,
        pageview_index,
        event_timestamp
    FROM {{ ref('fct_pageviews') }}
),

sessions AS (
    SELECT
        user_pseudo_id,
        session_number,
        session_start,
        session_end
    FROM {{ ref('fct_sessions') }}
),

-- Identify the last pageview in each session
exit_pages AS (
    SELECT
        user_pseudo_id,
        session_number,
        page_location AS exit_page,
        page_title AS exit_page_title,
        page_referrer AS exit_page_referrer,
        event_timestamp AS exit_timestamp
    FROM pageviews
    QUALIFY pageview_index = MAX(pageview_index) OVER (
        PARTITION BY user_pseudo_id, session_number
    )
)

SELECT
    s.user_pseudo_id,
    s.session_number,
    s.session_start,
    s.session_end,

    e.exit_page,
    e.exit_page_title,
    e.exit_page_referrer,
    DATETIME(TIMESTAMP_MICROS(e.exit_timestamp)) AS exit_datetime

FROM sessions s
LEFT JOIN exit_pages e
    ON s.user_pseudo_id = e.user_pseudo_id
    AND s.session_number = e.session_number

ORDER BY s.user_pseudo_id, s.session_number