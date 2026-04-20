import psycopg2

# 1. Buka koneksi ke Postgres di dalam Docker
conn = psycopg2.connect(
    host="127.0.0.1",
    port=5433,
    database="odoo_dummy",
    user="odoo_admin",
    password="kba_rahasia"
)
conn.autocommit = True
cursor = conn.cursor()

# 2. Bikin tabel Inventory, Purchase, dan Sales
print("Membuat tabel dummy di Postgres...")
cursor.execute('''
    CREATE TABLE IF NOT EXISTS sales_order (
        id SERIAL PRIMARY KEY,
        tanggal DATE,
        status VARCHAR(50),
        total_harga NUMERIC
    );
    CREATE TABLE IF NOT EXISTS purchase_order (
        id SERIAL PRIMARY KEY,
        tanggal DATE,
        status VARCHAR(50),
        total_pembelian NUMERIC
    );
    CREATE TABLE IF NOT EXISTS inventory_stock (
        id SERIAL PRIMARY KEY,
        nama_barang VARCHAR(100),
        kategori VARCHAR(50),
        hari_tanpa_transaksi INT
    );
''')

# 3. Isi dengan beberapa data dummy
print("Mengisi data dummy ke tabel...")
cursor.execute('''
    INSERT INTO sales_order (tanggal, status, total_harga) VALUES 
    ('2026-01-15', 'sale', 15000000), ('2026-01-20', 'draft', 5000000);
    
    INSERT INTO purchase_order (tanggal, status, total_pembelian) VALUES 
    ('2026-01-10', 'purchase', 10000000), ('2026-01-25', 'draft', 2000000);
    
    INSERT INTO inventory_stock (nama_barang, kategori, hari_tanpa_transaksi) VALUES 
    ('Mesin Espresso', 'Fast Moving', 5), ('Gelas Kaca', 'Slow Moving', 45);
''')

print("Berhasil! Database Postgres Odoo Dummy sudah siap disedot!")
cursor.close()
conn.close()