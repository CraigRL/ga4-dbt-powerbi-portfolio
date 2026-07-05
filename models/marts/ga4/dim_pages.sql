{{ config(
    materialized = 'table'
) }}

WITH page_params AS (
    SELECT
        ep.user_pseudo_id,
        ep.event_timestamp,
        MAX(CASE WHEN ep.param_name = 'page_location' THEN ep.param_value END) AS page_location,
        MAX(CASE WHEN ep.param_name = 'page_title' THEN ep.param_value END) AS page_title,
        MAX(CASE WHEN ep.param_name = 'page_referrer' THEN ep.param_value END) AS page_referrer
    FROM {{ ref('stg_ga4_event_params') }} ep
    GROUP BY 1,2
),

normalized AS (
    SELECT
        page_location,
        page_title,
        page_referrer,

        REGEXP_EXTRACT(page_location, r'https?://([^/]+)') AS hostname,
        REGEXP_EXTRACT(page_location, r'https?://[^/]+(.*)') AS page_path,

        LOWER(
            REGEXP_REPLACE(page_location, r'(\?|#).*$', '')
        ) AS normalized_location
    FROM page_params
    WHERE page_location IS NOT NULL
),

with_keys AS (
    SELECT
        *,
        TO_HEX(SHA256(normalized_location)) AS page_key
    FROM normalized
),

deduped AS (
    SELECT
        page_key,
        ANY_VALUE(page_location) AS page_location,
        ANY_VALUE(page_title) AS page_title,
        ANY_VALUE(page_referrer) AS page_referrer,
        ANY_VALUE(hostname) AS hostname,
        ANY_VALUE(page_path) AS page_path
    FROM with_keys
    GROUP BY page_key
)

SELECT *
FROM deduped
ORDER BY page_key