{{ config(materialized='table') }}

WITH raw AS (
    SELECT * FROM kba_bronze.stock_picking_type
)

SELECT
    toInt32OrNull(id) AS id_tipe_picking,

    NULLIF(name, '') AS nama_tipe_picking,
    NULLIF(code, '') AS kode_tipe_picking,  -- outgoing / incoming / internal

    toInt32OrNull(warehouse_id) AS id_warehouse,
    toInt32OrNull(company_id)   AS id_company,

    NULLIF(active, '') AS aktif_raw,

    toDateTime64OrNull(create_date) AS dibuat_pada,
    toDateTime64OrNull(write_date)  AS diubah_pada

FROM raw
WHERE id IS NOT NULL AND id != ''