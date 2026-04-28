{{ config(materialized='table') }}

WITH raw_product AS (
    SELECT * FROM kba_bronze.product_product
),
raw_template AS (
    SELECT * FROM kba_bronze.product_template
)

SELECT
    toInt32OrNull(p.id) AS id_produk,
    toInt32OrNull(p.product_tmpl_id) AS id_template_produk,

    NULLIF(p.default_code, '') AS kode_produk,
    NULLIF(p.barcode, '')      AS barcode,

    NULLIF(t.name, '')          AS nama_produk,
    NULLIF(t.detailed_type, '') AS tipe_detail_produk,
    NULLIF(t.type, '')          AS tipe_produk,

    toInt32OrNull(t.categ_id) AS id_kategori,
    toInt32OrNull(t.uom_id)   AS id_uom,

    toFloat64OrNull(t.list_price) AS harga_jual,

    t.sale_ok     AS boleh_dijual_raw,
    t.purchase_ok AS boleh_dibeli_raw,
    t.active      AS aktif_raw,

    toDateTime64OrNull(p.create_date) AS dibuat_pada_produk,
    toDateTime64OrNull(p.write_date)  AS diubah_pada_produk,
    toDateTime64OrNull(t.create_date) AS dibuat_pada_template,
    toDateTime64OrNull(t.write_date)  AS diubah_pada_template

FROM raw_product p
LEFT JOIN raw_template t
    ON toInt32OrNull(p.product_tmpl_id) = toInt32OrNull(t.id)

WHERE p.id IS NOT NULL AND p.id != ''