{{ config(
    materialized = 'view'
) }}

WITH scroll_events AS (
    SELECT
        e.user_pseudo_id,
        e.event_timestamp,
        e.event_name,
        e.event_date
    FROM {{ ref('stg_ga4_events') }} e
    WHERE e.event_name = 'scroll'
),

scroll_params AS (
    SELECT
        ep.user_pseudo_id,
        ep.event_timestamp,
        MAX(CASE WHEN ep.param_name = 'percent_scrolled' THEN SAFE_CAST(ep.param_value AS FLOAT64) END)
            AS percent_scrolled
    FROM {{ ref('stg_ga4_event_params') }} ep
    GROUP BY 1,2
),

scroll_enriched AS (
    SELECT
        se.*,
        sp.percent_scrolled
    FROM scroll_events se
    LEFT JOIN scroll_params sp
        ON se.user_pseudo_id = sp.user_pseudo_id
        AND se.event_timestamp = sp.event_timestamp
),

sessions AS (
    SELECT
        user_pseudo_id,
        session_number,
        session_start,
        session_end
    FROM {{ ref('fct_sessions') }}
),

scroll_with_session AS (
    SELECT
        se.*,
        s.session_number,
        s.session_start,
        s.session_end
    FROM scroll_enriched se
    LEFT JOIN sessions s
        ON se.user_pseudo_id = s.user_pseudo_id
        AND TIMESTAMP_MICROS(se.event_timestamp)
            BETWEEN s.session_start AND s.session_end
),

page_params AS (
    SELECT
        ep.user_pseudo_id,
        ep.event_timestamp,
        MAX(CASE WHEN ep.param_name = 'page_location' THEN ep.param_value END) AS page_location
    FROM {{ ref('stg_ga4_event_params') }} ep
    GROUP BY 1,2
)

SELECT
    sws.user_pseudo_id,
    sws.session_number,
    sws.event_timestamp,
    DATETIME(TIMESTAMP_MICROS(sws.event_timestamp)) AS event_datetime,
    sws.event_date,

    pp.page_location,
    sws.percent_scrolled

FROM scroll_with_session sws
LEFT JOIN page_params pp
    ON sws.user_pseudo_id = pp.user_pseudo_id
    AND sws.event_timestamp = pp.event_timestamp

ORDER BY sws.user_pseudo_id, sws.session_number, sws.event_timestamp