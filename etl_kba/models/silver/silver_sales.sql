{{ config(materialized='table') }}

WITH raw_sales AS (
    SELECT * FROM kba_bronze.sale_order
)

SELECT
    toInt32OrNull(id) AS id_penjualan,
    name AS nomor_nota,
    toDateTime64OrNull(date_order) AS tanggal_transaksi,
    toFloat64OrNull(amount_total) AS total_belanja,
    state AS status_transaksi

FROM raw_sales
WHERE id IS NOT NULL AND id != ''
  AND toDateTime64OrNull(date_order) IS NOT NULL