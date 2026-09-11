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

events AS (
    SELECT
        user_pseudo_id,
        event_timestamp,
        event_name,
        event_date
    FROM {{ ref('fct_events') }}
),

-- Extract traffic parameters from event_params
traffic_params AS (
    SELECT
        ep.user_pseudo_id,
        ep.event_timestamp,

        MAX(CASE WHEN ep.param_name = 'source' THEN ep.param_value END) AS traffic_source,
        MAX(CASE WHEN ep.param_name = 'medium' THEN ep.param_value END) AS traffic_medium,
        MAX(CASE WHEN ep.param_name = 'campaign' THEN ep.param_value END) AS traffic_campaign
    FROM {{ ref('stg_ga4_event_params') }} ep
    GROUP BY 1,2
),

-- Join events to traffic params
events_with_traffic AS (
    SELECT
        e.*,
        tp.traffic_source,
        tp.traffic_medium,
        tp.traffic_campaign
    FROM events e
    LEFT JOIN traffic_params tp
        ON e.user_pseudo_id = tp.user_pseudo_id
        AND e.event_timestamp = tp.event_timestamp
),

-- Assign session-level attribution using the first non-null
-- source, medium, and campaign observed within each session window

session_traffic AS (
    SELECT
        s.user_pseudo_id,
        s.session_number,
        s.session_start,
        s.session_end,

        -- First non-null traffic params observed during the session
        ARRAY_AGG(
            e.traffic_source IGNORE NULLS
            ORDER BY e.event_timestamp
            LIMIT 1
        )[SAFE_OFFSET(0)] AS traffic_source,

        ARRAY_AGG(
            e.traffic_medium IGNORE NULLS
            ORDER BY e.event_timestamp
            LIMIT 1
        )[SAFE_OFFSET(0)] AS traffic_medium,

        ARRAY_AGG(
            e.traffic_campaign IGNORE NULLS
            ORDER BY e.event_timestamp
            LIMIT 1
        )[SAFE_OFFSET(0)] AS traffic_campaign

    FROM sessions s
    LEFT JOIN events_with_traffic e
        ON s.user_pseudo_id = e.user_pseudo_id
        AND TIMESTAMP_MICROS(e.event_timestamp)
            BETWEEN s.session_start AND s.session_end

    GROUP BY
        s.user_pseudo_id,
        s.session_number,
        s.session_start,
        s.session_end
),

-- Identify the first pageview in each session as the landing page

landing_page AS (
    SELECT
        user_pseudo_id,
        session_number,
        page_location AS landing_page
    FROM {{ ref('fct_pageviews') }}
    WHERE pageview_index = 1
)

SELECT
    st.user_pseudo_id,
    st.session_number,
    st.session_start,
    st.session_end,

    st.traffic_source,
    st.traffic_medium,
    st.traffic_campaign,

    lp.landing_page

FROM session_traffic st
LEFT JOIN landing_page lp
    ON st.user_pseudo_id = lp.user_pseudo_id
    AND st.session_number = lp.session_number

ORDER BY st.user_pseudo_id, st.session_number
