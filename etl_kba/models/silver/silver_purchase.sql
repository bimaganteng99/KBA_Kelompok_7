{{ config(materialized='table') }}

WITH raw_purchase AS (
    SELECT * FROM kba_bronze.purchase_order
)

SELECT
    toInt32OrNull(id) AS id_pembelian,
    name AS nomor_nota_beli,
    toDateTimeOrNull(date_order) AS tanggal_transaksi,
    toFloat64OrNull(amount_total) AS total_belanja,
    state AS status_transaksi

FROM raw_purchase
WHERE id IS NOT NULL AND id != ''