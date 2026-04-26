{{ config(materialized='table') }}

SELECT 
    sv.periode_bulan,
    sv.id_produk,
    sv.nilai_stok,
    -- Labeling: Jika ada di hasil Python gunakan statusnya, jika tidak ada (null) tapi ada stok, maka pasti Slow/Dead
    COALESCE(sm.is_slow_moving_kpi, 1) AS is_slow_moving,
    COALESCE(sm.demand_segment, 'dead_stock') AS demand_segment,
    COALESCE(sm.kpi_reason, 'no_movement_recorded') AS slow_moving_reason,
    p.nama_produk
FROM {{ ref('silver_stock_value') }} sv
LEFT JOIN {{ source('external_python', 'silver_slow_moving_bulanan') }} sm 
    ON sv.id_produk = sm.id_produk 
    AND sv.periode_bulan = sm.periode_bulan
LEFT JOIN {{ ref('silver_products') }} p ON sv.id_produk = p.id_produk
WHERE sv.nilai_stok > 0