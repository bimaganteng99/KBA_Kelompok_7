{{ config(materialized='table') }}

WITH purchase_agg AS (
    SELECT 
        toStartOfMonth(tanggal_transaksi) AS periode_bulan,
        sum(total_belanja) AS total_pengeluaran_po
    FROM {{ ref('silver_purchase') }}
    WHERE status_transaksi IN ('purchase', 'done') -- Status PO Confirmed
    GROUP BY 1
),

otd_agg AS (
    SELECT 
        toStartOfMonth(po_date_order) AS periode_bulan,
        count(id_purchase) AS total_pengiriman,
        sum(CASE WHEN receipt_done <= po_date_planned THEN 1 ELSE 0 END) AS tepat_waktu
    FROM {{ ref('silver_purchase_on_time') }}
    GROUP BY 1
)

SELECT 
    p.periode_bulan AS periode_bulan,
    p.total_pengeluaran_po,
    a.jumlah_anggaran,
    (p.total_pengeluaran_po / NULLIF(a.jumlah_anggaran, 0)) * 100 AS budget_usage_pct,
    o.total_pengiriman,
    o.tepat_waktu,
    (o.tepat_waktu / NULLIF(o.total_pengiriman, 0)) * 100 AS vendor_otd_pct
FROM purchase_agg p
LEFT JOIN {{ ref('silver_alokasi_anggaran') }} a ON p.periode_bulan = a.periode_bulan
LEFT JOIN otd_agg o ON p.periode_bulan = o.periode_bulan