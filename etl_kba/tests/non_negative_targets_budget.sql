SELECT *
FROM (
  SELECT periode_bulan, target_penjualan AS value, 'target_penjualan' AS metric
  FROM {{ ref('silver_target_penjualan') }}
  UNION ALL
  SELECT periode_bulan, jumlah_anggaran AS value, 'alokasi_anggaran' AS metric
  FROM {{ ref('silver_alokasi_anggaran') }}
)
WHERE value < 0