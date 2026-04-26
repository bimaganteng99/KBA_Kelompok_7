{{ config(materialized='table') }}

WITH sales_data AS (
    SELECT 
        toStartOfMonth(tanggal_transaksi) AS periode_bulan,
        status_transaksi,
        sum(total_belanja) AS total_nilai
    FROM {{ ref('silver_sales') }}
    GROUP BY 1, 2
),

achievement AS (
    SELECT 
        s.periode_bulan,
        sum(CASE WHEN s.status_transaksi IN ('sale', 'done') THEN s.total_nilai ELSE 0 END) AS aktual_penjualan,
        sum(CASE WHEN s.status_transaksi != 'cancel' THEN s.total_nilai ELSE 0 END) AS total_quotation,
        t.target_penjualan
    FROM sales_data s
    LEFT JOIN {{ ref('silver_target_penjualan') }} t ON s.periode_bulan = t.periode_bulan
    GROUP BY 1, t.target_penjualan
)

SELECT 
    *,
    -- Sales Achievement Rate
    (aktual_penjualan / NULLIF(target_penjualan, 0)) * 100 AS achievement_rate,
    -- Sales Conversion Rate
    (aktual_penjualan / NULLIF(total_quotation, 0)) * 100 AS conversion_rate
FROM achievement