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
        e.user_pseudo_id,
        e.event_timestamp,
        e.event_name,
        e.event_date
    FROM {{ ref('stg_ga4_events') }} e
),

-- Join events to sessions using session_number
events_with_session AS (
    SELECT
        e.*,
        s.session_number,
        s.session_start,
        s.session_end
    FROM events e
    JOIN sessions s
        ON e.user_pseudo_id = s.user_pseudo_id
        AND TIMESTAMP_MICROS(e.event_timestamp)
            BETWEEN s.session_start AND s.session_end
),

-- Extract page parameters for page_view events
page_params AS (
    SELECT
        ep.user_pseudo_id,
        ep.event_timestamp,
        MAX(CASE WHEN ep.param_name = 'page_location' THEN ep.param_value END) AS page_location,
        MAX(CASE WHEN ep.param_name = 'page_title' THEN ep.param_value END) AS page_title
    FROM {{ ref('stg_ga4_event_params') }} ep
    GROUP BY 1,2
),

-- Join page metadata
events_enriched AS (
    SELECT
        ews.*,
        pp.page_location,
        pp.page_title
    FROM events_with_session ews
    LEFT JOIN page_params pp
        ON ews.user_pseudo_id = pp.user_pseudo_id
        AND ews.event_timestamp = pp.event_timestamp
),

-- Add ordering within session
ordered AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY user_pseudo_id, session_number
            ORDER BY event_timestamp
        ) AS event_index
    FROM events_enriched
)

SELECT
    user_pseudo_id,
    session_number,
    event_index,

    -- Event details
    event_name,
    event_timestamp,
    DATETIME(TIMESTAMP_MICROS(event_timestamp)) AS event_datetime,
    event_date,

    -- Page metadata
    page_location,
    page_title,

    -- Session timestamps
    session_start,
    session_end

FROM ordered
ORDER BY user_pseudo_id, session_number, event_index