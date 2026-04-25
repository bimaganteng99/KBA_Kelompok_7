{{ config(materialized='table') }}

WITH raw_anggaran AS (
    SELECT * FROM kba_bronze.alokasi_anggaran
)

SELECT
    -- Ubah teks jadi format Tanggal (kita pangkas jamnya biar rapi jadi tanggal aja)
    toDateOrNull(month) AS periode_bulan,
    
    -- Ubah teks jadi angka desimal
    toFloat64OrNull(budget) AS jumlah_anggaran

FROM raw_anggaran
WHERE month IS NOT NULL AND month != ''