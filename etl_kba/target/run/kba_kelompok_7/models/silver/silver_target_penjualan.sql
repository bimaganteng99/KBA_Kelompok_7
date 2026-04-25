
  
    
    
    
        
         


        
  

  insert into `kba_silver`.`silver_target_penjualan`
        ("periode_bulan", "target_penjualan")

WITH raw_target AS (
    SELECT * FROM kba_bronze.target_penjualan
)

SELECT
    -- Ubah teks jadi format Tanggal
    toDateOrNull(month) AS periode_bulan,
    
    -- Ubah teks jadi angka desimal
    toFloat64OrNull(target_sales) AS target_penjualan

FROM raw_target
WHERE month IS NOT NULL AND month != ''
  