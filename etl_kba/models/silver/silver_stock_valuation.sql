{{ config(materialized='table') }}

WITH raw AS (
    SELECT * FROM kba_bronze.stock_valuation_layer
)

SELECT
    toInt32OrNull(id) AS id_valuation_layer,

    toInt32OrNull(product_id)     AS id_produk,
    toInt32OrNull(company_id)     AS id_company,
    toInt32OrNull(categ_id)       AS id_kategori,
    toInt32OrNull(stock_move_id)  AS id_stock_move,
    toInt32OrNull(account_move_id) AS id_account_move,

    NULLIF(description, '') AS description,

    toFloat64OrNull(quantity)         AS quantity,
    toFloat64OrNull(unit_cost)        AS unit_cost,
    toFloat64OrNull(value)            AS value,
    toFloat64OrNull(remaining_qty)    AS remaining_qty,
    toFloat64OrNull(remaining_value)  AS remaining_value,
    toFloat64OrNull(price_diff_value) AS price_diff_value,

    toDateTimeOrNull(create_date) AS created_at,
    toDateTimeOrNull(write_date)  AS updated_at

FROM raw
WHERE id IS NOT NULL AND id != ''