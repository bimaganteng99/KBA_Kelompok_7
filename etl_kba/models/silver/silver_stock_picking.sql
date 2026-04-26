{{ config(materialized='table') }}

WITH raw AS (
    SELECT * FROM kba_bronze.stock_picking
)

SELECT
    toInt32OrNull(id) AS id_picking,

    toInt32OrNull(picking_type_id) AS id_picking_type,
    toInt32OrNull(partner_id)      AS id_partner,
    toInt32OrNull(company_id)      AS id_company,

    toInt32OrNull(location_id)      AS id_lokasi_asal,
    toInt32OrNull(location_dest_id) AS id_lokasi_tujuan,

    NULLIF(name, '')   AS nomor_picking,
    NULLIF(origin, '') AS origin_ref,
    NULLIF(state, '')  AS status_picking,
    NULLIF(move_type, '') AS move_type,

    toDateTimeOrNull(scheduled_date) AS scheduled_at,
    toDateTimeOrNull(date_deadline)  AS deadline_at,
    toDateTimeOrNull(date_done)      AS done_at,
    toDateTimeOrNull(date)           AS picking_date,

    has_deadline_issue AS has_deadline_issue_raw,
    is_locked          AS is_locked_raw,
    printed            AS printed_raw,
    NULLIF(note, '')   AS note,

    toInt32OrNull(sale_id) AS id_sale,

    toDateTimeOrNull(create_date) AS created_at,
    toDateTimeOrNull(write_date)  AS updated_at

FROM raw
WHERE id IS NOT NULL AND id != ''