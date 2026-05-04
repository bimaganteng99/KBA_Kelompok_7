{{ config(materialized='table') }}

WITH current_quant AS (
    -- Pastikan quantity diubah ke Float64 sebelum di-SUM
    SELECT 
        toInt32OrNull(toString(product_id)) AS id_produk,
        SUM(toFloat64OrNull(toString(quantity))) AS jumlah_stok_fisik
    FROM kba_bronze.stock_quant
    GROUP BY 1
),

valuation_price AS (
    -- Pastikan value dan quantity diubah ke Float64 sebelum di-SUM
    SELECT 
        toInt32OrNull(toString(product_id)) AS id_produk,
        toStartOfMonth(toDateTime64OrNull(toString(create_date))) AS periode_bulan,
        SUM(toFloat64OrNull(toString(value))) AS total_value,
        SUM(toFloat64OrNull(toString(quantity))) AS total_qty_valuation
    FROM kba_bronze.stock_valuation_layer
    GROUP BY 1, 2
)

SELECT 
    v.periode_bulan,
    q.id_produk,
    -- q.jumlah_stok_fisik,
    -- Hitung unit cost dengan pengamanan pembagi nol
    -- CASE 
    --     WHEN v.total_qty_valuation != 0 THEN v.total_value / v.total_qty_valuation
    --     ELSE 0 
    -- END AS unit_cost_avg,
    -- Nilai stok akhir
    (q.jumlah_stok_fisik * (CASE WHEN v.total_qty_valuation != 0 THEN v.total_value / v.total_qty_valuation ELSE 0 END)) AS nilai_stok
FROM current_quant q
LEFT JOIN valuation_price v ON q.id_produk = v.id_produk
-- WHERE q.jumlah_stok_fisik > 0