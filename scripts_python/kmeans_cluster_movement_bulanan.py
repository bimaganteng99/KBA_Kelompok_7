import pandas as pd
from clickhouse_driver import Client
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler
import os

CH_HOST = os.getenv('CH_HOST', 'localhost')
CH_PORT = os.getenv('CH_PORT', '9000')

# definisi KPI
RECENCY_DAYS = 30
QTY_MIN = 10

# koneksi ClickHouse
ch = Client(host=CH_HOST, port=CH_PORT, user="default", password="")

FEATURE_TABLE = "kba_silver.silver_fitur_movement_bulanan"
OUT_TABLE = "kba_silver.silver_slow_moving_bulanan"

# ambil feature data dari silver
# Ambil feature data dari silver dengan kolom snapshot_type
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
  jeda_hari_dari_transaksi_terakhir
FROM {FEATURE_TABLE}
"""

data = ch.execute(query)

cols = [
    "periode_bulan", "id_produk", "snapshot_date", "snapshot_type", "frekuensi_transaksi",
    "total_qty_terjual_keluar", "rata2_qty_per_transaksi",
    "max_qty_per_transaksi", "jeda_hari_dari_transaksi_terakhir",
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
    active_mask = temp_group["frekuensi_transaksi"] > 0
    df_active = temp_group[active_mask].copy()
    df_dead = temp_group[~active_mask].copy()

    if len(df_active) >= 3:
        X = df_active[feature_cols].fillna(0.0)
        X_scaled = StandardScaler().fit_transform(X)
        kmeans = KMeans(n_clusters=3, random_state=42, n_init="auto")
        df_active["cluster_id"] = kmeans.fit_predict(X_scaled)
        
        # Penamaan Segment Berdasarkan Profil di bulan tersebut
        prof = df_active.groupby("cluster_id")[feature_cols].mean()
        freq_rank = prof["frekuensi_transaksi"].rank(method="dense")
        avg_rank = prof["rata2_qty_per_transaksi"].rank(method="dense")
        
        seg_map = {}
        for cid in prof.index:
            if freq_rank[cid] == freq_rank.max() and avg_rank[cid] == avg_rank.min():
                seg_map[int(cid)] = "frequent_small"
            elif freq_rank[cid] == freq_rank.min() and avg_rank[cid] == avg_rank.max():
                seg_map[int(cid)] = "rare_bulk"
            else:
                seg_map[int(cid)] = "balanced_regular"
        df_active["demand_segment"] = df_active["cluster_id"].map(seg_map)
    else:
        df_active["cluster_id"] = -1
        df_active["demand_segment"] = "awaiting_more_sales"
    
    # produk mati
    df_dead["cluster_id"] = -2  # ID khusus untuk dead stock
    df_dead["demand_segment"] = "dead_stock"

    final_df_list.append(pd.concat([df_active, df_dead]))

df_final = pd.concat(final_df_list)

# Tulis output ke ClickHouse
# Tambahkan snapshot_type String ke skema tabel
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

ch.execute(f"TRUNCATE TABLE {OUT_TABLE}") # Hapus isi tapi simpan struktur

# SEHARUSNYA (Lengkap sesuai skema tabel)
records = df_final[[
    "periode_bulan", "snapshot_date", "snapshot_type", "id_produk", "cluster_id", "demand_segment", 
    "is_slow_moving_kpi", "kpi_reason", "frekuensi_transaksi", "total_qty_terjual_keluar", 
    "rata2_qty_per_transaksi", "max_qty_per_transaksi", "jeda_hari_dari_transaksi_terakhir"
]].to_dict("records")

ch.execute(f"INSERT INTO {OUT_TABLE} VALUES", records)

print("Selesai!")
print(f"- Features: {FEATURE_TABLE}")
print(f"- Output  : {OUT_TABLE}")
print(f"- KPI params: RECENCY_DAYS={RECENCY_DAYS}, QTY_MIN={QTY_MIN}")
print("Ringkasan KPI (jumlah baris):")
print(df_final["is_slow_moving_kpi"].value_counts(dropna=False).sort_index())
print("\nRingkasan segment:")
print(df_final["demand_segment"].value_counts(dropna=False))