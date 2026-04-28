{{ config(materialized='table') }}

WITH po_header AS (
    SELECT 
        toInt32OrNull(toString(id)) AS id_purchase,
        name AS nomor_po,
        partner_id AS id_vendor,
        -- Menggunakan toDateTime64OrNull sesuai standar Anda sebelumnya
        toDateTime64OrNull(toString(date_order)) AS tanggal_transaksi,
        state AS status_transaksi
    FROM kba_bronze.purchase_order
),

po_line AS (
    SELECT
        toInt32OrNull(toString(order_id)) AS id_purchase,
        toInt32OrNull(toString(product_id)) AS id_produk,
        toFloat64OrNull(toString(product_qty)) AS qty_beli,
        toFloat64OrNull(toString(price_unit)) AS harga_satuan,
        (toFloat64OrNull(toString(product_qty)) * toFloat64OrNull(toString(price_unit))) AS subtotal_item
    FROM kba_bronze.purchase_order_line
),

-- Jembatan untuk mendapatkan Nama dari Template via Variant
products_lookup AS (
    SELECT 
        toInt32OrNull(toString(pp.id)) AS id_produk,
        -- Nama aslinya ada di Template
        extract(pt.name, '\'en_US\': \'([^/]+)\'') AS nama_produk
    FROM kba_bronze.product_product pp
    LEFT JOIN kba_bronze.product_template pt ON pp.product_tmpl_id = pt.id
)

SELECT
    h.tanggal_transaksi,
    h.nomor_po,
    h.status_transaksi,
    h.id_vendor,
    l.id_produk AS id_produk,
    p.nama_produk,
    l.qty_beli,
    l.harga_satuan,
    l.subtotal_item AS total_belanja 
FROM po_line l
LEFT JOIN po_header h ON l.id_purchase = h.id_purchase
LEFT JOIN products_lookup p ON l.id_produk = p.id_produk