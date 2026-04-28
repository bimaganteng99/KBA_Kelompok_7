{{ config(materialized='table') }}

WITH base AS (
    SELECT
        toInt32OrNull(trim(BOTH ' ' FROM sml.product_id)) AS id_produk,
        toDate(toStartOfMonth(toDateTime64OrNull(sml.date))) AS periode_bulan,
        toFloat64OrNull(sml.quantity) AS qty,
        toDateTime64OrNull(sml.date) AS tanggal_pergerakan,

        lowerUTF8(trim(BOTH ' ' FROM sml.state)) AS status_move_line,
        lowerUTF8(trim(BOTH ' ' FROM sp.state))  AS status_picking,
        lowerUTF8(trim(BOTH ' ' FROM spt.code))  AS kode_tipe_picking

    FROM kba_bronze.stock_move_line sml
    LEFT JOIN kba_bronze.stock_move sm
        ON toInt32OrNull(trim(BOTH ' ' FROM sml.move_id))
         = toInt32OrNull(trim(BOTH ' ' FROM sm.id))
    LEFT JOIN kba_bronze.stock_picking sp
        ON toInt32(ifNull(toFloat64OrNull(trim(BOTH ' ' FROM sm.picking_id)), -1))
         = toInt32OrNull(trim(BOTH ' ' FROM sp.id))
    LEFT JOIN kba_bronze.stock_picking_type spt
        ON toInt32OrNull(trim(BOTH ' ' FROM sp.picking_type_id))
         = toInt32OrNull(trim(BOTH ' ' FROM spt.id))

    WHERE sml.id IS NOT NULL AND sml.id != ''
)

SELECT
    id_produk,
    periode_bulan,
    count() AS frekuensi_transaksi,
    sum(qty) AS total_qty_terjual_keluar,
    avg(qty) AS rata2_qty_per_transaksi,
    max(qty) AS max_qty_per_transaksi,
    dateDiff(
        'day',
        max(tanggal_pergerakan),
        now()
    ) AS jeda_hari_dari_transaksi_terakhir
FROM base
WHERE status_move_line = 'done'
  AND status_picking = 'done'
  AND kode_tipe_picking = 'outgoing'
  AND id_produk IS NOT NULL
  AND periode_bulan IS NOT NULL
GROUP BY id_produk, periode_bulan