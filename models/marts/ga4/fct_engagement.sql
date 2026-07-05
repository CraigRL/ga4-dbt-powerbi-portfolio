{{ config(
    materialized = 'view'
) }}

WITH events AS (
    SELECT
        user_pseudo_id,
        session_number,
        event_timestamp,
        event_name,
        page_location
    FROM {{ ref('fct_events') }}
),

pageviews AS (
    SELECT
        user_pseudo_id,
        session_number,
        page_location,
        pageview_index
    FROM {{ ref('fct_pageviews') }}
),

-- Session-level engagement
session_engagement AS (
    SELECT
        user_pseudo_id,
        session_number,

        COUNT(*) AS total_events,
        COUNTIF(event_name = 'page_view') AS total_pageviews,
        COUNT(DISTINCT page_location) AS unique_pages_viewed
    FROM events
    GROUP BY 1,2
),

-- Landing & exit pages
session_pages AS (
    SELECT
        user_pseudo_id,
        session_number,
        MIN_BY(page_location, pageview_index) AS landing_page,
        MAX_BY(page_location, pageview_index) AS exit_page
    FROM pageviews
    GROUP BY 1,2
),

-- User-level engagement
user_engagement AS (
    SELECT
        user_pseudo_id,
        COUNT(DISTINCT session_number) AS sessions_per_user,
        COUNT(*) AS events_per_user
    FROM events
    GROUP BY 1
)

SELECT
    se.user_pseudo_id,
    se.session_number,

    -- Session metrics
    se.total_events,
    se.total_pageviews,
    se.unique_pages_viewed,

    sp.landing_page,
    sp.exit_page,

    -- User metrics
    ue.sessions_per_user,
    ue.events_per_user

FROM session_engagement se
LEFT JOIN session_pages sp
    ON se.user_pseudo_id = sp.user_pseudo_id
    AND se.session_number = sp.session_number
LEFT JOIN user_engagement ue
    ON se.user_pseudo_id = ue.user_pseudo_id

ORDER BY se.user_pseudo_id, se.session_number