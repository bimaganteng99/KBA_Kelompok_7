{{ config(materialized='table') }}

WITH po AS (
    SELECT * FROM kba_bronze.purchase_order
),
sp AS (
    SELECT * FROM kba_bronze.stock_picking
), 
pr AS (
    SELECT * FROM kba_bronze.res_partner
)

SELECT
    toInt32OrNull(po.id) AS id_purchase,
    NULLIF(po.name, '')  AS nomor_po,
    toInt32OrNull(po.partner_id) AS id_vendor,
    NULLIF(pr.name, '')  AS nama_vendor,
    NULLIF(po.state, '') AS status_po,

    -- Tanggal order & planned (dari PO)
    toDateTime64OrNull(po.date_order)   AS po_date_order,
    toDateTime64OrNull(po.date_planned) AS po_date_planned,

    -- Receipt (dari stock picking yang origin-nya match nomor PO)
    -- planned delivery schedule (picking scheduled) dan actual done
    min(toDateTime64OrNull(sp.scheduled_date)) AS receipt_scheduled,
    max(toDateTime64OrNull(sp.date_done))      AS receipt_done,

    -- jumlah dokumen receipt terkait
    countIf(sp.id IS NOT NULL AND sp.id != '') AS receipt_docs_count

FROM po
LEFT JOIN sp
    ON NULLIF(sp.origin, '') = NULLIF(po.name, '')
LEFT JOIN pr
    ON NULLIF(pr.id, '') = NULLIF(po.partner_id, '')

WHERE po.id IS NOT NULL AND po.id != ''
  AND toDateTime64OrNull(po.date_order) IS NOT NULL
  AND toDateTime64OrNull(po.date_planned) IS NOT NULL
  AND toDateTime64OrNull(sp.date_done) IS NOT NULL
GROUP BY
    id_purchase, nomor_po, id_vendor, nama_vendor, status_po, po_date_order, po_date_planned