SELECT *
FROM {{ ref('silver_fitur_movement_bulanan') }}
WHERE frekuensi_transaksi < 0
   OR total_qty_terjual_keluar < 0
   OR rata2_qty_per_transaksi < 0
   OR max_qty_per_transaksi < 0
   OR jeda_hari_dari_transaksi_terakhir < 0