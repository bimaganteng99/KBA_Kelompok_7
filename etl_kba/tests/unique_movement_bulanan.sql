-- gagal jika ada duplikasi (id_produk, periode_bulan)
SELECT
  id_produk,
  snapshot_date,
  count(*) AS cnt
FROM {{ ref('silver_fitur_movement_bulanan') }}
GROUP BY id_produk, snapshot_date
HAVING cnt > 1