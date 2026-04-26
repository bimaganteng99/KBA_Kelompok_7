{{ config(materialized='table') }}

WITH raw_inventory AS (
    SELECT * FROM kba_bronze.stock_quant
)

SELECT
    toInt32OrNull(id) AS id_stok,
    toInt32OrNull(product_id) AS id_produk,
    toInt32OrNull(location_id) AS id_lokasi,
    toFloat64OrNull(quantity) AS jumlah_stok

FROM raw_inventory
WHERE id IS NOT NULL AND id != ''
  AND toFloat64OrNull(quantity) IS NOT NULL