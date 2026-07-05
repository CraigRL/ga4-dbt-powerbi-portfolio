{{ config(
    materialized = 'view'
) }}

WITH source AS (
    SELECT
        event_date,
        event_timestamp,
        event_name,
        user_pseudo_id,
        items
    FROM {{ source('ga4', 'events_*') }}
),

flattened AS (
    SELECT
        s.event_date,
        s.event_timestamp,
        s.event_name,
        s.user_pseudo_id,
        item.item_id,
        item.item_name,
        item.item_brand,
        item.item_category,
        item.item_category2,
        item.item_category3,
        item.item_category4,
        item.item_category5,
        item.price,
        item.quantity,
        item.item_variant,
        item.item_list_name,
        item.item_list_id,
        item.promotion_id,
        item.promotion_name,
        item.coupon
    FROM source s,
    UNNEST(s.items) AS item
)

SELECT *
FROM flattened