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
        PARSE_DATE('%Y%m%d', CAST(event_date AS STRING)) AS event_date
    FROM {{ ref('stg_ga4_events') }}
    WHERE event_name = 'page_view'
),

page_params AS (
    SELECT
        ep.user_pseudo_id,
        ep.event_timestamp,
        MAX(CASE WHEN ep.param_name = 'page_location' THEN ep.param_value END) AS page_location,
        MAX(CASE WHEN ep.param_name = 'page_title' THEN ep.param_value END) AS page_title,
        MAX(CASE WHEN ep.param_name = 'page_referrer' THEN ep.param_value END) AS page_referrer
    FROM {{ ref('stg_ga4_event_params') }} ep
    GROUP BY 1,2
),

events_with_pages AS (
    SELECT
        e.*,
        pp.page_location,
        pp.page_title,
        pp.page_referrer,
        dp.page_key
    FROM events e
    LEFT JOIN page_params pp
        ON e.user_pseudo_id = pp.user_pseudo_id
        AND e.event_timestamp = pp.event_timestamp
    LEFT JOIN {{ ref('dim_pages') }} dp
        ON dp.page_location = pp.page_location
),

events_with_session AS (
    SELECT
        ewp.*,
        s.session_number,
        s.session_start,
        s.session_end
    FROM events_with_pages ewp
    JOIN sessions s
        ON ewp.user_pseudo_id = s.user_pseudo_id
        AND TIMESTAMP_MICROS(ewp.event_timestamp)
            BETWEEN s.session_start AND s.session_end
),

ordered AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY user_pseudo_id, session_number
            ORDER BY event_timestamp
        ) AS pageview_index
    FROM events_with_session
)

SELECT
    user_pseudo_id,
    session_number,
    pageview_index,

    -- Page metadata
    page_location,
    page_title,
    page_referrer,
    page_key,

    -- Event timestamps
    event_timestamp,
    DATETIME(TIMESTAMP_MICROS(event_timestamp)) AS event_datetime,
    event_date,

    -- Session timestamps
    session_start,
    session_end

FROM ordered
ORDER BY user_pseudo_id, session_number, pageview_index