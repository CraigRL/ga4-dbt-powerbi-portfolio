{{ config(
    materialized = 'view'
) }}

WITH events AS (
    SELECT
        user_pseudo_id,
        event_timestamp,
        event_name,
        event_date,
        session_number,
        page_location
    FROM {{ ref('fct_events') }}
),

items AS (
    SELECT
        user_pseudo_id,
        event_timestamp,
        item_id,
        item_name,
        item_brand,
        item_category,
        item_category2,
        item_category3,
        item_category4,
        item_variant,
        price,
        quantity
    FROM {{ ref('stg_ga4_items') }}
),

joined AS (
    SELECT
        e.user_pseudo_id,
        e.session_number,
        e.event_timestamp,
        DATETIME(TIMESTAMP_MICROS(e.event_timestamp)) AS event_datetime,
        e.event_name,
        e.event_date,
        e.page_location,

        i.item_id,
        i.item_name,
        i.item_brand,
        i.item_category,
        i.item_category2,
        i.item_category3,
        i.item_category4,
        i.item_variant,

        i.price,
        i.quantity,

        SAFE_MULTIPLY(CAST(i.price AS FLOAT64), i.quantity) AS item_revenue
    FROM items i
    JOIN events e
        ON i.user_pseudo_id = e.user_pseudo_id
        AND i.event_timestamp = e.event_timestamp
)

SELECT
    user_pseudo_id,
    session_number,
    event_timestamp,
    event_datetime,
    event_name,
    event_date,
    page_location,

    item_id,
    item_name,
    item_brand,
    item_category,
    item_category2,
    item_category3,
    item_category4,
    item_variant,

    price,
    quantity,
    item_revenue

FROM joined
ORDER BY user_pseudo_id, session_number, event_timestamp, item_id