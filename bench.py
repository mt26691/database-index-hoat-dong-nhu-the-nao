"""Số thời gian dùng trong bài: mỗi câu chạy 1 lần làm nóng + 7 lần đo, lấy trung vị.
Kết quả: results/bench.json. Chạy sau seed.sql và lab chương 1, 4 (cần vehicles_10k, vehicles_200k, vehicles_plate_idx)."""
import json, subprocess, statistics, datetime

def psql(sql):
    r = subprocess.run(["docker", "exec", "-i", "pgidx", "psql", "-U", "lab", "-d", "lab", "-X", "-A", "-t", "-v", "ON_ERROR_STOP=1"],
                       input=sql, capture_output=True, text=True, check=True)
    return r.stdout

def explain(sql, prefix=""):
    out = psql(prefix + "EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) " + sql + ";")
    j = json.loads(out[out.index("["):])[0]
    p = j["Plan"]
    return j["Execution Time"], p.get("Shared Hit Blocks", 0) + p.get("Shared Read Blocks", 0), p["Node Type"]

def measure(sql, prefix="", n=7):
    explain(sql, prefix)
    runs = [explain(sql, prefix) for _ in range(n)]
    ms = [r[0] for r in runs]
    return {"sql": sql, "medianMs": round(statistics.median(ms), 3), "minMs": round(min(ms), 3),
            "maxMs": round(max(ms), 3), "buffers": runs[-1][1], "topNode": runs[-1][2], "runs": n}

plate = psql("SELECT plate FROM vehicles WHERE id = 5000;").strip()
res = {}
for t in ("vehicles_10k", "vehicles_200k", "vehicles"):
    res[f"ch01_seq_{t}"] = measure(f"SELECT * FROM {t} WHERE plate = '{plate}'", "SET enable_indexscan = off; SET enable_bitmapscan = off;\n")
res["ch01_index_plate"] = measure(f"SELECT * FROM vehicles WHERE plate = '{plate}'")
res["ch01_pkey"] = measure("SELECT * FROM vehicles WHERE id = 5000")

Q3 = ("SELECT id, plate, price_vnd, listed_at FROM vehicles WHERE province = 'Đà Nẵng' "
      "AND sold_at IS NULL ORDER BY listed_at DESC LIMIT 20")
psql("DROP INDEX IF EXISTS vehicles_unsold_idx; ANALYZE vehicles;")
res["ch13_before"] = measure(Q3)
psql("CREATE INDEX vehicles_unsold_idx ON vehicles (province, listed_at DESC) WHERE sold_at IS NULL; ANALYZE vehicles;")
res["ch13_after"] = measure(Q3)

# Chương 11: nạp 500.000 dòng, 3 lần mỗi cấu hình.
LOAD = """
DROP TABLE IF EXISTS vehicles_w; CREATE TABLE vehicles_w (LIKE vehicles);
{idx}
CHECKPOINT;
EXPLAIN (ANALYZE, WAL, FORMAT JSON) INSERT INTO vehicles_w SELECT * FROM vehicles WHERE id <= 500000;
"""
IDX = {
    0: "",
    1: "CREATE UNIQUE INDEX ON vehicles_w (id);",
    3: "CREATE UNIQUE INDEX ON vehicles_w (id); CREATE INDEX ON vehicles_w (plate); CREATE INDEX ON vehicles_w (province, listed_at DESC);",
    6: "CREATE UNIQUE INDEX ON vehicles_w (id); CREATE INDEX ON vehicles_w (plate); CREATE INDEX ON vehicles_w (province, listed_at DESC);"
       " CREATE INDEX ON vehicles_w (price_vnd); CREATE INDEX ON vehicles_w (brand, model); CREATE INDEX ON vehicles_w (mileage_km);",
}
for k, idx in IDX.items():
    ms, wal = [], []
    for _ in range(3):
        out = psql(LOAD.format(idx=idx))
        j = json.loads(out[out.index("["):])[0]
        ms.append(j["Execution Time"]); wal.append(j["Plan"].get("WAL Bytes", 0))
    res[f"ch11_load_{k}_idx"] = {"rows": 500000, "medianMs": round(statistics.median(ms)), "walMB": round(statistics.median(wal) / 1e6), "runs": 3}
psql("DROP TABLE IF EXISTS vehicles_w;")

meta = {"postgres": psql("SHOW server_version;").strip(), "machine": "Apple M5, Docker Desktop 10 CPU / 8 GB, postgres:18",
        "shared_buffers": psql("SHOW shared_buffers;").strip(), "cache": "nóng: bảng 1,5 GB nằm trong page cache của máy ảo Docker, lớn hơn shared_buffers",
        "measuredAt": datetime.date.today().isoformat()}
json.dump({"meta": meta, "results": res}, open("results/bench.json", "w"), ensure_ascii=False, indent=1)
for k, v in res.items(): print(k, v.get("medianMs"), v.get("minMs"), v.get("maxMs"), v.get("buffers"), v.get("walMB"), v.get("topNode"))
