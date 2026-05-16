import pandas as pd
from clickhouse_driver import Client
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler
import os
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np

CH_HOST = os.getenv('CH_HOST', 'localhost')
CH_PORT = os.getenv('CH_PORT', '9000')

# definisi KPI
RECENCY_DAYS = 30
QTY_MIN = 10

# koneksi ClickHouse
ch = Client(host=CH_HOST, port=CH_PORT, user="default", password="")

FEATURE_TABLE = "kba_silver.silver_fitur_movement_bulanan"
OUT_TABLE = "kba_silver.silver_slow_moving_bulanan"

# Ambil feature data dari silver
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
    raise SystemExit(f"Tabel feature kosong: {FEATURE_TABLE}. Jalankan dbt run (silver) dulu.")

# KPI Slow Moving
df["kpi_recency_hit"] = (df["jeda_hari_dari_transaksi_terakhir"] >= RECENCY_DAYS)
df["kpi_qty_hit"] = (df["total_qty_terjual_keluar"] < QTY_MIN)
df["is_slow_moving_kpi"] = ((df["kpi_recency_hit"] | df["kpi_qty_hit"]) & (df["total_qty_terjual_keluar"] < 50)).astype(int)

def _reason(row):
    if row["kpi_recency_hit"] and row["kpi_qty_hit"]:
        return "recency_and_qty"
    if row["kpi_recency_hit"]:
        return "recency"
    if row["kpi_qty_hit"]:
        return "qty"
    return "none"

df["kpi_reason"] = df.apply(_reason, axis=1)

# Clustering (SEGMENTASI)

feature_cols = ["frekuensi_transaksi", "total_qty_terjual_keluar", "rata2_qty_per_transaksi", "max_qty_per_transaksi"]
final_df_list = []


for bulan, group in df.groupby("snapshot_date"):
    temp_group = group.copy()

    # Pisahkan produk aktif dan mati
    # 1. Produk dengan transaksi (Masuk Clustering)
    active_mask = temp_group["frekuensi_transaksi"] > 0
    df_active = temp_group[active_mask].copy()

    # 2. Produk TANPA transaksi tapi ADA STOK
    dead_mask = (~active_mask) & (temp_group["stok_akhir"] > 0)
    df_dead = temp_group[dead_mask].copy()

    # 3. Produk TANPA transaksi dan TANPA STOK
    oos_mask = (~active_mask) & (temp_group["stok_akhir"] <= 0)
    df_oos = temp_group[oos_mask].copy()

    if len(df_active) >= 3:
        X = df_active[feature_cols].fillna(0.0)
        X_scaled = StandardScaler().fit_transform(X)
        kmeans = KMeans(n_clusters=3, random_state=42, n_init="auto")
        df_active["cluster_id"] = kmeans.fit_predict(X_scaled)
        
        prof = df_active.groupby("cluster_id")[feature_cols].mean()
        avg_rank = prof["rata2_qty_per_transaksi"].rank(method="dense")
        
        # Cari tahu cluster_id mana yang memiliki rata-rata frekuensi tertinggi dan terendah
        highest_freq_cid = prof["frekuensi_transaksi"].idxmax()
        lowest_freq_cid = prof["frekuensi_transaksi"].idxmin()

        # Cari tahu cluster_id untuk rata-rata qty terbanyak
        highest_avg_qty_cid = prof["rata2_qty_per_transaksi"].idxmax()

        seg_map = {}
        for cid in prof.index:
            if cid == highest_freq_cid:
                seg_map[int(cid)] = "frequent_small"
            elif cid == highest_avg_qty_cid:
                seg_map[int(cid)] = "rare_bulk"
            else:
                seg_map[int(cid)] = "balanced_regular"
        df_active["demand_segment"] = df_active["cluster_id"].map(seg_map)
    else:
        df_active["cluster_id"] = -1
        df_active["demand_segment"] = "awaiting_more_sales"
    
    # Beri label untuk kategori non-aktif
    df_oos["cluster_id"] = -3
    df_oos["demand_segment"] = "no_sales_and_stock"

    # produk mati
    df_dead["cluster_id"] = -2
    df_dead["demand_segment"] = "dead_stock"

    final_df_list.append(pd.concat([df_active, df_oos, df_dead]))

df_final = pd.concat(final_df_list)

def save_multi_period_plots(df_to_plot):
    plot_data = df_to_plot.copy()
    
    if plot_data.empty:
        print("Data tidak cukup untuk visualisasi.")
        return
    
    output_dir = "grafik"
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    plot_data['periode_str'] = plot_data['periode_bulan'].astype(str)

    def add_jitter(series):
        return series + np.random.normal(0, 0.05, size=len(series))
    
    plot_data['x_jittered'] = add_jitter(plot_data['frekuensi_transaksi'])
    plot_data['y_jittered'] = add_jitter(plot_data['rata2_qty_per_transaksi'])

    sns.set_theme(style="whitegrid")

    # Grouping berdasarkan Periode dan Snapshot
    grouped = plot_data.groupby(['periode_str', 'snapshot_type'])

    for (periode, snapshot), group_df in grouped:
        # 1. Inisialisasi figure per grafik
        plt.figure(figsize=(10, 7))

        palette_colors = {
            "frequent_small": "green",
            "rare_bulk": "orange",
            "balanced_regular": "blue",
            "dead_stock": "red",
            "awaiting_more_sales": "grey",
            "no_sales_and_stock": "black"
        }
        
        # 2. Gambar scatter plot
        sns.scatterplot(
            data=group_df,
            x="x_jittered", 
            y="y_jittered",
            hue="demand_segment",
            size="total_qty_terjual_keluar",  # Ukuran lingkaran berdasarkan total qty
            sizes=(50, 500),           # Rentang ukuran lingkaran (min, max)
            palette=palette_colors,
            alpha=0.6,
            edgecolor="w",
            linewidth=0.5
        )
        
        plt.margins(x=0.1, y=0.1)
        
        # --- Skala Logaritmik ---
        plt.xscale('symlog', linthresh=1)
        plt.yscale('symlog', linthresh=1)

        plt.axvline(0, color='red', linestyle='--', alpha=0.3)
        plt.axhline(0, color='red', linestyle='--', alpha=0.3)
        
        # 3. Judul dan Label
        plt.title(f"Clustering: {periode} ({snapshot})", fontsize=14)
        plt.xlabel("Freq Transaksi")
        plt.ylabel("Avg Qty per Transaksi")
        plt.legend(title="Legend", bbox_to_anchor=(1.05, 1), loc='upper left')
        plt.tight_layout()
        
        # 4. Buat nama file
        clean_filename = f"clustering_{periode}_{snapshot}.png".replace(" ", "_")
        filepath = os.path.join(output_dir, clean_filename)
        
        plt.savefig(filepath, dpi=300, bbox_inches='tight')
        plt.close()
        
        print(f"Berhasil menyimpan: {filepath}")

# Panggil fungsi
save_multi_period_plots(df_final)

# Tulis output ke ClickHouse
ch.execute(f"""
    CREATE TABLE IF NOT EXISTS {OUT_TABLE} (
      periode_bulan Date,
      snapshot_date Date,
      snapshot_type String,
      id_produk Int32, 
      cluster_id Int32, 
      demand_segment String,
      is_slow_moving_kpi UInt8, 
      kpi_reason String, 
      frekuensi_transaksi Float64,
      total_qty_terjual_keluar Float64, 
      rata2_qty_per_transaksi Float64,
      max_qty_per_transaksi Float64, 
      jeda_hari_dari_transaksi_terakhir Int32
    ) ENGINE = MergeTree() ORDER BY (snapshot_date, id_produk)
""")

ch.execute(f"TRUNCATE TABLE {OUT_TABLE}")

records = df_final[[
    "periode_bulan", "snapshot_date", "snapshot_type", "id_produk", "cluster_id", "demand_segment", 
    "is_slow_moving_kpi", "kpi_reason", "frekuensi_transaksi", "total_qty_terjual_keluar", 
    "rata2_qty_per_transaksi", "max_qty_per_transaksi", "jeda_hari_dari_transaksi_terakhir"
]].values.tolist()

ch.execute(f"INSERT INTO {OUT_TABLE} VALUES", records)

print("Selesai!")
print(f"- Features: {FEATURE_TABLE}")
print(f"- Output  : {OUT_TABLE}")
print(f"- KPI params: RECENCY_DAYS={RECENCY_DAYS}, QTY_MIN={QTY_MIN}")
print("Ringkasan KPI (jumlah baris):")
print(df_final["is_slow_moving_kpi"].value_counts(dropna=False).sort_index())
print("\nRingkasan segment:")
print(df_final["demand_segment"].value_counts(dropna=False))