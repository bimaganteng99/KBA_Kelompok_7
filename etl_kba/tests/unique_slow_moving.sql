SELECT
  id_produk,
  periode_bulan,
  count(*) AS cnt
FROM kba_silver.silver_slow_moving_bulanan
GROUP BY id_produk, periode_bulan
HAVING cnt > 1