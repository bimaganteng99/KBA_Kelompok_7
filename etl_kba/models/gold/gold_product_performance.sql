{{ config(materialized='table') }}

WITH sales AS (
    SELECT
        id_produk,
        periode_bulan,
        SUM(qty) AS total_qty,
        SUM(nilai_penjualan_proxy) AS total_sales
    FROM {{ ref('silver_sales_move') }}
    GROUP BY 1,2
),
inventory AS (
    SELECT
        id_produk,
        periode_bulanan as periode_bulan,
        -- demand_segment,
        nilai_stok,
        is_slow_moving
    FROM {{ ref('gold_slow_moving') }}
    -- WHERE snapshot_type = 'Historical'
),

base AS (
    SELECT 
        COALESCE(s.id_produk, i.id_produk) AS id_produk,
        COALESCE(s.periode_bulan, i.periode_bulan) AS periode_bulan, 
        -- i.demand_segment,
        s.total_sales,
        s.total_qty,
        i.nilai_stok,
        i.is_slow_moving
    FROM sales s
    FULL OUTER JOIN inventory i
        ON s.id_produk = i.id_produk
        AND s.periode_bulan = i.periode_bulan 
)

SELECT 
    b.periode_bulan as periode_bulan,
    b.id_produk as id_produk,
    -- menggunakan RegEx untuk mengambil teks di antara 'en_US': ' dan '
    extract(p.nama_produk, '\'en_US\': \'([^/]+)\'') AS nama_produk,
    sm.demand_segment,

    COALESCE(b.total_sales, 0) AS total_sales,
    COALESCE(b.total_qty, 0) AS total_qty,
    COALESCE(b.nilai_stok, 0) AS nilai_stok,
    COALESCE(b.is_slow_moving, 0) AS is_slow_moving_flag
FROM base b
LEFT JOIN {{ ref('silver_products') }} p
    ON b.id_produk = p.id_produk
LEFT JOIN {{ source('external_python', 'silver_slow_moving_bulanan') }} sm 
    ON b.id_produk = sm.id_produk 
    AND b.periode_bulan = sm.periode_bulan
    AND sm.snapshot_type = 'Historical'