{{ config(materialized='table') }}

SELECT 
    id_vendor,
    nama_vendor,
    toStartOfMonth(po_date_order) AS periode_bulan,
    count(*) AS total_pengiriman,
    sum(CASE WHEN receipt_done <= po_date_planned THEN 1 ELSE 0 END) AS tepat_waktu,
    count(*) - sum(CASE WHEN receipt_done <= po_date_planned THEN 1 ELSE 0 END) AS terlambat,
    (sum(CASE WHEN receipt_done <= po_date_planned THEN 1 ELSE 0 END) 
        / NULLIF(count(*),0)) * 100 AS otd_pct,

    avg(CASE 
        WHEN receipt_done > po_date_planned 
        THEN dateDiff('hour', po_date_planned, receipt_done) / 24.0
        WHEN receipt_done < po_date_planned 
        THEN 0
        ELSE NULL 
    END) AS avg_delay_days,

    max(greatest(dateDiff('hour', po_date_planned, receipt_done) / 24.0, 0)) AS max_delay_days,

    avg(dateDiff('hour', po_date_planned, receipt_scheduled) / 24.0) AS internal_scheduling_gap

FROM {{ ref('silver_purchase_on_time') }}

GROUP BY 1,2,3