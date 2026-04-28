{{ config(materialized='table') }}

WITH raw AS (
    SELECT * FROM kba_bronze.stock_move
)

SELECT
    toInt32OrNull(id) AS id_move,

    toInt32OrNull(picking_id) AS id_picking,
    toInt32OrNull(product_id) AS id_produk,
    toInt32OrNull(company_id) AS id_company,
    toInt32OrNull(partner_id) AS id_partner,

    toInt32OrNull(location_id)      AS id_lokasi_asal,
    toInt32OrNull(location_dest_id) AS id_lokasi_tujuan,

    toInt32OrNull(picking_type_id) AS id_picking_type,

    NULLIF(name, '')      AS deskripsi_move,
    NULLIF(reference, '') AS reference,
    NULLIF(origin, '')    AS origin_ref,
    NULLIF(state, '')     AS status_move,

    toFloat64OrNull(product_qty)     AS product_qty,
    toFloat64OrNull(product_uom_qty) AS product_uom_qty,
    toFloat64OrNull(quantity)        AS quantity,

    toDateTime64OrNull(date)          AS move_date,
    toDateTime64OrNull(date_deadline) AS deadline_at,

    toFloat64OrNull(price_unit) AS price_unit,

    toInt32OrNull(sale_line_id)     AS id_sale_line,
    toInt32OrNull(purchase_line_id) AS id_purchase_line,

    toDateTime64OrNull(create_date) AS created_at,
    toDateTime64OrNull(write_date)  AS updated_at

FROM raw
WHERE id IS NOT NULL AND id != ''