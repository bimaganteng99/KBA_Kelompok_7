-- Gagal jika ada duplikasi (id_produk, periode_bulan)
SELECT
  id_produk,
  periode_bulan,
  count(*) AS cnt
FROM {{ ref('silver_fitur_movement_bulanan') }}
GROUP BY id_produk, periode_bulan
HAVING cnt > 1