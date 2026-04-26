import pandas as pd
from clickhouse_driver import Client
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler

# koneksi ClickHouse
ch = Client(host="localhost", port=9000, user="default", password="")

FEATURE_TABLE = "kba_silver.silver_fitur_movement_bulanan"
OUT_TABLE = "kba_silver.silver_kluster_slow_moving_bulanan"

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

if len(df) < 3:
    raise SystemExit("Data kurang dari 3 baris; KMeans n_clusters=3 tidak bisa dijalankan.")

# fitur untuk clustering
feature_cols = [
    "frekuensi_transaksi",
    "total_qty_terjual_keluar",
    "rata2_qty_per_transaksi",
    "max_qty_per_transaksi",
    "jeda_hari_dari_transaksi_terakhir",
]
X = df[feature_cols].fillna(0.0)

# scaling
scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)

# KMeans
kmeans = KMeans(n_clusters=3, random_state=42, n_init="auto")
df["cluster_id"] = kmeans.fit_predict(X_scaled)

# tentukan label cluster pakai skor gabungan
X_scaled_df = pd.DataFrame(X_scaled, columns=feature_cols, index=df.index)
cluster_profile = (
    X_scaled_df.assign(cluster_id=df["cluster_id"])
    .groupby("cluster_id")
    .mean()
)

# skor moving: gabungan frekuensi + qty
cluster_profile["score_moving"] = (
    0.6 * cluster_profile["frekuensi_transaksi"] +
    0.4 * cluster_profile["total_qty_terjual_keluar"]
)

rank = cluster_profile["score_moving"].sort_values()  # rendah -> tinggi
slow_cluster = int(rank.index[0])
medium_cluster = int(rank.index[1])
fast_cluster = int(rank.index[2])

df["label_cluster"] = df["cluster_id"].map({
    slow_cluster: "slow_moving",
    medium_cluster: "medium_moving",
    fast_cluster: "fast_moving",
})
df["is_slow_moving"] = (df["cluster_id"] == slow_cluster).astype(int)

# tulis ke ClickHouse
ch.execute(f"DROP TABLE IF EXISTS {OUT_TABLE}")
ch.execute(
    f"""
    CREATE TABLE {OUT_TABLE} (
      periode_bulan Date,
      id_produk Int32,
      cluster_id Int32,
      is_slow_moving UInt8,
      label_cluster String
    )
    ENGINE = MergeTree()
    ORDER BY (periode_bulan, id_produk)
    """
)

records = df[["periode_bulan", "id_produk", "cluster_id", "is_slow_moving", "label_cluster"]].to_dict("records")
ch.execute(f"INSERT INTO {OUT_TABLE} VALUES", records)

print("Selesai!")
print(f"- Features: {FEATURE_TABLE}")
print(f"- Output  : {OUT_TABLE}")
print(f"- slow_cluster_id = {slow_cluster}")
print(cluster_profile[["score_moving"]])