{{ config(
    materialized = 'view'
) }}

WITH sessions AS (
    SELECT
        user_pseudo_id,
        session_number,
        DATE(session_start) AS event_date
    FROM {{ ref('fct_sessions') }}
),

events AS (
    SELECT
        user_pseudo_id,
        session_number,
        DATE(event_date) AS event_date,
        event_name
    FROM {{ ref('fct_events') }}
),

pageviews AS (
    SELECT
        user_pseudo_id,
        session_number,
        DATE(event_date) AS event_date
    FROM {{ ref('fct_pageviews') }}
),

revenue AS (
    SELECT
        user_pseudo_id,
        session_number,
        DATE(event_date) AS event_date,
        SUM(item_revenue) AS session_revenue
    FROM {{ ref('fct_item_performance') }}
    GROUP BY 1,2,3
),

traffic AS (
    SELECT
        user_pseudo_id,
        session_number,
        traffic_source,
        traffic_medium,
        traffic_campaign
    FROM {{ ref('fct_traffic_sources') }}
),

landing AS (
    SELECT
        user_pseudo_id,
        session_number,
        landing_page
    FROM {{ ref('fct_landing_pages') }}
),

combined AS (
    SELECT
        s.user_pseudo_id,
        s.session_number,
        s.event_date,

        -- Events
        COUNT(e.event_name) AS total_events,
        COUNTIF(e.event_name = 'page_view') AS total_pageviews,

        -- Revenue
        SUM(r.session_revenue) AS total_revenue,

        -- Traffic
        ANY_VALUE(t.traffic_source) AS traffic_source,
        ANY_VALUE(t.traffic_medium) AS traffic_medium,
        ANY_VALUE(t.traffic_campaign) AS traffic_campaign,

        -- Landing page
        ANY_VALUE(l.landing_page) AS landing_page

    FROM sessions s
    LEFT JOIN events e
        ON s.user_pseudo_id = e.user_pseudo_id
        AND s.session_number = e.session_number
        AND s.event_date = e.event_date
    LEFT JOIN revenue r
        ON s.user_pseudo_id = r.user_pseudo_id
        AND s.session_number = r.session_number
        AND s.event_date = r.event_date
    LEFT JOIN traffic t
        ON s.user_pseudo_id = t.user_pseudo_id
        AND s.session_number = t.session_number
    LEFT JOIN landing l
        ON s.user_pseudo_id = l.user_pseudo_id
        AND s.session_number = l.session_number

    GROUP BY 1,2,3
)

SELECT
    event_date,

    -- Users & Sessions
    COUNT(DISTINCT user_pseudo_id) AS daily_active_users,
    COUNT(DISTINCT session_number) AS daily_sessions,

    -- Engagement
    SUM(total_events) AS daily_events,
    SUM(total_pageviews) AS daily_pageviews,

    -- Revenue
    SUM(total_revenue) AS daily_revenue,

    -- Top landing page
    (
        SELECT landing_page
        FROM combined c2
        WHERE c2.event_date = c.event_date
        GROUP BY landing_page
        ORDER BY COUNT(*) DESC
        LIMIT 1
    ) AS top_landing_page,

    -- Top traffic source
    (
        SELECT traffic_source
        FROM combined c3
        WHERE c3.event_date = c.event_date
        GROUP BY traffic_source
        ORDER BY COUNT(*) DESC
        LIMIT 1
    ) AS top_traffic_source

FROM combined c
GROUP BY event_date
ORDER BY event_date