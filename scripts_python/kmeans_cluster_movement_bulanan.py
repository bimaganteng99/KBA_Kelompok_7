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
query = f"""
SELECT
  id_produk,
  periode_bulan,
  frekuensi_transaksi,
  total_qty_terjual_keluar,
  rata2_qty_per_transaksi,
  max_qty_per_transaksi,
  jeda_hari_dari_transaksi_terakhir
FROM {FEATURE_TABLE}
"""
data = ch.execute(query)

cols = [
    "id_produk",
    "periode_bulan",
    "frekuensi_transaksi",
    "total_qty_terjual_keluar",
    "rata2_qty_per_transaksi",
    "max_qty_per_transaksi",
    "jeda_hari_dari_transaksi_terakhir",
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


for bulan, group in df.groupby("periode_bulan"):
    temp_group = group.copy()
    if len(temp_group) >= 3:
        X = temp_group[feature_cols].fillna(0.0)
        X_scaled = StandardScaler().fit_transform(X)
        kmeans = KMeans(n_clusters=3, random_state=42, n_init="auto")
        temp_group["cluster_id"] = kmeans.fit_predict(X_scaled)
        
        # Penamaan Segment Berdasarkan Profil di bulan tersebut
        prof = temp_group.groupby("cluster_id")[feature_cols].mean()
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
        temp_group["demand_segment"] = temp_group["cluster_id"].map(seg_map)
    else:
        temp_group["cluster_id"] = -1
        temp_group["demand_segment"] = "insufficient_data"
    
    final_df_list.append(temp_group)

df_final = pd.concat(final_df_list)

# Tulis output ke ClickHouse
ch.execute(f"""
    CREATE TABLE IF NOT EXISTS {OUT_TABLE} (
      periode_bulan Date, id_produk Int32, cluster_id Int32, demand_segment String,
      is_slow_moving_kpi UInt8, kpi_reason String, frekuensi_transaksi Float64,
      total_qty_terjual_keluar Float64, rata2_qty_per_transaksi Float64,
      max_qty_per_transaksi Float64, jeda_hari_dari_transaksi_terakhir Int32
    ) ENGINE = MergeTree() ORDER BY (periode_bulan, id_produk)
""")

ch.execute(f"TRUNCATE TABLE {OUT_TABLE}") # Hapus isi tapi simpan struktur

records = df_final[[
    "periode_bulan", "id_produk", "cluster_id", "demand_segment", "is_slow_moving_kpi",
    "kpi_reason", "frekuensi_transaksi", "total_qty_terjual_keluar", "rata2_qty_per_transaksi",
    "max_qty_per_transaksi", "jeda_hari_dari_transaksi_terakhir"
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