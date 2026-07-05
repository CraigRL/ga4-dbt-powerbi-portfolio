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

-- Identify the first pageview in each session
landing AS (
    SELECT
        user_pseudo_id,
        session_number,
        page_location AS landing_page,
        page_title AS landing_page_title,
        page_referrer AS landing_page_referrer,
        event_timestamp AS landing_timestamp
    FROM pageviews
    WHERE pageview_index = 1
)

SELECT
    s.user_pseudo_id,
    s.session_number,
    s.session_start,
    s.session_end,

    l.landing_page,
    l.landing_page_title,
    l.landing_page_referrer,
    DATETIME(TIMESTAMP_MICROS(l.landing_timestamp)) AS landing_datetime

FROM sessions s
LEFT JOIN landing l
    ON s.user_pseudo_id = l.user_pseudo_id
    AND s.session_number = l.session_number

ORDER BY s.user_pseudo_id, s.session_number