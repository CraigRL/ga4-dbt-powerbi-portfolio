{{ config(
    materialized = 'view'
) }}

WITH journey AS (
    SELECT
        user_pseudo_id,
        session_number,
        event_index,
        event_name,
        page_location,
        event_timestamp
    FROM {{ ref('fct_user_journey') }}
),

-- Define funnel steps here
funnel_steps AS (
    SELECT 'view_product' AS step_name, 'view_item' AS event_name, 1 AS step_order UNION ALL
    SELECT 'add_to_cart', 'add_to_cart', 2 UNION ALL
    SELECT 'begin_checkout', 'begin_checkout', 3 UNION ALL
    SELECT 'purchase', 'purchase', 4
),

-- Match events to funnel steps
matched AS (
    SELECT
        j.user_pseudo_id,
        j.session_number,
        f.step_name,
        f.step_order,
        j.event_timestamp,
        j.event_index,
        j.page_location
    FROM journey j
    JOIN funnel_steps f
        ON j.event_name = f.event_name
),

-- First occurrence of each step per session
first_step AS (
    SELECT
        user_pseudo_id,
        session_number,
        step_name,
        step_order,
        MIN(event_timestamp) AS step_timestamp
    FROM matched
    GROUP BY 1,2,3,4
)

SELECT
    user_pseudo_id,
    session_number,
    step_name,
    step_order,
    step_timestamp,
    DATETIME(TIMESTAMP_MICROS(step_timestamp)) AS step_datetime
FROM first_step
ORDER BY user_pseudo_id, session_number, step_order