{{ config(materialized='table') }}

WITH raw_purchase AS (
    SELECT * FROM kba_bronze.purchase_order
)

SELECT
    toInt32OrNull(id) AS id_pembelian,
    name AS nomor_nota_beli,
    toDateTime64OrNull(date_order) AS tanggal_transaksi,
    toFloat64OrNull(amount_total) AS total_belanja,
    state AS status_transaksi

FROM raw_purchase
WHERE id IS NOT NULL AND id != ''
  AND toDateTime64OrNull(date_order) IS NOT NULL