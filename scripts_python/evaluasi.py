import os
import pandas as pd
import numpy as np
from clickhouse_driver import Client
from sklearn.preprocessing import StandardScaler
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score, davies_bouldin_score, calinski_harabasz_score

# ==========================================
# 1. KONFIGURASI KONEKSI
# ==========================================
CH_HOST = os.getenv('CH_HOST', 'localhost')
CH_PORT = os.getenv('CH_PORT', '9000')

# Koneksi ClickHouse
ch = Client(host=CH_HOST, port=CH_PORT, user="default", password="")
FEATURE_TABLE = "kba_silver.silver_fitur_movement_bulanan"

def run_clustering_evaluation():
    # ==========================================
    # 2. LOAD DATA DARI CLICKHOUSE
    # ==========================================
    query = f"""
    SELECT
      periode_bulan,
      id_produk,
      snapshot_date,
      snapshot_type,
      frekuensi_transaksi,
      total_qty_terjual_keluar,
      rata2_qty_per_transaksi,
      max_qty_per_transaksi,
      jeda_hari_dari_transaksi_terakhir,
      stok_akhir
    FROM {FEATURE_TABLE}
    """
    
    data = ch.execute(query)
    cols = [
        "periode_bulan", "id_produk", "snapshot_date", "snapshot_type", "frekuensi_transaksi",
        "total_qty_terjual_keluar", "rata2_qty_per_transaksi",
        "max_qty_per_transaksi", "jeda_hari_dari_transaksi_terakhir", "stok_akhir"
    ]
    df = pd.DataFrame(data, columns=cols)

    if df.empty:
        print(f"Tabel feature kosong: {FEATURE_TABLE}. Silakan periksa data Anda.")
        return

    feature_cols = ["frekuensi_transaksi", "total_qty_terjual_keluar", "rata2_qty_per_transaksi", "max_qty_per_transaksi"]
    
    print("==========================================================================")
    print("             LAPORAN EVALUASI INTERNAL CLUSTERING (K-MEANS)               ")
    print("==========================================================================")

    # ==========================================
    # 3. EVALUASI ITERATIF PER SNAPSHOT DATE
    # ==========================================
    # Algoritma mengevaluasi cluster per bulan secara independen karena data dipisahkan per grup tanggal.
    grouped = df.groupby("snapshot_date")
    
    summary_reports = []

    for snapshot, group in grouped:
        temp_group = group.copy()

        # Filter produk aktif
        active_mask = temp_group["frekuensi_transaksi"] > 0
        df_active = temp_group[active_mask].copy()

        periode_label = str(df_active["periode_bulan"].iloc[0]) if not df_active.empty else str(snapshot)
        snapshot_type = df_active["snapshot_type"].iloc[0] if not df_active.empty else "Unknown"

        print(f"\n▶ Periode: {periode_label} ({snapshot_type})")
        print(f"  Jumlah total produk : {len(temp_group)} item")
        print(f"  Jumlah produk aktif : {len(df_active)} item (dimasukkan ke K-Means)")

        # Evaluasi hanya bisa berjalan jika jumlah sampel aktif mencukupi untuk membentuk 3 cluster
        if len(df_active) > 3:
            X = df_active[feature_cols].fillna(0.0)
            
            # Z-Score
            scaler = StandardScaler()
            X_scaled = scaler.fit_transform(X)
            
            # Fitting model sesuai parameter script utama (K=3)
            kmeans = KMeans(n_clusters=3, random_state=42, n_init="auto")
            cluster_labels = kmeans.fit_predict(X_scaled)
            
            # Perhitungan Metrics Statistik Evaluasi
            # 1. Silhouette Score (Ideal: Mendekati 1.0)
            sil_score = silhouette_score(X_scaled, cluster_labels)
            
            # 2. Davies-Bouldin Index (Ideal: Mendekati 0.0 / Makin kecil makin rapat)
            dbi_score = davies_bouldin_score(X_scaled, cluster_labels)
            
            # 3. Calinski-Harabasz Index (Ideal: Makin besar nilainya makin baik pemisahannya)
            ch_score = calinski_harabasz_score(X_scaled, cluster_labels)
            
            # Print hasil
            print(f"  [METRICS PERFORMANCE]")
            print(f"  - Silhouette Score          : {sil_score:.4f}")
            print(f"  - Davies-Bouldin Index (DBI) : {dbi_score:.4f}")
            print(f"  - Calinski-Harabasz Index   : {ch_score:.4f}")
            
            # Distribusi per kelompok cluster
            counts = pd.Series(cluster_labels).value_counts().to_dict()
            dist_str = ", ".join([f"Cluster {k}: {v} item" for k, v in sorted(counts.items())])
            print(f"  - Distribusi Ukuran Cluster : {dist_str}")
            
            summary_reports.append({
                "Periode": periode_label,
                "Type": snapshot_type,
                "Active_Items": len(df_active),
                "Silhouette": round(sil_score, 4),
                "DBI": round(dbi_score, 4),
                "Calinski_Harabasz": round(ch_score, 4)
            })
        else:
            print("  [PERINGATAN] Data produk aktif terlalu sedikit untuk dievaluasi (< 3 item).")

    # ==========================================
    # 4. RINGKASAN AKHIR DALAM BENTUK MATRIKS
    # ==========================================
    if summary_reports:
        print("\n" + "="*74)
        print("                        RINGKASAN METRICS KESELURUHAN                     ")
        print("="*74)
        df_summary = pd.DataFrame(summary_reports)
        print(df_summary.to_string(index=False))
        print("="*74)

if __name__ == "__main__":
    run_clustering_evaluation()