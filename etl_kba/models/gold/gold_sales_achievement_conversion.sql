{{ config(materialized='table') }}

WITH actual_sales AS (
    SELECT 
        periode_bulan,
        sum(nilai_penjualan_proxy) AS total_aktual_sales
    FROM {{ ref('silver_sales_move') }}
    GROUP BY 1
),

quotation_data AS (
    SELECT 
        toStartOfMonth(tanggal_transaksi) AS periode_bulan,
        sum(total_belanja) AS total_quotation_value
    FROM {{ ref('silver_sales') }}
    WHERE status_transaksi != 'cancel'
    GROUP BY 1
),

achievement AS (
    SELECT 
        COALESCE(s.periode_bulan, q.periode_bulan) as periode_bulan,
        COALESCE(s.total_aktual_sales, 0) AS aktual_penjualan,
        COALESCE(q.total_quotation_value, 0) AS total_quotation,
        t.target_penjualan
    FROM quotation_data q
    FULL OUTER JOIN actual_sales s ON q.periode_bulan = s.periode_bulan
    LEFT JOIN {{ ref('silver_target_penjualan') }} t ON COALESCE(s.periode_bulan, q.periode_bulan) = t.periode_bulan
)

SELECT 
    *,
    (aktual_penjualan / NULLIF(target_penjualan, 0)) * 100 AS achievement_rate,
    (aktual_penjualan / NULLIF(total_quotation, 0)) * 100 AS conversion_rate
FROM achievement