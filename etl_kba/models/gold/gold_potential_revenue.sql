{{ config(materialized='table') }}

WITH quotation_lines AS (
    SELECT
        -- Mengambil data produk dan qty dari sale_order_line
        toInt32OrNull(toString(sol.product_id)) AS id_produk,
        toInt32OrNull(toString(sol.order_id)) AS id_order,
        toFloat64OrNull(toString(sol.product_uom_qty)) AS qty,
        toFloat64OrNull(toString(sol.price_subtotal)) AS subtotal_potensi,
        
        -- Mengambil status dan tanggal dari sale_order
        so.state AS status_transaksi,
        toDateTime64OrNull(toString(so.date_order)) AS tanggal_quotation,
        toStartOfMonth(toDateTime64OrNull(toString(so.date_order))) AS periode_bulan

    FROM kba_bronze.sale_order_line sol
    LEFT JOIN kba_bronze.sale_order so ON sol.order_id = so.id
    
    -- Filter hanya untuk penawaran yang belum jadi sales
    WHERE so.state IN ('draft', 'sent')
      AND toFloat64OrNull(toString(sol.product_uom_qty)) > 0
),

aggregated AS (
    SELECT
        periode_bulan,
        id_produk,
        status_transaksi,
        sum(qty) AS total_qty_penawaran,
        sum(subtotal_potensi) AS total_nilai_potensi,
        count(DISTINCT id_order) AS jumlah_unique_quotation
    FROM quotation_lines
    GROUP BY 1, 2, 3
)

SELECT 
    a.*,
    sm.demand_segment -- Ambil dari gold_slow_moving
FROM aggregated a
LEFT JOIN {{ source('external_python', 'silver_slow_moving_bulanan') }} sm 
    ON a.id_produk = sm.id_produk 
    AND a.periode_bulan = sm.periode_bulan
    AND sm.snapshot_type = 'Historical'
ORDER BY 
    periode_bulan DESC, 
    total_nilai_potensi DESC