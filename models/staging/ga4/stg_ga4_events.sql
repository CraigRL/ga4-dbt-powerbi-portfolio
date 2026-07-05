{{ config(
    materialized = 'view'
) }}

WITH source AS (
    SELECT
        event_date,
        event_timestamp,
        event_name,
        user_pseudo_id,
        event_params,
        items
    FROM {{ source('ga4', 'events_*') }}
),

-- Flatten event parameters
event_params_flat AS (
    SELECT
        s.event_date,
        s.event_timestamp,
        s.event_name,
        s.user_pseudo_id,
        ep.key AS param_name,
        ep.value.string_value AS param_value_string,
        ep.value.int_value AS param_value_int,
        ep.value.float_value AS param_value_float,
        ep.value.double_value AS param_value_double,
        s.items
    FROM source s,
    UNNEST(s.event_params) ep
),

-- Extract session fields
session_fields AS (
    SELECT
        user_pseudo_id,
        event_timestamp,
        MAX(CASE WHEN param_name = 'ga_session_id' THEN param_value_int END) AS session_id,
        MAX(CASE WHEN param_name = 'ga_session_number' THEN param_value_int END) AS session_number
    FROM event_params_flat
    GROUP BY 1,2
)

SELECT
    s.event_date,
    s.event_timestamp,
    s.event_name,
    s.user_pseudo_id,
    s.event_params,
    s.items,
    sf.session_id,
    sf.session_number
FROM source s
LEFT JOIN session_fields sf
    ON s.user_pseudo_id = sf.user_pseudo_id
    AND s.event_timestamp = sf.event_timestamp