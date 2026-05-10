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
    f.grid_id_produk AS id_produk, -- Referensi eksplisit ke alias di final_agg
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

-- {{ config(materialized='table') }}

-- -- 1. Ambil semua produk aktif
-- WITH list_produk AS (
--     SELECT 
--         id_produk
--     FROM {{ ref('silver_products') }}
-- ),

-- -- 2. Tentukan periode snapshot
-- calendar AS (
--     SELECT DISTINCT 
--         dateTrunc('month', toDate(d)) AS periode_bulan,
--         dateAdd(month, 1, dateTrunc('month', toDate(d))) - interval 1 day AS snapshot_date,
--         -- dateTrunc('month', toDate(d)) AS snapshot_date,
--         'Historical' AS snapshot_type
--     FROM (
--         SELECT toDate('2026-03-01') AS d
--         UNION ALL SELECT toDate('2026-04-01') AS d
--         UNION ALL SELECT toDate('2026-05-01')
--     )
--     UNION ALL
--     -- Data Real-Time (Kondisi Hari Ini)
--     SELECT 
--         dateTrunc('month', today()) AS periode_bulan,
--         today() AS snapshot_date,
--         'Real-time' AS snapshot_type
-- ),

-- -- 3. Cross Join untuk membuat grid
-- product_monthly_grid AS (
--     SELECT 
--         p.id_produk,
--         c.periode_bulan,
--         c.snapshot_date,
--         c.snapshot_type
--     FROM list_produk p
--     CROSS JOIN calendar c
-- ),

-- -- 4. Gabungkan Stock Move (Fisik) dan Sale Order (Jasa)
-- movement_data AS (
--     -- Ambil dari Stock Move (untuk Fisik)
--     SELECT
--         toInt32OrNull(trim(sml.product_id)) AS id_produk,
--         toDateTime64OrNull(sml.date) AS tanggal_pergerakan,
--         toFloat64OrNull(sml.quantity) AS qty
--     FROM kba_bronze.stock_move_line sml
--     LEFT JOIN kba_bronze.stock_move sm ON toInt32OrNull(trim(BOTH ' ' FROM sml.move_id)) = toInt32OrNull(trim(BOTH ' ' FROM sm.id))
--     LEFT JOIN kba_bronze.stock_picking sp ON toInt32(ifNull(toFloat64OrNull(trim(BOTH ' ' FROM sm.picking_id)), -1)) = toInt32OrNull(trim(BOTH ' ' FROM sp.id))
--     LEFT JOIN kba_bronze.stock_picking_type spt ON toInt32OrNull(trim(BOTH ' ' FROM sp.picking_type_id)) = toInt32OrNull(trim(BOTH ' ' FROM spt.id))
--     WHERE lowerUTF8(trim(BOTH ' ' FROM sml.state)) = 'done'
--       AND lowerUTF8(trim(BOTH ' ' FROM spt.code)) = 'outgoing'

--     UNION ALL

--     -- Ambil dari Sale Order (khusus untuk Service)
--     SELECT
--         toInt32OrNull(trim(sol.product_id)) AS id_produk,
--         toDateTime64OrNull(so.date_order) AS tanggal_pergerakan,
--         toFloat64OrNull(sol.product_uom_qty) AS qty
--     FROM kba_bronze.sale_order_line sol
--     JOIN kba_bronze.sale_order so ON toInt32OrNull(trim(BOTH ' ' FROM sol.order_id)) = toInt32OrNull(trim(BOTH ' ' FROM so.id))
--     JOIN kba_bronze.product_product pp ON toInt32OrNull(trim(BOTH ' ' FROM sol.product_id)) = toInt32OrNull(trim(BOTH ' ' FROM pp.id))
--     JOIN kba_bronze.product_template pt ON toInt32OrNull(trim(BOTH ' ' FROM pp.product_tmpl_id)) = toInt32OrNull(trim(BOTH ' ' FROM pt.id))
--     WHERE lowerUTF8(trim(BOTH ' ' FROM so.state)) IN ('sale', 'done')
--       AND lowerUTF8(trim(BOTH ' ' FROM pt.type)) = 'service'
-- ),

-- -- 5. Gabungkan dan gunakan FILTER di dalam agregasi untuk menghindari Error 403
-- final_agg AS (
--     SELECT
--         grid.periode_bulan AS periode_bulan,
--         grid.id_produk AS id_produk,
--         grid.snapshot_date AS snapshot_date,
--         grid.snapshot_type AS snapshot_type,
--         i.qty AS stok_akhir,
--         -- Menghitung frekuensi hanya jika tanggal masuk dalam rentang 30 hari
--         countIf(m.tanggal_pergerakan > (grid.snapshot_date - interval 30 day) AND m.tanggal_pergerakan <= grid.snapshot_date) AS frekuensi_transaksi,
        
--         -- Menghitung qty hanya jika tanggal masuk dalam rentang 30 hari
--         sumIf(m.qty, m.tanggal_pergerakan > (grid.snapshot_date - interval 30 day) AND m.tanggal_pergerakan <= grid.snapshot_date) AS total_qty_terjual_keluar,
        
--         max(m.qty) AS max_qty_per_transaksi_temp,

--         -- Mengambil tanggal terakhir untuk hitung jeda
--         -- maxIf(m.tanggal_pergerakan, m.tanggal_pergerakan > (grid.snapshot_date - interval 30 day) AND m.tanggal_pergerakan <= grid.snapshot_date) AS last_move_date
--         maxIf(m.tanggal_pergerakan, m.tanggal_pergerakan <= grid.snapshot_date) AS last_move_date
--     FROM product_monthly_grid grid
--     LEFT JOIN movement_data m ON grid.id_produk = m.id_produk
--     LEFT JOIN kba_silver.silver_inventory_monthly_valuation i 
--     ON grid.id_produk = i.id_produk AND grid.periode_bulan = i.periode_bulan
--     GROUP BY 
--         periode_bulan, 
--         id_produk, 
--         snapshot_date, 
--         snapshot_type,
--         stok_akhir
-- )

-- SELECT
--     periode_bulan,
--     id_produk,
--     snapshot_date,
--     snapshot_type,
--     stok_akhir,
--     frekuensi_transaksi,
--     ifNull(total_qty_terjual_keluar, 0) AS total_qty_terjual_keluar,
--     if(frekuensi_transaksi > 0, total_qty_terjual_keluar / frekuensi_transaksi, 0) AS rata2_qty_per_transaksi,
--     if(frekuensi_transaksi > 0, max_qty_per_transaksi_temp, 0) AS max_qty_per_transaksi,
--     -- Jeda hari: jika tidak ada transaksi dalam 30 hari terakhir, beri nilai 999
--     -- if(last_move_date IS NULL, 365, dateDiff('day', last_move_date, snapshot_date)) AS jeda_hari_dari_transaksi_terakhir
--     if(last_move_date IS NULL, 365, dateDiff('day', last_move_date, snapshot_date)) AS jeda_hari_dari_transaksi_terakhir
-- FROM final_agg
