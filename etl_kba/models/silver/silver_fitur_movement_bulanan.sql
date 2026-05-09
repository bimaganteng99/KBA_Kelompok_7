{{ config(materialized='table') }}

-- 1. Ambil semua produk aktif
WITH list_produk AS (
    SELECT 
        id_produk
    FROM {{ ref('silver_products') }}
),

-- 2. Tentukan periode snapshot
calendar AS (
    SELECT DISTINCT 
        dateTrunc('month', toDate(d)) AS periode_bulan,
        dateAdd(month, 1, dateTrunc('month', toDate(d))) - interval 1 day AS snapshot_date,
        -- dateTrunc('month', toDate(d)) AS snapshot_date,
        'Historical' AS snapshot_type
    FROM (
        SELECT toDate('2026-03-01') AS d
        UNION ALL SELECT toDate('2026-04-01') AS d
        UNION ALL SELECT toDate('2026-05-01')
    )
    UNION ALL
    -- Data Real-Time (Kondisi Hari Ini)
    SELECT 
        dateTrunc('month', today()) AS periode_bulan,
        today() AS snapshot_date,
        'Real-time' AS snapshot_type
),

-- 3. Cross Join untuk membuat grid
product_monthly_grid AS (
    SELECT 
        p.id_produk,
        c.periode_bulan,
        c.snapshot_date,
        c.snapshot_type
    FROM list_produk p
    CROSS JOIN calendar c
),

-- 4. Ambil data transaksi keluar tanpa filter tanggal di awal
movement_data AS (
    SELECT
        toInt32OrNull(trim(BOTH ' ' FROM sml.product_id)) AS id_produk,
        toDateTime64OrNull(sml.date) AS tanggal_pergerakan,
        toFloat64OrNull(sml.quantity) AS qty
    FROM kba_bronze.stock_move_line sml
    LEFT JOIN kba_bronze.stock_move sm ON toInt32OrNull(trim(BOTH ' ' FROM sml.move_id)) = toInt32OrNull(trim(BOTH ' ' FROM sm.id))
    LEFT JOIN kba_bronze.stock_picking sp ON toInt32(ifNull(toFloat64OrNull(trim(BOTH ' ' FROM sm.picking_id)), -1)) = toInt32OrNull(trim(BOTH ' ' FROM sp.id))
    LEFT JOIN kba_bronze.stock_picking_type spt ON toInt32OrNull(trim(BOTH ' ' FROM sp.picking_type_id)) = toInt32OrNull(trim(BOTH ' ' FROM spt.id))
    WHERE lowerUTF8(trim(BOTH ' ' FROM sml.state)) = 'done'
      AND lowerUTF8(trim(BOTH ' ' FROM sp.state)) = 'done'
      AND lowerUTF8(trim(BOTH ' ' FROM spt.code)) = 'outgoing'
),

-- 5. Gabungkan dan gunakan FILTER di dalam agregasi untuk menghindari Error 403
final_agg AS (
    SELECT
        grid.periode_bulan,
        grid.id_produk,
        grid.snapshot_date,
        grid.snapshot_type,
        -- Menghitung frekuensi hanya jika tanggal masuk dalam rentang 30 hari
        countIf(m.tanggal_pergerakan > (grid.snapshot_date - interval 30 day) AND m.tanggal_pergerakan <= grid.snapshot_date) AS frekuensi_transaksi,
        
        -- Menghitung qty hanya jika tanggal masuk dalam rentang 30 hari
        sumIf(m.qty, m.tanggal_pergerakan > (grid.snapshot_date - interval 30 day) AND m.tanggal_pergerakan <= grid.snapshot_date) AS total_qty_terjual_keluar,
        
        max(m.qty) AS max_qty_per_transaksi_temp,

        -- Mengambil tanggal terakhir untuk hitung jeda
        maxIf(m.tanggal_pergerakan, m.tanggal_pergerakan > (grid.snapshot_date - interval 30 day) AND m.tanggal_pergerakan <= grid.snapshot_date) AS last_move_date
    FROM product_monthly_grid grid
    LEFT JOIN movement_data m ON grid.id_produk = m.id_produk
    GROUP BY grid.id_produk, grid.snapshot_date, grid.snapshot_type, grid.periode_bulan
)

SELECT
    periode_bulan,
    id_produk,
    snapshot_date,
    snapshot_type,
    frekuensi_transaksi,
    ifNull(total_qty_terjual_keluar, 0) AS total_qty_terjual_keluar,
    if(frekuensi_transaksi > 0, total_qty_terjual_keluar / frekuensi_transaksi, 0) AS rata2_qty_per_transaksi,
    if(frekuensi_transaksi > 0, max_qty_per_transaksi_temp, 0) AS max_qty_per_transaksi,
    -- Jeda hari: jika tidak ada transaksi dalam 30 hari terakhir, beri nilai 999
    if(last_move_date IS NULL, 365, dateDiff('day', last_move_date, snapshot_date)) AS jeda_hari_dari_transaksi_terakhir
FROM final_agg

-- {{ config(materialized='table') }}

-- WITH base AS (
--     SELECT
--         toInt32OrNull(trim(BOTH ' ' FROM sml.product_id)) AS id_produk,
--         dateAdd(month, 1, dateTrunc('month', toDate(sml.date))) - interval 1 day AS snapshot_date,
--         toFloat64OrNull(sml.quantity) AS qty,
--         toDateTime64OrNull(sml.date) AS tanggal_pergerakan,

--         lowerUTF8(trim(BOTH ' ' FROM sml.state)) AS status_move_line,
--         lowerUTF8(trim(BOTH ' ' FROM sp.state))  AS status_picking,
--         lowerUTF8(trim(BOTH ' ' FROM spt.code))  AS kode_tipe_picking

--     FROM kba_bronze.stock_move_line sml
--     LEFT JOIN kba_bronze.stock_move sm
--         ON toInt32OrNull(trim(BOTH ' ' FROM sml.move_id))
--          = toInt32OrNull(trim(BOTH ' ' FROM sm.id))
--     LEFT JOIN kba_bronze.stock_picking sp
--         ON toInt32(ifNull(toFloat64OrNull(trim(BOTH ' ' FROM sm.picking_id)), -1))
--          = toInt32OrNull(trim(BOTH ' ' FROM sp.id))
--     LEFT JOIN kba_bronze.stock_picking_type spt
--         ON toInt32OrNull(trim(BOTH ' ' FROM sp.picking_type_id))
--          = toInt32OrNull(trim(BOTH ' ' FROM spt.id))

--     WHERE sml.id IS NOT NULL AND sml.id != ''
-- )

-- SELECT
--     id_produk,
--     snapshot_date,
--     count() AS frekuensi_transaksi,
--     sum(qty) AS total_qty_terjual_keluar,
--     avg(qty) AS rata2_qty_per_transaksi,
--     max(qty) AS max_qty_per_transaksi,
--     dateDiff('day', max(tanggal_pergerakan), snapshot_date) AS jeda_hari_dari_snapshot
-- FROM base
-- WHERE status_move_line = 'done'
--   AND status_picking = 'done'
--   AND kode_tipe_picking = 'outgoing'
--   AND id_produk IS NOT NULL
--   AND tanggal_pergerakan > (snapshot_date - interval 30 day)
--   AND tanggal_pergerakan <= snapshot_date
-- GROUP BY id_produk, snapshot_date