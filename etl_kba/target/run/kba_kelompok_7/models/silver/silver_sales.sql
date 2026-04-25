
  
    
    
    
        
         


        
  

  insert into `kba_silver`.`silver_sales__dbt_backup`
        ("id_penjualan", "nomor_nota", "tanggal_transaksi", "total_belanja", "status_transaksi")

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
    toDateTimeOrNull(date_order) AS tanggal_transaksi,
    
    -- 4. Mengubah string menjadi angka desimal (Uang)
    toFloat64OrNull(amount_total) AS total_belanja,
    
    state AS status_transaksi

FROM raw_sales
-- 5. Membuang baris yang ID-nya kosong/cacat
WHERE id IS NOT NULL AND id != ''
  