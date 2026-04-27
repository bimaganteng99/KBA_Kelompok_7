{{ config(materialized='table') }}

SELECT 
    id_vendor,
    nama_vendor,
    toStartOfMonth(po_date_order) AS periode_bulan,
    count(*) AS total_pengiriman,
    sum(CASE WHEN receipt_done <= po_date_planned THEN 1 ELSE 0 END) AS tepat_waktu,
    (sum(CASE WHEN receipt_done <= po_date_planned THEN 1 ELSE 0 END) 
        / NULLIF(count(*),0)) * 100 AS otd_pct

FROM {{ ref('silver_purchase_on_time') }}

GROUP BY 1,2,3