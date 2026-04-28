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
        nilai_stok,
        is_slow_moving
    FROM {{ ref('gold_slow_moving') }}
),

base AS (
    SELECT 
        COALESCE(s.id_produk, i.id_produk) AS id_produk,
        -- Changed i.periode_bulanan to i.periode_bulan
        COALESCE(s.periode_bulan, i.periode_bulan) AS periode_bulan, 
        s.total_sales,
        s.total_qty,
        i.nilai_stok,
        i.is_slow_moving
    FROM sales s
    FULL OUTER JOIN inventory i
        ON s.id_produk = i.id_produk
        -- Changed i.periode_bulanan to i.periode_bulan
        AND s.periode_bulan = i.periode_bulan 
)

SELECT 
    b.periode_bulan,
    b.id_produk,
    -- Menggunakan RegEx untuk mengambil teks di antara 'en_US': ' dan '
    extract(p.nama_produk, '\'en_US\': \'([^/]+)\'') AS nama_produk,

    COALESCE(b.total_sales, 0) AS total_sales,
    COALESCE(b.total_qty, 0) AS total_qty,
    COALESCE(b.nilai_stok, 0) AS nilai_stok,
    COALESCE(b.is_slow_moving, 0) AS is_slow_moving_flag
FROM base b
LEFT JOIN {{ ref('silver_products') }} p
    ON b.id_produk = p.id_produk