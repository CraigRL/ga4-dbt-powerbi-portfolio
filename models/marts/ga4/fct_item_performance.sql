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

    -- Ensure one event record per user/timestamp/event type
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY
            user_pseudo_id,
            event_timestamp,
            event_name
        ORDER BY session_number
    ) = 1
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

        -- Item value at any ecommerce stage
        SAFE_MULTIPLY(
            CAST(i.price AS FLOAT64),
            CAST(i.quantity AS FLOAT64)
        ) AS item_value,

        -- Realized revenue only for completed purchases
        CASE
            WHEN e.event_name = 'purchase'
            THEN SAFE_MULTIPLY(
                CAST(i.price AS FLOAT64),
                CAST(i.quantity AS FLOAT64)
            )
            ELSE 0
        END AS item_revenue

    FROM items i

    INNER JOIN events e
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
    item_value,
    item_revenue

FROM joined