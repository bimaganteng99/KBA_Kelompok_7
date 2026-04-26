# KBA_Kelompok_7
Proyek Business Intelligence Kelompok 7 KBA_SI-F

### KPI
1. **Sales Achievement Rate**: Mencapai 100% target penjualan bulanan sesuai dokumen target penjualan (CSV). 
2. **Sales Conversion Rate**: Mencapai rasio konversi penawaran menjadi pesanan (Quotation to Sales Order) minimal 70%.
3. **Vendor On-Time Delivery**: Jumlah pengiriman tepat waktu dari vendor mencapai 90% dari total pengiriman untuk tiap bulan.
4. **Budget Adherence**: Pengeluaran pembelian bulanan perusahaan tidak melebihi 90% dari alokasi di dokumen anggaran (XLSX).
5. **Slow Moving Optimization**: Menjaga komposisi stok barang "Slow Moving" maksimal 25% dari total nilai stok.

## Instalasi Proyek
### Clone Repository
Pastikan perangkat sudah memiliki ini:
- **Git:** Git terinstall di perangkat. Git bisa didownload dari official Git website.
- **Terminal:** Command-line interface (Terminal di macOS/Linux, Command Prompt atau Git Bash di Windows) untuk mengeksekusi perintah clone.

Jalankan kode berikut untuk melakukan clone repository.
```bash
git clone [https://github.com/bimaganteng99/KBA_Kelompok_7.git](https://github.com/bimaganteng99/KBA_Kelompok_7.git)
```

### Buat file .env
Buat file `.env`, lalu salin isi file `.env.example` ke dalamnya.

### Jalankan Docker Compose
Pastikan repositori sudah di-clone dan file `.env` sudah dibuat, lalu jalankan kode berikut.
```bash
# bersihkan container jika sudah pernah menjalankan compose up sebelumnya
docker compose down -v

# jalankan compose up
docker compose up -d
```
Pastikan semua service berhasil berjalan.
Buka Odoo di [localhost:8069](http://localhost:8069/web/login)

Login dengan menggunakan kredensial berikut:
```text
email    : admin@kba7.com 
password : adminkba7
```
Jika instalasi berhasil, modul Purchase, Inventory, dan Sales sudah terpasang dan berisi data.

---

## ⚙️ Eksekusi Pipeline Data (ETL)

Setelah Odoo berjalan dan berisi data, langkah selanjutnya adalah menarik data tersebut ke Data Warehouse (ClickHouse) dan membersihkannya menggunakan arsitektur Medallion.

### 1. Persiapan Environment Python
Proyek ini menggunakan Python untuk ekstraksi data dan `dbt` untuk transformasi. Pastikan kamu menggunakan Virtual Environment.

Jalankan perintah berikut di terminal:
```bash
# Membuat environment variable
python -m venv env

# Mengaktifkan virtual environment (Windows)
.\env\Scripts\activate

# Instalasi library utama
pip install -r requirements.txt

# FIX PENTING untuk pengguna Python 3.14+ (Mengatasi error mashumaro pada dbt)
pip install "mashumaro[msgpack]>=3.17"
```

### 2. Ekstraksi Data Mentah (Layer Bronze)
Skrip Python digunakan untuk menyedot data dari PostgreSQL (Odoo) dan file manual (CSV/XLSX), lalu memasukkannya ke layer `kba_bronze` di ClickHouse dengan format teks murni (String) menggunakan metode *Full Load*.

Pastikan file `target_sales_simple.csv` dan `budget_purchase_furniture.xlsx` sudah berada di dalam folder `data/raw/`.

Jalankan skrip ekstraksi:
```bash
python scripts_python/extract_to_bronze.py
```
*Tanda sukses: Muncul indikator "Data ... berhasil masuk!" untuk kelima tabel.*

### 3. Transformasi & Pembersihan (Layer Silver)
Setelah data mentah masuk ke Bronze, kita menggunakan **dbt (data build tool)** untuk mencuci data tersebut ke layer `kba_silver`. Proses ini meliputi:
- Konversi tipe data (String menjadi Int, Float, atau Date).
- Penanganan nilai kosong/Null.
- Standarisasi nama kolom ke Bahasa Indonesia.

Tabel yang dihasilkan pada Layer Silver:
- `silver_sales` (dari Odoo)
- `silver_purchase` (dari Odoo)
- `silver_inventory` (dari Odoo)
- `silver_target_penjualan` (dari CSV)
- `silver_alokasi_anggaran` (dari Excel)

Masuk ke direktori dbt dan jalankan proses transformasi:
```bash
# Pindah ke folder dbt
cd etl_kba

# Jalankan model dbt (menggunakan dbt_project.yml dan profiles.yml di folder saat ini)
dbt run --profiles-dir .
```
*Tanda sukses: Muncul keterangan `Completed successfully` dan `PASS=5` di terminal.*

---

## 💡 Catatan Troubleshooting
- **Conflict Port 5432:** Jika kamu memiliki PostgreSQL bawaan yang berjalan di laptop, koneksi ke Odoo dari luar Docker diubah menggunakan port `5433` (seperti yang terkonfigurasi di `docker-compose.yml` dan `extract_to_bronze.py`).
- **Akses DBeaver/Terminal ClickHouse:** Gunakan port `8123` untuk DBeaver atau jalankan `docker exec -it trialproyek_clickhouse clickhouse-client` untuk masuk langsung via terminal.
```