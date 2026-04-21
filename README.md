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
```
git clone https://github.com/bimaganteng99/KBA_Kelompok_7.git
```
### Buat file .env
Buat file `.env`, lalu salin isi file `.env.example` ke dalamnya

### Jalankan Docker Compose
Pastikan repositori sudah di-clone dan file `.env` sudah dibuat, lalu jalankan kode berikut.
```
# bersihkan container jika sudah pernah menjalankan compose up sebelumnya
docker compose down -v
# jalankan compose up
docker compose up -d
```
Pastikan semua service berhasil berjalan.
Buka odoo di [localhost:8069](http://localhost:8069/web/login)

Login dengan menggunakan kredensial berikut
```
email    : admin@kba7.com 
password : adminkba7
```
Jika instalasi berhasil, modul Purchase, Inventory, dan Sales sudah terpasang dan berisi data.

