import time
import subprocess
import psycopg2
import os
from clickhouse_driver import Client

# Konfigurasi dari Environment Variables (sesuai file .env Anda)
PG_HOST = os.getenv('PG_HOST', 'trialproyek_postgres')  # Gunakan 'trialproyek_postgres' jika di dalam docker
PG_PORT = os.getenv('PG_PORT', '5432')       # Port luar 5433, port dalam 5432
PG_DB = os.getenv('PG_DB', 'odoo')
PG_USER = os.getenv('PG_USER', 'odoo')
PG_PASS = os.getenv('PG_PASSWORD', 'odoo')

CH_HOST = os.getenv('CH_HOST', 'trialproyek_clickhouse')  # Gunakan 'trialproyek_clickhouse' jika di dalam docker
CH_USER = os.getenv('CH_USER', 'default')
CH_PASS = os.getenv('CH_PASSWORD', '')

def connect_with_retry():
    while True:
        try:
            conn = psycopg2.connect(
                host=os.getenv('PG_HOST'),
                database=os.getenv('PG_DB'),
                user=os.getenv('PG_USER'),
                password=os.getenv('PG_PASSWORD'),
                port=5432
            )
            return conn
        except psycopg2.OperationalError:
            print("Postgres belum siap, mencoba lagi dalam 5 detik...")
            time.sleep(5)

def ada_data_baru():
    # Daftar 12 tabel Odoo Anda
    daftar_tabel = ['sale_order', 'sale_order_line', 'purchase_order', 'purchase_order_line', 'stock_quant', 'stock_picking', 'stock_move', 'stock_move_line', 'product_product', 'product_template', 'stock_valuation_layer', 'stock_picking_type', 'res_partner'] 
    
    pg_conn = None
    try:
        pg_conn = psycopg2.connect(host=PG_HOST, port=PG_PORT, database=PG_DB, user=PG_USER, password=PG_PASS)
        pg_cur = pg_conn.cursor()
        
        ch_client = Client(host=CH_HOST, user=CH_USER, password=CH_PASS)

        for tabel in daftar_tabel:
            # Cek Max ID di Postgres
            pg_cur.execute(f'SELECT MAX(id) FROM public."{tabel}"')
            res_pg = pg_cur.fetchone()[0]
            # Paksa ke int, jika None (tabel kosong) maka 0
            max_pg = int(res_pg) if res_pg is not None else 0

            # Cek Max ID di Clickhouse
            try:
                tabel_ch = f"{tabel}" 
                ch_res = ch_client.execute(f"SELECT MAX(toUInt64(id)) FROM kba_bronze.{tabel_ch}")
                # Paksa ke int, jika None atau error maka 0
                max_ch = int(ch_res[0][0]) if ch_res and ch_res[0][0] is not None else 0
            except Exception:
                max_ch = 0

            if max_pg > max_ch:
                print("\n" + "="*40 + "\n")
                print(f"Data baru ditemukan pada tabel: {tabel} (PG: {max_pg}, CH: {max_ch})")
                return True # Langsung return True jika ada satu saja yang beda
        
        return False # Jika semua tabel sudah diperiksa dan tidak ada yang baru

    except Exception as e:
        print(f"Error pengecekan tabel: {e}")
        return False
    finally:
        if pg_conn: pg_conn.close()

def run_pipeline():
    print("\n" + "="*40 + "\n")
    print("--- Memulai Pipeline ---")
    try:
        # Jalankan script Ingestion
        text = "Menjalankan Ingestion..."
        width = len(text) + 6

        print("\n")
        print("#" * (width + 2))
        print("#" + " " * (width) + "#") 
        print(f"#   {text}   #")               
        print("#" + " " * (width) + "#") 
        print("#" * (width + 2))
        print("\n")

        subprocess.run(["python", "scripts_python/extract_to_bronze.py"], check=True)
        
        # Jalankan DBT Silver
        text = "Menjalankan DBT Silver..."
        width = len(text) + 6

        print("\n")
        print("#" * (width + 2))
        print("#" + " " * (width) + "#") 
        print(f"#   {text}   #")               
        print("#" + " " * (width) + "#") 
        print("#" * (width + 2))
        print("\n")
        
        subprocess.run(["dbt", "run", "--profiles-dir", ".", "--select", "tag:silver"], cwd="etl_kba", check=True)

        # Quality test 1/2
        text = "Menjalankan DBT Test 1/2..."
        width = len(text) + 6

        print("\n")
        print("#" * (width + 2))
        print("#" + " " * (width) + "#") 
        print(f"#   {text}   #")               
        print("#" + " " * (width) + "#") 
        print("#" * (width + 2))
        print("\n")

        subprocess.run(["dbt", "test", "--profiles-dir", ".", "--select", "silver", "--exclude", "source:external_python"], cwd="etl_kba", check=True)

        # Jalankan script K-Means
        text = "Menjalankan Script KMeans Clustering..."
        width = len(text) + 6

        print("\n")
        print("#" * (width + 2))
        print("#" + " " * (width) + "#") 
        print(f"#   {text}   #")               
        print("#" + " " * (width) + "#") 
        print("#" * (width + 2))
        print("\n")

        subprocess.run(["python", "scripts_python/kmeans_cluster_movement_bulanan.py"], check=True)

        # Quality test 2/2
        text = "Menjalankan DBT Test 2/2..."
        width = len(text) + 6

        print("\n")
        print("#" * (width + 2))
        print("#" + " " * (width) + "#") 
        print(f"#   {text}   #")               
        print("#" + " " * (width) + "#") 
        print("#" * (width + 2))
        print("\n")

        subprocess.run(["dbt", "test", "--profiles-dir", ".", "--select", "source:external_python.silver_slow_moving_bulanan"], cwd="etl_kba", check=True)

        # Jalankan DBT Gold
        text = "Menjalankan DBT Gold..."
        width = len(text) + 6

        print("\n")
        print("#" * (width + 2))
        print("#" + " " * (width) + "#") 
        print(f"#   {text}   #")               
        print("#" + " " * (width) + "#") 
        print("#" * (width + 2))
        print("\n")

        subprocess.run(["dbt", "run", "--profiles-dir", ".", "--select", "tag:gold"], cwd="etl_kba", check=True)
        
        print("\n--- Pipeline Berhasil Diselesaikan ---")
    except subprocess.CalledProcessError as e:
        print(f"Pipeline gagal pada tahap tertentu: {e}")
    print("="*40 + "\n")
    print("Menunggu perubahan data...\n")

if __name__ == "__main__":
    db_connection = connect_with_retry()
    print("Scheduler aktif")
    while True:
        try:
            if ada_data_baru():
                run_pipeline()
            else:
                print(f"[{time.strftime('%H:%M:%S')}] Data masih sama. Menunggu...")
        except Exception as e:
            print(f"Error Utama: {e}")
            db_connection = connect_with_retry()
        
        time.sleep(20) # Cek setiap 20 detik