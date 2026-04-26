{{ config(materialized='table') }}

-- Snapshot nilai stok per akhir bulan per produk dari silver_stock_valuation (remaining_value)
-- Ambil record terakhir (created_at paling besar) di bulan tsb

WITH v AS (
    SELECT
        id_produk,
        toDate(toStartOfMonth(created_at)) AS periode_bulan,
        created_at,
        remaining_value
    FROM kba_silver.silver_stock_valuation
    WHERE id_produk IS NOT NULL
      AND created_at IS NOT NULL
      AND remaining_value IS NOT NULL
),
ranked AS (
    SELECT
        id_produk,
        periode_bulan,
        remaining_value,
        row_number() OVER (
            PARTITION BY id_produk, periode_bulan
            ORDER BY created_at DESC
        ) AS rn
    FROM v
)

SELECT
    periode_bulan,
    id_produk,
    greatest(remaining_value, 0) AS nilai_stok
FROM ranked
WHERE rn = 1