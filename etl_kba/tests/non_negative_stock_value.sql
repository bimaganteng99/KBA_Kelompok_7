SELECT *
FROM {{ ref('silver_stock_value') }}
WHERE nilai_stok < 0