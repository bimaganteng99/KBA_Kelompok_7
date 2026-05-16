import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
import numpy as np
from clickhouse_driver import Client
import os

# Konfigurasi Koneksi
CH_HOST = os.getenv('CH_HOST', 'localhost')
CH_PORT = os.getenv('CH_PORT', '9000')
ch = Client(host=CH_HOST, port=CH_PORT, user="default", password="")
FEATURE_TABLE = "kba_silver.silver_fitur_movement_bulanan"

def run_eda_per_snapshot():
    # 1. Load Data
    query = f"SELECT * FROM {FEATURE_TABLE}"
    data = ch.execute(query)
    cols = [
        "periode_bulan", "id_produk", "snapshot_date", "snapshot_type", 
        "stok_akhir", "nilai_stok_akhir", "frekuensi_transaksi", 
        "total_qty_terjual_keluar", "rata2_qty_per_transaksi", 
        "max_qty_per_transaksi", "jeda_hari_dari_transaksi_terakhir"
    ]
    df = pd.DataFrame(data, columns=cols)
    
    if df.empty:
        print(f"Data di tabel {FEATURE_TABLE} kosong.")
        return

    # Konversi kolom periode ke string
    df['periode_str'] = df['periode_bulan'].astype(str)
    
    # Fitur yang akan dianalisis
    features_to_plot = [
        "frekuensi_transaksi", 
        "total_qty_terjual_keluar", 
        "rata2_qty_per_transaksi", 
        "jeda_hari_dari_transaksi_terakhir"
    ]

    # 2. Grouping berdasarkan Periode Bulan dan Tipe Snapshot
    grouped = df.groupby(['periode_str', 'snapshot_type'])

    for (periode, snapshot_type), group_df in grouped:
        print(f"\n" + "="*50)
        print(f"PROSES EDA UNTUK: Periode {periode} ({snapshot_type})")
        print(f"="*50)
        
        # Cetak info
        print(f"Jumlah Baris Data: {len(group_df)}")
        print("\n--- Deskripsi Statistik ---")
        print(group_df[features_to_plot + ["stok_akhir"]].describe())

        # Buat sub-folder spesifik per snapshot
        output_dir = f"grafik/eda_results/{periode}_{snapshot_type}"
        if not os.path.exists(output_dir):
            os.makedirs(output_dir)

        # Set tema seaborn
        sns.set_theme(style="whitegrid")

        # -------------------------------------------------------------
        # 3. Distribusi Fitur Utama (Univariate Analysis)
        # -------------------------------------------------------------
        plt.figure(figsize=(15, 10))
        for i, col in enumerate(features_to_plot, 1):
            plt.subplot(2, 2, i)
            if group_df[col].nunique() <= 1:
                sns.histplot(group_df[col], bins=10, kde=False, edgecolor="#000", line_kws={"color": "#000",   "linewidth": 2.5})
            else:
                sns.histplot(group_df[col], kde=True, bins=30, edgecolor="#000", line_kws={"color": "#000",   "linewidth": 2.5})
            
            plt.title(f'Distribusi {col}')
            
            # skala log krn rentang data terlalu timpang jauh
            if group_df[col].max() > 100:
                plt.yscale('log') 
                
        plt.suptitle(f"Distribusi Fitur - {periode} ({snapshot_type})", fontsize=16, y=1.02)
        plt.tight_layout()
        plt.savefig(f"{output_dir}/1_feature_distribution.png", bbox_inches='tight', dpi=150)
        plt.close()

        # -------------------------------------------------------------
        # 4. Correlation Heatmap
        # -------------------------------------------------------------
        plt.figure(figsize=(10, 8))
        corr = group_df[features_to_plot + ["stok_akhir"]].corr()
        
        # Gambarkan heatmap
        sns.heatmap(corr, annot=True, cmap='RdBu', center=0, vmin=-1, vmax=1, fmt=".2f")
        plt.title(f"Matriks Korelasi - {periode} ({snapshot_type})", fontsize=14)
        plt.tight_layout()
        plt.savefig(f"{output_dir}/2_correlation_matrix.png", bbox_inches='tight', dpi=150)
        plt.close()

        # -------------------------------------------------------------
        # 5. Analisis Outliers (Boxplot)
        # -------------------------------------------------------------
        plt.figure(figsize=(12, 6))
        # Skala logaritmik agar boxplot fitur ber-value besar vs kecil tetap terlihat
        df_melted = pd.melt(group_df[features_to_plot])
        ax = sns.boxplot(data=df_melted, x="variable", y="value")
        ax.set_yscale('symlog', linthresh=1) # Menggunakan symlog untuk handle nilai 0
        
        plt.xticks(rotation=15)
        plt.title(f"Identifikasi Outliers (Skala Symlog) - {periode} ({snapshot_type})", fontsize=14)
        plt.xlabel("Fitur")
        plt.ylabel("Nilai (Log Scale)")
        plt.tight_layout()
        plt.savefig(f"{output_dir}/3_outliers_check.png", bbox_inches='tight', dpi=150)
        plt.close()

        # -------------------------------------------------------------
        # 6. Nilai Stok vs Pergerakan (Bivariate Analysis)
        # -------------------------------------------------------------
        plt.figure(figsize=(10, 6))
        sns.scatterplot(data=group_df, x="total_qty_terjual_keluar", y="stok_akhir", alpha=0.6, color='purple')
        
        # Set skala log krn sebaran data sangat ekstrem
        if group_df["total_qty_terjual_keluar"].max() > 50 or group_df["stok_akhir"].max() > 50:
            plt.xscale('symlog', linthresh=1)
            plt.yscale('symlog', linthresh=1)
            
        plt.title(f"Total Penjualan vs Stok Akhir - {periode} ({snapshot_type})", fontsize=14)
        plt.xlabel("Total Qty Terjual (Keluar)")
        plt.ylabel("Stok Akhir")
        plt.tight_layout()
        plt.savefig(f"{output_dir}/4_sales_vs_stock.png", bbox_inches='tight', dpi=150)
        plt.close()

        print(f"-> Grafik sukses disimpan di folder: {output_dir}")

    print("\n[SELESAI] Seluruh snapshot telah dievaluasi!")

if __name__ == "__main__":
    run_eda_per_snapshot()