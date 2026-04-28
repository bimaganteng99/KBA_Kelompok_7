{{ config(materialized='table') }}

WITH raw_sales AS (
    -- Ambil data mentah dari Layer Bronze
    SELECT * FROM kba_bronze.sale_order
)

SELECT
    -- 1. Mengembalikan tipe data ke aslinya
    toInt32OrNull(id) AS id_penjualan,
    
    -- 2. Merapikan nama kolom
    name AS nomor_nota,
    
    -- 3. Mengubah string menjadi format waktu (DateTime)
    toDateTime64OrNull(date_order) AS tanggal_transaksi,
    
    -- 4. Mengubah string menjadi angka desimal (Uang)
    toFloat64OrNull(amount_total) AS total_belanja,
    
    state AS status_transaksi

FROM raw_sales
-- 5. Membuang baris yang ID-nya kosong/cacat dan tanggalnya null
WHERE id IS NOT NULL AND id != ''
  AND toDateTime64OrNull(date_order) IS NOT NULL