{{ config(materialized='table') }}

WITH calendar AS (
  SELECT DISTINCT dateTrunc('month', toDate(d)) AS start_of_month, 
  dateAdd(month, 1, dateTrunc('month', toDate(d))) - interval 1 day AS end_of_month
    FROM (
        SELECT toDate('2026-03-01') AS d
        UNION ALL SELECT toDate('2026-04-01')
        UNION ALL SELECT toDate('2026-05-01')
    )
),

products AS (
    SELECT 
        id_produk,
        nama_produk
    FROM {{ ref('silver_products') }} 
),

valuation_layers AS (
    SELECT
        id_produk,
        quantity,
        value,
        toDate(created_at) AS created_date
    FROM {{ ref('silver_stock_valuation') }} 
),

product_monthly_grid AS (
    SELECT 
        c.start_of_month,
        c.end_of_month,
        p.id_produk,
        p.nama_produk
    FROM calendar c
    CROSS JOIN products p
),

final_calculation AS (
    SELECT 
        grid.start_of_month AS periode_bulan,
        -- grid.end_of_month,
        grid.id_produk,
        grid.nama_produk,
        -- Menggunakan conditional aggregation untuk menghindari error Join
        SUM(IF(vl.created_date <= grid.end_of_month, vl.quantity, 0)) AS qty_on_hand,
        SUM(IF(vl.created_date <= grid.end_of_month, vl.value, 0)) AS total_value
    FROM product_monthly_grid grid
    LEFT JOIN valuation_layers vl 
        ON grid.id_produk = vl.id_produk 
    GROUP BY 
        grid.start_of_month, 
        grid.id_produk, 
        grid.nama_produk
)

SELECT 
    periode_bulan,
    id_produk,
    nama_produk,
    round(qty_on_hand, 2) AS qty,
    round(total_value, 2) AS nilai_stok
FROM final_calculation
-- Menggunakan filter untuk menghilangkan row kosong
-- WHERE qty_on_hand != 0 OR total_value != 0
ORDER BY periode_bulan ASC, nilai_stok DESC