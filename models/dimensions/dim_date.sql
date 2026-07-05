{{ config(
    materialized = 'table'
) }}

-- Set your date range here
WITH date_range AS (
    SELECT
        DATE('2020-01-01') AS start_date,
        DATE('2030-12-31') AS end_date
),

calendar AS (
    SELECT
        day AS date_day
    FROM date_range,
    UNNEST(GENERATE_DATE_ARRAY(start_date, end_date, INTERVAL 1 DAY)) AS day
)

SELECT
    date_day AS date,

    -- Basic components
    EXTRACT(YEAR FROM date_day) AS year,
    EXTRACT(QUARTER FROM date_day) AS quarter,
    EXTRACT(MONTH FROM date_day) AS month,
    EXTRACT(DAY FROM date_day) AS day,
    EXTRACT(DAYOFWEEK FROM date_day) AS day_of_week,
    EXTRACT(WEEK FROM date_day) AS week_of_year,

    -- Text labels
    FORMAT_DATE('%A', date_day) AS day_name,
    FORMAT_DATE('%B', date_day) AS month_name,
    FORMAT_DATE('%Y-%m', date_day) AS year_month,
    FORMAT_DATE('%Y-Q%q', date_day) AS year_quarter,

    -- Flags
    CASE WHEN EXTRACT(DAYOFWEEK FROM date_day) IN (1,7) THEN TRUE ELSE FALSE END AS is_weekend,
    CASE WHEN EXTRACT(DAYOFWEEK FROM date_day) IN (2,3,4,5,6) THEN TRUE ELSE FALSE END AS is_weekday,

    -- Month boundaries
    DATE_TRUNC(date_day, MONTH) AS month_start,
    LAST_DAY(date_day, MONTH) AS month_end,

    -- Quarter boundaries
    DATE_TRUNC(date_day, QUARTER) AS quarter_start,
    LAST_DAY(DATE_TRUNC(date_day, QUARTER) + INTERVAL 2 MONTH, MONTH) AS quarter_end,

    -- Year boundaries
    DATE_TRUNC(date_day, YEAR) AS year_start,
    DATE_FROM_UNIX_DATE(UNIX_DATE(DATE_TRUNC(date_day, YEAR)) + 364) AS approx_year_end

FROM calendar
ORDER BY date_day