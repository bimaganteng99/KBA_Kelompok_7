{{ config(materialized='table') }}

WITH v AS (
    SELECT
        id_produk,
        toStartOfMonth(toDate(created_at)) AS periode_bulan,
        remaining_value,
        created_at
    FROM {{ ref('silver_stock_valuation') }}
    WHERE remaining_value IS NOT NULL
),
ranked AS (
    SELECT
        id_produk,
        periode_bulan,
        argMax(remaining_value, created_at) AS nilai_stok_raw
    FROM v
    GROUP BY id_produk, periode_bulan
)

SELECT
    periode_bulan,
    id_produk,
    greatest(nilai_stok_raw, 0) AS nilai_stok
FROM ranked