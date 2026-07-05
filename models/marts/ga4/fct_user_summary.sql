{{ config(
    materialized = 'view'
) }}

WITH sessions AS (
    SELECT
        user_pseudo_id,
        session_number,
        session_start,
        session_end,
        DATETIME_DIFF(session_end, session_start, SECOND) AS session_length_seconds
    FROM {{ ref('fct_sessions') }}
),

engagement AS (
    SELECT
        user_pseudo_id,
        session_number,
        total_events,
        total_pageviews,
        unique_pages_viewed
    FROM {{ ref('fct_engagement') }}
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

exit_pages AS (
    SELECT
        user_pseudo_id,
        session_number,
        exit_page
    FROM {{ ref('fct_exit_pages') }}
),

revenue AS (
    SELECT
        user_pseudo_id,
        session_number,
        SUM(item_revenue) AS session_revenue
    FROM {{ ref('fct_item_performance') }}
    GROUP BY 1,2
),

combined AS (
    SELECT
        s.user_pseudo_id,
        s.session_number,
        s.session_length_seconds,

        e.total_events,
        e.total_pageviews,
        e.unique_pages_viewed,

        t.traffic_source,
        t.traffic_medium,
        t.traffic_campaign,

        l.landing_page,
        x.exit_page,

        r.session_revenue
    FROM sessions s
    LEFT JOIN engagement e USING (user_pseudo_id, session_number)
    LEFT JOIN traffic t USING (user_pseudo_id, session_number)
    LEFT JOIN landing l USING (user_pseudo_id, session_number)
    LEFT JOIN exit_pages x USING (user_pseudo_id, session_number)
    LEFT JOIN revenue r USING (user_pseudo_id, session_number)
),

-- Most common landing page per user
landing_mode AS (
    SELECT
        user_pseudo_id,
        landing_page AS mode_landing_page,
        COUNT(*) AS freq,
        ROW_NUMBER() OVER (
            PARTITION BY user_pseudo_id
            ORDER BY COUNT(*) DESC
        ) AS rn
    FROM combined
    GROUP BY 1,2
),

-- Most common exit page per user
exit_mode AS (
    SELECT
        user_pseudo_id,
        exit_page AS mode_exit_page,
        COUNT(*) AS freq,
        ROW_NUMBER() OVER (
            PARTITION BY user_pseudo_id
            ORDER BY COUNT(*) DESC
        ) AS rn
    FROM combined
    GROUP BY 1,2
),

-- Aggregate to user level
user_agg AS (
    SELECT
        user_pseudo_id,

        -- Sessions
        COUNT(*) AS total_sessions,
        AVG(session_length_seconds) AS avg_session_length_seconds,

        -- Engagement
        SUM(total_events) AS total_events,
        SUM(total_pageviews) AS total_pageviews,
        SUM(unique_pages_viewed) AS total_unique_pages_viewed,

        -- Revenue
        SUM(session_revenue) AS total_revenue,
        AVG(session_revenue) AS avg_revenue_per_session,

        -- Acquisition (first session)
        MIN_BY(traffic_source, session_number) AS first_traffic_source,
        MIN_BY(traffic_medium, session_number) AS first_traffic_medium,
        MIN_BY(traffic_campaign, session_number) AS first_traffic_campaign,
        MIN_BY(landing_page, session_number) AS first_landing_page

    FROM combined
    GROUP BY user_pseudo_id
)

SELECT
    ua.*,
    lm.mode_landing_page AS most_common_landing_page,
    em.mode_exit_page AS most_common_exit_page

FROM user_agg ua
LEFT JOIN landing_mode lm
    ON ua.user_pseudo_id = lm.user_pseudo_id
    AND lm.rn = 1
LEFT JOIN exit_mode em
    ON ua.user_pseudo_id = em.user_pseudo_id
    AND em.rn = 1

ORDER BY ua.user_pseudo_id