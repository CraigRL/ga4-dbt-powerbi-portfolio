{{ config(
    materialized = 'view'
) }}

WITH source AS (
    SELECT
        event_date,
        event_timestamp,
        event_name,
        user_pseudo_id,
        event_params
    FROM {{ source('ga4', 'events_*') }}
),

flattened AS (
    SELECT
        s.event_date,
        s.event_timestamp,
        s.event_name,
        s.user_pseudo_id,
        ep.key AS param_name,
        COALESCE(
            ep.value.string_value,
            CAST(ep.value.int_value AS STRING),
            CAST(ep.value.float_value AS STRING),
            CAST(ep.value.double_value AS STRING)
        ) AS param_value
    FROM source s,
    UNNEST(s.event_params) ep
)

SELECT *
FROM flattened