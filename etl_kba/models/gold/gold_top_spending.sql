{{ config(materialized='table') }}

WITH product_spending AS (
    SELECT 
        toStartOfMonth(tanggal_transaksi) AS periode_bulan,
        id_produk,
        nama_produk,
        SUM(total_belanja) AS total_pengeluaran_produk,
        SUM(qty_beli) AS total_qty_produk,
        harga_satuan
    FROM {{ ref('silver_purchase_detail') }} -- Pastikan ada layer silver untuk detail PO
    WHERE status_transaksi IN ('purchase', 'done')
    GROUP BY 1, 2, 3, 6
)

SELECT 
    *,
    -- Membuat ranking berdasarkan pengeluaran terbesar per bulan
    rank() OVER (PARTITION BY periode_bulan ORDER BY total_pengeluaran_produk DESC) AS rank_pengeluaran
FROM product_spending