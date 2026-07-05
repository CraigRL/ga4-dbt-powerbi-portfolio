{{ config(
    materialized = 'view'
) }}

WITH pageviews AS (
    SELECT
        page_location,
        event_date,
        user_pseudo_id,
        session_number
    FROM {{ ref('fct_pageviews') }}
),

events AS (
    SELECT
        page_location,
        event_date,
        user_pseudo_id,
        session_number,
        event_name
    FROM {{ ref('fct_events') }}
),

items AS (
    SELECT
        page_location,
        event_date,
        user_pseudo_id,
        session_number,
        item_revenue
    FROM {{ ref('fct_item_performance') }}
),

-- Aggregate pageviews
pv_agg AS (
    SELECT
        page_location,
        event_date,
        COUNT(*) AS pageviews,
        COUNT(DISTINCT user_pseudo_id) AS unique_users,
        COUNT(DISTINCT session_number) AS sessions
    FROM pageviews
    GROUP BY 1,2
),

-- Aggregate events (for engagement + conversions)
ev_agg AS (
    SELECT
        page_location,
        event_date,
        COUNT(*) AS total_events,
        COUNTIF(event_name = 'purchase') AS purchases,
        COUNTIF(event_name = 'add_to_cart') AS add_to_cart_events
    FROM events
    GROUP BY 1,2
),

-- Aggregate item revenue
item_agg AS (
    SELECT
        page_location,
        event_date,
        SUM(item_revenue) AS total_revenue
    FROM items
    GROUP BY 1,2
)

SELECT
    p.page_location,
    p.event_date,

    -- Pageview metrics
    p.pageviews,
    p.unique_users,
    p.sessions,

    -- Event metrics
    e.total_events,
    e.add_to_cart_events,
    e.purchases,

    -- Revenue
    i.total_revenue

FROM pv_agg p
LEFT JOIN ev_agg e
    ON p.page_location = e.page_location
    AND p.event_date = e.event_date
LEFT JOIN item_agg i
    ON p.page_location = i.page_location
    AND p.event_date = i.event_date

ORDER BY p.event_date, p.page_location