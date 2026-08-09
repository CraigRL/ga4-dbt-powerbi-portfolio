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

event_metrics AS (
    SELECT
        user_pseudo_id,
        session_number,
        event_date,
        COUNT(*) AS total_events,
        COUNTIF(event_name = 'page_view') AS total_pageviews
    FROM {{ ref('fct_events') }}
    GROUP BY 1, 2, 3
),

revenue AS (
    SELECT
        user_pseudo_id,
        session_number,
        event_date,
        SUM(item_revenue) AS session_revenue
    FROM {{ ref('fct_item_performance') }}
    GROUP BY 1, 2, 3
),

traffic AS (
    SELECT
        user_pseudo_id,
        session_number,
        ANY_VALUE(traffic_source) AS traffic_source,
        ANY_VALUE(traffic_medium) AS traffic_medium,
        ANY_VALUE(traffic_campaign) AS traffic_campaign
    FROM {{ ref('fct_traffic_sources') }}
    GROUP BY 1, 2
),

landing AS (
    SELECT
        user_pseudo_id,
        session_number,
        ANY_VALUE(landing_page) AS landing_page
    FROM {{ ref('fct_landing_pages') }}
    GROUP BY 1, 2
),

combined AS (
    SELECT
        s.user_pseudo_id,
        s.session_number,
        s.event_date,

        COALESCE(e.total_events, 0) AS total_events,
        COALESCE(e.total_pageviews, 0) AS total_pageviews,
        COALESCE(r.session_revenue, 0) AS total_revenue,

        t.traffic_source,
        t.traffic_medium,
        t.traffic_campaign,
        l.landing_page

    FROM sessions s

    LEFT JOIN event_metrics e
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
),

daily_metrics AS (
    SELECT
        event_date,

        COUNT(DISTINCT user_pseudo_id) AS daily_active_users,

        COUNT(
            DISTINCT CONCAT(
                CAST(user_pseudo_id AS STRING),
                '-',
                CAST(session_number AS STRING)
            )
        ) AS daily_sessions,

        SUM(total_events) AS daily_events,
        SUM(total_pageviews) AS daily_pageviews,
        SUM(total_revenue) AS daily_revenue

    FROM combined
    GROUP BY event_date
),

landing_counts AS (
    SELECT
        event_date,
        landing_page,
        COUNT(*) AS landing_count
    FROM combined
    WHERE landing_page IS NOT NULL
    GROUP BY event_date, landing_page
),

top_landing_pages AS (
    SELECT
        event_date,
        ARRAY_AGG(
            landing_page
            ORDER BY landing_count DESC, landing_page
            LIMIT 1
        )[SAFE_OFFSET(0)] AS top_landing_page
    FROM landing_counts
    GROUP BY event_date
),

traffic_counts AS (
    SELECT
        event_date,
        traffic_source,
        COUNT(*) AS traffic_count
    FROM combined
    WHERE traffic_source IS NOT NULL
    GROUP BY event_date, traffic_source
),

top_traffic_sources AS (
    SELECT
        event_date,
        ARRAY_AGG(
            traffic_source
            ORDER BY traffic_count DESC, traffic_source
            LIMIT 1
        )[SAFE_OFFSET(0)] AS top_traffic_source
    FROM traffic_counts
    GROUP BY event_date
)

SELECT
    d.event_date,
    d.daily_active_users,
    d.daily_sessions,
    d.daily_events,
    d.daily_pageviews,
    d.daily_revenue,
    l.top_landing_page,
    t.top_traffic_source

FROM daily_metrics d

LEFT JOIN top_landing_pages l
    USING (event_date)

LEFT JOIN top_traffic_sources t
    USING (event_date)

ORDER BY d.event_date