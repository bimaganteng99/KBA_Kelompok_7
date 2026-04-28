{{ config(materialized='table') }}

WITH raw AS (
    SELECT * FROM kba_bronze.stock_move_line
)

SELECT
    toInt32OrNull(id) AS id_move_line,

    toInt32OrNull(picking_id) AS id_picking,
    toInt32OrNull(move_id)    AS id_move,
    toInt32OrNull(product_id) AS id_produk,
    toInt32OrNull(company_id) AS id_company,

    toInt32OrNull(location_id)      AS id_lokasi_asal,
    toInt32OrNull(location_dest_id) AS id_lokasi_tujuan,

    NULLIF(state, '')     AS status_move_line,
    NULLIF(reference, '') AS reference,
    NULLIF(description_picking, '') AS description_picking,
    NULLIF(lot_name, '')  AS lot_name,

    toFloat64OrNull(quantity)             AS quantity,
    toFloat64OrNull(quantity_product_uom) AS quantity_product_uom,

    toDateTime64OrNull(date) AS move_line_date,

    toDateTime64OrNull(create_date) AS created_at,
    toDateTime64OrNull(write_date)  AS updated_at

FROM raw
WHERE id IS NOT NULL AND id != ''