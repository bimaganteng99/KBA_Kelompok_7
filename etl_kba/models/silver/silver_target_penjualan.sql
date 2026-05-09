{{ config(materialized='table') }}

WITH raw_target AS (
    SELECT * FROM kba_bronze.target_penjualan
)

SELECT
    toDateOrNull(month) AS periode_bulan,
    toFloat64OrNull(target_sales) AS target_penjualan

FROM raw_target
WHERE month IS NOT NULL AND month != ''