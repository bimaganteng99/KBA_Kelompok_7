{{ config(materialized='table') }}

SELECT
    toInt32OrNull(toString(sol.id)) AS id_move,
    toInt32OrNull(toString(sol.product_id)) AS id_produk,
    toDateTime64OrNull(toString(so.date_order)) AS tanggal,
    toStartOfMonth(toDateTime64OrNull(toString(so.date_order))) AS periode_bulan,
    
    toFloat64OrNull(toString(sol.product_uom_qty)) AS qty, 
    toFloat64OrNull(toString(sol.price_unit)) AS price_unit,
    
    -- Menghitung nilai penjualan asli dari dokumen Sales
    toFloat64OrNull(toString(sol.product_uom_qty)) * toFloat64OrNull(toString(sol.price_unit)) AS nilai_penjualan_proxy,
    
    sol.id AS sale_line_id,
    so.state AS status_transaksi

FROM kba_bronze.sale_order_line sol
LEFT JOIN kba_bronze.sale_order so ON sol.order_id = so.id

WHERE so.state IN ('sale', 'done') -- Hanya ambil yang sudah jadi pesanan resmi
  AND toFloat64OrNull(toString(sol.product_uom_qty)) > 0