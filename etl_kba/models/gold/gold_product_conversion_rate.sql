{{ config(materialized='table') }}

WITH raw_data AS (
    SELECT
        id_produk,
        periode_bulan,
        status_transaksi,
        qty,
        nilai_subtotal
    FROM {{ ref('silver_sale_order_line') }}
),

product_metrics AS (
    SELECT
        periode_bulan,
        id_produk,
        -- 1. Total Penawaran (Penyebut: Semua status)
        SUM(qty) AS total_qty_quotation,
        SUM(nilai_subtotal) AS total_nilai_quotation,
        
        -- 2. Total Penjualan Aktual (Pembilang: Hanya yang laku)
        SUM(CASE WHEN status_transaksi IN ('sale', 'done') THEN qty ELSE 0 END) AS total_qty_aktual,
        SUM(CASE WHEN status_transaksi IN ('sale', 'done') THEN nilai_subtotal ELSE 0 END) AS total_nilai_aktual
    FROM raw_data
    GROUP BY 1, 2
)

SELECT
    m.periode_bulan,
    m.id_produk,
    -- Ambil nama produk dari silver_products
    extract(p.nama_produk, '\'en_US\': \'([^/]+)\'') AS nama_produk,
    
    m.total_qty_quotation,
    m.total_nilai_quotation,
    m.total_qty_aktual,
    m.total_nilai_aktual,
    
    -- Conversion Rate Qty (%)
    (m.total_qty_aktual / NULLIF(m.total_qty_quotation, 0)) * 100 AS conversion_rate_qty,
    
    -- Conversion Rate Value (%)
    (m.total_nilai_aktual / NULLIF(m.total_nilai_quotation, 0)) * 100 AS conversion_rate_value

FROM product_metrics m
LEFT JOIN {{ ref('silver_products') }} p ON m.id_produk = p.id_produk
ORDER BY periode_bulan DESC, conversion_rate_qty DESC