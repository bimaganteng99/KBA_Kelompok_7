{{ config(materialized='table') }}

WITH po AS (
    SELECT * FROM kba_bronze.purchase_order
),
sp AS (
    SELECT * FROM kba_bronze.stock_picking
)

SELECT
    toInt32OrNull(po.id) AS id_purchase,
    NULLIF(po.name, '')  AS nomor_po,
    toInt32OrNull(po.partner_id) AS id_vendor,
    NULLIF(po.state, '') AS status_po,

    -- Tanggal order & planned (dari PO)
    toDateTimeOrNull(po.date_order)   AS po_date_order,
    toDateTimeOrNull(po.date_planned) AS po_date_planned,

    -- Receipt (dari stock picking yang origin-nya match nomor PO)
    -- planned delivery schedule (picking scheduled) dan actual done
    min(toDateTimeOrNull(sp.scheduled_date)) AS receipt_scheduled_min,
    max(toDateTimeOrNull(sp.date_done))      AS receipt_done_max,

    -- jumlah dokumen receipt terkait
    countIf(sp.id IS NOT NULL AND sp.id != '') AS receipt_docs_count

FROM po
LEFT JOIN sp
    ON NULLIF(sp.origin, '') = NULLIF(po.name, '')

WHERE po.id IS NOT NULL AND po.id != ''
GROUP BY
    id_purchase, nomor_po, id_vendor, status_po, po_date_order, po_date_planned