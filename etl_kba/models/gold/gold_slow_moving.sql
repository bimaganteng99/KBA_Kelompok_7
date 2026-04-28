{{ config(materialized='table') }}

SELECT 
    sv.periode_bulan as periode_bulanan,
    sv.id_produk as id_produk,
    sv.nilai_stok,
    CASE 
        WHEN sm.id_produk = 0 THEN 1 -- Dead Stock = Pasti Slow Moving
        WHEN sm.is_slow_moving_kpi = 1 THEN 1 
        ELSE 0 
    END AS is_slow_moving,
    multiIf(empty(sm.demand_segment), 'dead_stock', sm.demand_segment) AS demand_segment,
    multiIf(empty(sm.kpi_reason), 'no_movement_recorded', sm.kpi_reason) AS slow_moving_reason,
    extract(p.nama_produk, '\'en_US\': \'([^/]+)\'') AS nama_produk
FROM {{ ref('silver_stock_value') }} sv
LEFT JOIN {{ source('external_python', 'silver_slow_moving_bulanan') }} sm 
    ON sv.id_produk = sm.id_produk 
    AND sv.periode_bulan = sm.periode_bulan
LEFT JOIN {{ ref('silver_products') }} p ON sv.id_produk = p.id_produk
WHERE sv.nilai_stok > 0