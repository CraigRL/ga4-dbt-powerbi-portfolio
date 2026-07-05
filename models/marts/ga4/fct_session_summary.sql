{{ config(
    materialized = 'view'
) }}

WITH sessions AS (
    SELECT
        user_pseudo_id,
        session_number,
        session_start,
        session_end
    FROM {{ ref('fct_sessions') }}
),

landing AS (
    SELECT
        user_pseudo_id,
        session_number,
        landing_page,
        landing_page_title,
        landing_page_referrer,
        landing_datetime
    FROM {{ ref('fct_landing_pages') }}
),

exit_pages AS (
    SELECT
        user_pseudo_id,
        session_number,
        exit_page,
        exit_page_title,
        exit_page_referrer,
        exit_datetime
    FROM {{ ref('fct_exit_pages') }}
),

engagement AS (
    SELECT
        user_pseudo_id,
        session_number,
        total_events,
        total_pageviews,
        unique_pages_viewed,
        sessions_per_user,
        events_per_user
    FROM {{ ref('fct_engagement') }}
),

traffic AS (
    SELECT
        user_pseudo_id,
        session_number,
        traffic_source,
        traffic_medium,
        traffic_campaign,
        landing_page AS traffic_landing_page
    FROM {{ ref('fct_traffic_sources') }}
),

revenue AS (
    SELECT
        user_pseudo_id,
        session_number,
        SUM(item_revenue) AS session_revenue
    FROM {{ ref('fct_item_performance') }}
    GROUP BY 1,2
)

SELECT
    s.user_pseudo_id,
    s.session_number,
    s.session_start,
    s.session_end,

    -- Landing page
    l.landing_page,
    l.landing_page_title,
    l.landing_page_referrer,
    l.landing_datetime,

    -- Exit page
    e.exit_page,
    e.exit_page_title,
    e.exit_page_referrer,
    e.exit_datetime,

    -- Engagement
    g.total_events,
    g.total_pageviews,
    g.unique_pages_viewed,
    g.sessions_per_user,
    g.events_per_user,

    -- Traffic
    t.traffic_source,
    t.traffic_medium,
    t.traffic_campaign,

    -- Revenue
    r.session_revenue

FROM sessions s
LEFT JOIN landing l
    ON s.user_pseudo_id = l.user_pseudo_id
    AND s.session_number = l.session_number
LEFT JOIN exit_pages e
    ON s.user_pseudo_id = e.user_pseudo_id
    AND s.session_number = e.session_number
LEFT JOIN engagement g
    ON s.user_pseudo_id = g.user_pseudo_id
    AND s.session_number = g.session_number
LEFT JOIN traffic t
    ON s.user_pseudo_id = t.user_pseudo_id
    AND s.session_number = t.session_number
LEFT JOIN revenue r
    ON s.user_pseudo_id = r.user_pseudo_id
    AND s.session_number = r.session_number

ORDER BY s.user_pseudo_id, s.session_number