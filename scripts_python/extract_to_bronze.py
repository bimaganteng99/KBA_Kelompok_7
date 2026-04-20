import pandas as pd
from clickhouse_driver import Client

# 1. Buka Koneksi ke ClickHouse (yang sudah jalan di Docker)
# Kita pakai port 9000 sesuai dengan konfigurasi docker-compose kamu
client = Client(host='localhost', port=9000, user='default', password='kba_admin')

# 2. Bikin Database untuk Layer Bronze
client.execute('CREATE DATABASE IF NOT EXISTS kba_bronze')

# Bikin Tabel Target Penjualan (dari CSV)
client.execute('''
    CREATE TABLE IF NOT EXISTS kba_bronze.target_penjualan (
        periode_bulan Date,
        target_penjualan UInt64
    ) ENGINE = MergeTree()
    ORDER BY periode_bulan
''')

# Bikin Tabel Alokasi Anggaran (dari XLSX)
client.execute('''
    CREATE TABLE IF NOT EXISTS kba_bronze.alokasi_anggaran (
        periode_bulan Date,
        alokasi_pembelian UInt64
    ) ENGINE = MergeTree()
    ORDER BY periode_bulan
''')

# 3. Baca Data Dummy pakai Pandas
print("Membaca data dari folder data_source...")
# Path file disesuaikan dengan asumsi kamu menjalankan skrip dari folder utama (kba_kelompok_7)
df_target = pd.read_csv('data_source/target_penjualan.csv')
df_anggaran = pd.read_excel('data_source/alokasi_anggaran.xlsx')

# Konversi format tanggal di Pandas agar bisa masuk ke tipe data 'Date' di ClickHouse
df_target['periode_bulan'] = pd.to_datetime(df_target['periode_bulan']).dt.date
df_anggaran['periode_bulan'] = pd.to_datetime(df_anggaran['periode_bulan']).dt.date

# 4. Memasukkan Data (Load) ke ClickHouse
print("Menyedot data ke Layer Bronze ClickHouse...")
client.execute('INSERT INTO kba_bronze.target_penjualan VALUES', df_target.to_dict('records'))
client.execute('INSERT INTO kba_bronze.alokasi_anggaran VALUES', df_anggaran.to_dict('records'))

print("Ekstraksi data CSV dan XLSX ke Bronze Layer berhasil, sob!")