import pandas as pd
import psycopg2
from clickhouse_driver import Client
import warnings
import os

# Jika dijalankan di Windows manual, dia akan pakai localhost:5433
# Jika dijalankan di Docker, Docker akan 'menyuntikkan' kba7_postgres:5432
PG_HOST = os.getenv('PG_HOST', 'localhost')
PG_PORT = os.getenv('PG_PORT', '5433') 
PG_DB   = os.getenv('PG_DB', 'odoo')
PG_USER = os.getenv('PG_USER', 'odoo')
PG_PASS = os.getenv('PG_PASSWORD', 'odoo')

# Begitu juga untuk Clickhouse
CH_HOST = os.getenv('CH_HOST', 'localhost')
CH_PORT = os.getenv('CH_PORT', '9000')

# Matikan warning Pandas agar terminal tetap bersih
warnings.filterwarnings('ignore')

# Koneksi
pg_conn = psycopg2.connect(
    host=PG_HOST, port=PG_PORT, database=PG_DB, user=PG_USER, password=PG_PASS
)
ch_client = Client(host=CH_HOST, port=CH_PORT, user='default', password='')
ch_client.execute('CREATE DATABASE IF NOT EXISTS kba_bronze')

# Ingestion
def sedot_ke_clickhouse(df, nama_tabel):
    # Paksa setiap sel tanpa ampun jadi String. Kalau kosong (NaN), jadikan teks kosong ""
    for col in df.columns:
        df[col] = df[col].apply(lambda x: "" if pd.isna(x) else str(x))
        
    kolom_string = [f"`{col}` Nullable(String)" for col in df.columns]
    query_bikin_tabel = f"CREATE TABLE IF NOT EXISTS kba_bronze.{nama_tabel} ({', '.join(kolom_string)}) ENGINE = MergeTree() ORDER BY tuple()"
    
    ch_client.execute(f'DROP TABLE IF EXISTS kba_bronze.{nama_tabel}')
    ch_client.execute(query_bikin_tabel)
    ch_client.execute(f'INSERT INTO kba_bronze.{nama_tabel} VALUES', df.to_dict('records'))
    print(f"Data {nama_tabel} berhasil masuk!")

# ODOO POSTGRES
print("Menyedot data dari Odoo Postgres...")
# tambah tabel
tabel_odoo = ['sale_order', 'sale_order_line', 'purchase_order', 'purchase_order_line', 'stock_quant', 'stock_location', 'stock_picking', 'stock_move', 'stock_move_line', 'product_product', 'product_template', 'stock_valuation_layer', 'stock_picking_type', 'res_partner'] 
for tabel in tabel_odoo:
    try:
        df_odoo = pd.read_sql(f"SELECT * FROM {tabel}", pg_conn)
        sedot_ke_clickhouse(df_odoo, tabel)
    except Exception as e:
        print(f"Gagal menarik {tabel}: {e}")
        pg_conn.rollback()

# FILE MANUAL
print("\nMembaca data file manual...")
try:
    df_target = pd.read_csv('data/raw/target_sales_simple.csv')
    sedot_ke_clickhouse(df_target, 'target_penjualan')

    df_anggaran = pd.read_excel('data/raw/budget_purchase_furniture.xlsx')
    sedot_ke_clickhouse(df_anggaran, 'alokasi_anggaran')
except Exception as e:
    print(f"Gagal menarik file manual: {e}")

print("\nMISI SELESAI: Layer Bronze siap digunakan!")
pg_conn.close()