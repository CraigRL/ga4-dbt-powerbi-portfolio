{{ config(
    materialized = 'table'
) }}

WITH base AS (
    SELECT
        user_pseudo_id,
        session_number,
        event_timestamp,
        page_location,
        page_title,
        page_referrer,
        pageview_index
    FROM {{ ref('fct_pageviews') }}
),

-- Normalize URLs by removing query parameters and fragments
-- so equivalent page locations share the same page key

normalized AS (
    SELECT
        user_pseudo_id,
        session_number,
        pageview_index,
        event_timestamp,

        page_location,
        page_title,
        page_referrer,

        -- remove query params and fragments, lowercase
        LOWER(REGEXP_REPLACE(page_location, r'(\?|#).*$', '')) AS normalized_page
    FROM base
),

-- Build page-to-page transitions within each session;
-- a null to_page represents the final pageview (session exit)

ordered AS (
    SELECT
        user_pseudo_id,
        session_number,
        pageview_index,

        normalized_page AS from_page,
        LEAD(normalized_page) OVER (
            PARTITION BY user_pseudo_id, session_number
            ORDER BY pageview_index
        ) AS to_page
    FROM normalized
),

-- Generate surrogate keys
with_keys AS (
    SELECT
        user_pseudo_id,
        session_number,
        pageview_index,

        from_page,
        to_page,

        TO_HEX(SHA256(from_page)) AS from_page_key,
        CASE
            WHEN to_page IS NULL THEN NULL
            ELSE TO_HEX(SHA256(to_page))
        END AS to_page_key
    FROM ordered
)

SELECT *
FROM with_keys
ORDER BY user_pseudo_id, session_number, pageview_index
