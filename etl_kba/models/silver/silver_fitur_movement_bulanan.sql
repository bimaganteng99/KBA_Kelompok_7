{{ config(materialized='table') }}

WITH list_produk AS (
    SELECT id_produk FROM {{ ref('silver_products') }}
),

calendar AS (
    SELECT DISTINCT 
        dateTrunc('month', toDate(d)) AS p_bulan,
        (dateTrunc('month', toDate(d)) + toIntervalMonth(1)) - toIntervalDay(1) AS s_date,
        'Historical' AS s_type
    FROM (
        SELECT toDate('2026-03-01') AS d
        UNION ALL SELECT toDate('2026-04-01') AS d
        UNION ALL SELECT toDate('2026-05-01')
    )
    UNION ALL
    SELECT 
        dateTrunc('month', today()) AS p_bulan,
        today() AS s_date,
        'Real-time' AS s_type
),

product_monthly_grid AS (
    SELECT 
        p.id_produk AS grid_id_produk, -- Beri nama unik
        c.p_bulan AS grid_p_bulan,
        c.s_date AS grid_s_date,
        c.s_type AS grid_s_type
    FROM list_produk AS p
    CROSS JOIN calendar AS c
),

sales_data AS (
    SELECT 
        id_produk AS sales_id_produk, 
        tanggal, 
        qty 
    FROM {{ ref('silver_sales_move') }}
),

final_agg AS (
    SELECT
        grid.grid_p_bulan,
        grid.grid_id_produk,
        grid.grid_s_date,
        grid.grid_s_type,
        ifNull(i.qty, 0) AS stok_akhir,
        ifNull(i.nilai_stok, 0) AS nilai_stok_akhir,
        countIf(s.tanggal > (grid.grid_s_date - toIntervalDay(30)) AND s.tanggal <= grid.grid_s_date) AS frekuensi,
        sumIf(s.qty, s.tanggal > (grid.grid_s_date - toIntervalDay(30)) AND s.tanggal <= grid.grid_s_date) AS total_qty,
        maxIf(s.qty, s.tanggal > (grid.grid_s_date - toIntervalDay(30)) AND s.tanggal <= grid.grid_s_date) AS max_qty_temp,
        maxIf(s.tanggal, s.tanggal <= grid.grid_s_date) AS last_date
    FROM product_monthly_grid AS grid
    LEFT JOIN sales_data AS s ON grid.grid_id_produk = s.sales_id_produk
    LEFT JOIN {{ ref('silver_inventory_monthly_valuation') }} AS i 
        ON grid.grid_id_produk = i.id_produk 
        AND grid.grid_p_bulan = i.periode_bulan
    GROUP BY 
        grid.grid_p_bulan, 
        grid.grid_id_produk, 
        grid.grid_s_date, 
        grid.grid_s_type,
        stok_akhir,
        nilai_stok_akhir
)

SELECT
    f.grid_p_bulan AS periode_bulan,
    f.grid_id_produk AS id_produk,
    f.grid_s_date AS snapshot_date,
    f.grid_s_type AS snapshot_type,
    f.stok_akhir,
    f.nilai_stok_akhir,
    f.frekuensi AS frekuensi_transaksi,
    ifNull(f.total_qty, 0) AS total_qty_terjual_keluar,
    if(f.frekuensi > 0, f.total_qty / f.frekuensi, 0) AS rata2_qty_per_transaksi,
    if(f.frekuensi > 0, f.max_qty_temp, 0) AS max_qty_per_transaksi,
    if(f.last_date = toDate('1970-01-01') OR f.last_date IS NULL, 365, dateDiff('day', f.last_date, f.grid_s_date)) AS jeda_hari_dari_transaksi_terakhir
FROM final_agg AS f
