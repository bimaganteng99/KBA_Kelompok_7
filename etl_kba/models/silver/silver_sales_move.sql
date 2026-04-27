{{ config(materialized='table') }}

WITH stock_move AS (
    SELECT * FROM kba_bronze.stock_move
)

SELECT
    toInt32OrNull(toString(id)) AS id_move,
    toInt32OrNull(toString(product_id)) AS id_produk,

    toDateTime64OrNull(toString(date)) AS tanggal,
    toStartOfMonth(toDateTime64OrNull(toString(date))) AS periode_bulan,

    toFloat64OrNull(toString(quantity)) AS qty, 

    toFloat64OrNull(toString(price_unit)) AS price_unit,

    toFloat64OrNull(toString(quantity)) * toFloat64OrNull(toString(price_unit)) AS nilai_penjualan_proxy,

    sale_line_id

FROM stock_move

WHERE sale_line_id IS NOT NULL
  AND toFloat64OrNull(toString(quantity)) > 0