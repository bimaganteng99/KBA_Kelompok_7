{{ config(materialized='table') }}

WITH raw_anggaran AS (
    SELECT * FROM kba_bronze.alokasi_anggaran
)

SELECT
    toDateOrNull(month) AS periode_bulan,
    toFloat64OrNull(budget) AS jumlah_anggaran

FROM raw_anggaran
WHERE month IS NOT NULL AND month != ''