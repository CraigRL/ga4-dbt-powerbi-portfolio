{{ config(
    materialized = 'view'
) }}

WITH items AS (
    SELECT
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

-- Deduplicate items by item_id
deduped AS (
    SELECT
        item_id,

        ANY_VALUE(item_name) AS item_name,
        ANY_VALUE(item_brand) AS item_brand,

        ANY_VALUE(item_category) AS item_category,
        ANY_VALUE(item_category2) AS item_category2,
        ANY_VALUE(item_category3) AS item_category3,
        ANY_VALUE(item_category4) AS item_category4,

        ANY_VALUE(item_variant) AS item_variant,

        -- Price is often inconsistent across events; choose the most common
        ANY_VALUE(price) AS default_price
    FROM items
    WHERE item_id IS NOT NULL
    GROUP BY item_id
)

SELECT
    -- Surrogate key
    TO_HEX(SHA256(CAST(item_id AS STRING))) AS item_key,

    item_id,
    item_name,
    item_brand,

    item_category,
    item_category2,
    item_category3,
    item_category4,

    item_variant,
    default_price

FROM deduped
ORDER BY item_id