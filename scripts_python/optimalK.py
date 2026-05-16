import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import os
from collections import Counter
from clickhouse_driver import Client
from sklearn.preprocessing import StandardScaler
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score

# Set tema global
sns.set_theme(style="whitegrid")

# 1. Konfigurasi Koneksi
CH_HOST = os.getenv('CH_HOST', 'localhost')
CH_PORT = os.getenv('CH_PORT', '9000')
ch = Client(host=CH_HOST, port=CH_PORT, user="default", password="")
FEATURE_TABLE = "kba_silver.silver_fitur_movement_bulanan"

def find_k_optimal_comprehensive():
    # 2. Load Data
    query = f"""
    SELECT
      periode_bulan,
      snapshot_type,
      frekuensi_transaksi,
      total_qty_terjual_keluar,
      rata2_qty_per_transaksi,
      max_qty_per_transaksi
    FROM {FEATURE_TABLE}
    WHERE frekuensi_transaksi > 0  -- Hanya produk aktif yang dicluster
    """
    data = ch.execute(query)
    cols = ["periode_bulan", "snapshot_type", "frekuensi_transaksi", "total_qty_terjual_keluar", "rata2_qty_per_transaksi", "max_qty_per_transaksi"]
    df = pd.DataFrame(data, columns=cols)

    if df.empty or len(df) < 15:
        print("Data terlalu sedikit untuk melakukan analisis cluster.")
        return

    df['periode_str'] = df['periode_bulan'].astype(str)
    feature_cols = ["frekuensi_transaksi", "total_qty_terjual_keluar", "rata2_qty_per_transaksi", "max_qty_per_transaksi"]
    K_range = range(2, 8) # Mencari K dari 2 sampai 7
    
    # Tempat menyimpan K terbaik dari masing-masing snapshot
    best_k_per_snapshot = []
    
    # Siapkan folder output grafik
    output_dir = "grafik/k_optimal"
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    # =================================================================
    # BAGIAN 1: EVALUASI PER SNAPSHOT
    # =================================================================
    grouped = df.groupby(['periode_str', 'snapshot_type'])
    
    for (periode, snapshot_type), group_df in grouped:
        if len(group_df) < 10:
            continue
            
        X_scaled = StandardScaler().fit_transform(group_df[feature_cols].fillna(0))
        
        wcss_snap = []
        silhouette_snap = []
        
        for k in K_range:
            kmeans = KMeans(n_clusters=k, n_init="auto", random_state=42)
            cluster_labels = kmeans.fit_predict(X_scaled)
            wcss_snap.append(kmeans.inertia_)
            silhouette_snap.append(silhouette_score(X_scaled, cluster_labels))
        
        # Cari K terbaik di snapshot ini berdasarkan Silhouette tertinggi
        best_k_snap = K_range[np.argmax(silhouette_snap)]
        best_k_per_snapshot.append(best_k_snap)
        
        # Plot Grafik per Snapshot
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 5.5))
        
        ax1.plot(K_range, wcss_snap, 'bx-', linewidth=2, markersize=8)
        ax1.set_title(f'Elbow Method\n({periode} - {snapshot_type})', fontsize=11, fontweight='bold')
        ax1.set_xlabel('Jumlah Cluster (K)')
        ax1.set_ylabel('WCSS')
        ax1.grid(True)
        
        ax2.plot(K_range, silhouette_snap, 'ro-', linewidth=2, markersize=8)
        ax2.set_title(f'Silhouette Analysis (Best K = {best_k_snap})\n({periode} - {snapshot_type})', fontsize=11, fontweight='bold')
        ax2.set_xlabel('Jumlah Cluster (K)')
        ax2.set_ylabel('Silhouette Score')
        ax2.grid(True)
        
        plt.tight_layout()
        clean_filename = f"k_opt_{periode}_{snapshot_type}.png".replace(" ", "_")
        plt.savefig(f"{output_dir}/{clean_filename}", dpi=120, bbox_inches='tight')
        plt.close()
        print(f"✔ Selesai analisis stabilitas untuk: {periode} ({snapshot_type}) -> K Terbaik: {best_k_snap}")

    # =================================================================
    # BAGIAN 2: PENDEKATAN GLOBAL CLUSTERING
    # =================================================================
    print("\nMenjalankan Pendekatan Global Clustering (All Snapshots Combined)...")
    X_global_scaled = StandardScaler().fit_transform(df[feature_cols].fillna(0))
    
    wcss_global = []
    silhouette_global = []
    
    for k in K_range:
        kmeans = KMeans(n_clusters=k, n_init="auto", random_state=42)
        cluster_labels = kmeans.fit_predict(X_global_scaled)
        wcss_global.append(kmeans.inertia_)
        silhouette_global.append(silhouette_score(X_global_scaled, cluster_labels))
        
    best_k_global = K_range[np.argmax(silhouette_global)]
    
    # Plot Grafik Global
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 5.5))
    
    ax1.plot(K_range, wcss_global, 'bX-', linewidth=2, markersize=8)
    ax1.set_title('Elbow Method', fontsize=11, fontweight='bold')
    ax1.set_xlabel('Jumlah Cluster (K)')
    ax1.set_ylabel('WCSS (Inertia)')
    ax1.grid(True)
    
    ax2.plot(K_range, silhouette_global, 'ro-', linewidth=2, markersize=8)
    ax2.set_title(f'Silhouette Analysis (Best K = {best_k_global})', fontsize=11, fontweight='bold')
    ax2.set_xlabel('Jumlah Cluster (K)')
    ax2.set_ylabel('Silhouette Score')
    ax2.grid(True)
    
    plt.suptitle("Evaluasi K-Means Secara Global (Gabungan Seluruh Periode)", fontsize=14, fontweight='bold', y=0.98)
    
    plt.tight_layout()
    plt.savefig(f"{output_dir}/k_global_optimization_results.png", dpi=150, bbox_inches='tight')
    plt.close()

    # =================================================================
    # BAGIAN 3: KESIMPULAN & REKOMENDASI STABILITAS
    # =================================================================
    occurence_count = Counter(best_k_per_snapshot)
    k_paling_stabil = occurence_count.most_common(1)[0][0]
    frekuensi_stabil = occurence_count.most_common(1)[0][1]
    total_snapshot = len(best_k_per_snapshot)

    print("\n" + "="*60)
    print("KESIMPULAN AKHIR PENENTUAN NILAI K KONSISTEN")
    print("="*60)
    print(f"1. Rincian K terbaik di tiap periode: {dict(zip([f'{p} ({s})' for p, s in grouped.groups.keys()], best_k_per_snapshot))}")
    print(f"2. K yang paling STABIL (Sering Muncul) : K = {k_paling_stabil} (Muncul {frekuensi_stabil}x dari {total_snapshot} snapshot)")
    print(f"3. K terbaik versi GLOBAL DATA          : K = {best_k_global}")
    print("-"*60)
    
    if k_paling_stabil == best_k_global:
        print(f"REKOMENDASI FINAL: Gunakan K = {k_paling_stabil}")
        print("Alasan: Pendekatan stabilitas tren bulanan dan data global menghasilkan angka yang sama. Ini angka mutlak terkuat untuk BI Anda.")
    else:
        print(f"REKOMENDASI FINAL: Gunakan K = {best_k_global} (Pendekatan Global) atau K = {k_paling_stabil} (Pendekatan Stabilitas)")
        print("Tips BI: Jika Anda ingin murni melihat struktur makro pasar, pakai K Global. Jika ingin mengamankan konsistensi bulanan, pakai K Stabilitas.")
    print(f"Seluruh grafik evaluasi disimpan di: {output_dir}")

if __name__ == "__main__":
    find_k_optimal_comprehensive()
