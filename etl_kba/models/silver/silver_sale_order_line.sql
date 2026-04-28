{{ config(materialized='table') }}

SELECT
    toInt32OrNull(id) AS id_line,
    toInt32OrNull(order_id) AS id_order,
    toInt32OrNull(product_id) AS id_produk,
    
    -- Pembersihan Tanggal
    toDateTime64OrNull(create_date) AS tanggal_dibuat,
    toStartOfMonth(toDateTime64OrNull(toString(so.date_order))) AS periode_bulan,
    
    -- Pembersihan Angka
    toFloat64OrNull(product_uom_qty) AS qty,
    toFloat64OrNull(price_unit) AS harga_satuan,
    toFloat64OrNull(price_subtotal) AS nilai_subtotal,
    
    -- Status tetap dibawa untuk filter di Layer Gold
    state AS status_transaksi

FROM kba_bronze.sale_order_line sol
LEFT JOIN kba_bronze.sale_order so ON sol.order_id = so.id
