"""Chương 9: quét tỷ lệ dòng khớp của `WHERE price_vnd < X` và ghi lại cost thật của planner
PostgreSQL 18 cho ba đường đọc, cùng thời gian chạy thật. Kết quả: results/09-planner-sweep.json.
Chạy: python3 planner_sweep.py   (cần container pgidx và index vehicles_price_idx của chương 9)."""
import json, re, subprocess, statistics, datetime

def psql(sql):
    r = subprocess.run(["docker", "exec", "-i", "pgidx", "psql", "-U", "lab", "-d", "lab", "-X", "-A", "-t"],
                       input=sql, capture_output=True, text=True, check=True)
    return r.stdout

BASE = "SET max_parallel_workers_per_gather = 0; SET jit = off;\n"
FORCE = {
    "seq":    "SET enable_indexscan = off; SET enable_bitmapscan = off;\n",
    "index":  "SET enable_seqscan = off; SET enable_bitmapscan = off;\n",
    "bitmap": "SET enable_seqscan = off; SET enable_indexscan = off;\n",
    "auto":   "",
}
NODE = {"Seq Scan": "seq", "Index Scan": "index", "Bitmap Heap Scan": "bitmap"}

def plan(force, x, analyze=False):
    opt = "(ANALYZE, BUFFERS, FORMAT JSON)" if analyze else "(FORMAT JSON)"
    out = psql(BASE + FORCE[force] + f"EXPLAIN {opt} SELECT * FROM vehicles WHERE price_vnd < {x};")
    return json.loads(out[out.index("["):])[0]

def scan_kind(node):
    while node:
        t = node["Node Type"]
        if t in NODE: return NODE[t]
        node = (node.get("Plans") or [None])[0]

total = int(psql("SELECT count(*) FROM vehicles;").strip())
pages = int(psql("SELECT pg_relation_size('vehicles') / 8192;").strip())
points = [0.0006, 0.001, 0.002, 0.003, 0.005, 0.0075, 0.01, 0.015, 0.02, 0.03, 0.05,
          0.075, 0.1, 0.15, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]
TIMED = set(points)
rows = []
for s in points:
    x = 200_000_000 + int(round(s * 1_800_000_000 / 1_000_000)) * 1_000_000
    actual = int(psql(f"SELECT count(*) FROM vehicles WHERE price_vnd < {x};").strip())
    row = {"selectivity": s, "threshold": x, "actualRows": actual}
    for k in ("seq", "index", "bitmap"):
        p = plan(k, x)["Plan"]
        row[k + "Cost"] = p["Total Cost"]
        row["estRows"] = p["Plan Rows"]
    row["chosen"] = scan_kind(plan("auto", x)["Plan"])
    if s in TIMED:
        for k in ("seq", "index", "bitmap"):
            times, bufs = [], None
            for _ in range(3):
                a = plan(k, x, analyze=True)
                times.append(a["Execution Time"])
                p = a["Plan"]; bufs = p.get("Shared Hit Blocks", 0) + p.get("Shared Read Blocks", 0)
            row[k + "Ms"] = round(statistics.median(times), 1)
            row[k + "Buffers"] = bufs
    rows.append(row)
    print(row, flush=True)

meta = {
    "postgres": psql("SHOW server_version;").strip(),
    "query": "SELECT * FROM vehicles WHERE price_vnd < :x",
    "tableRows": total, "heapPages": pages,
    "settings": {k: psql(f"SHOW {k};").strip() for k in
                 ("shared_buffers", "random_page_cost", "seq_page_cost", "cpu_tuple_cost",
                  "cpu_index_tuple_cost", "cpu_operator_cost", "effective_cache_size")},
    "notes": "max_parallel_workers_per_gather = 0, jit = off; cache nóng (bảng đã nằm trong page cache của máy); median 3 lần chạy",
    "machine": "Apple M5, Docker Desktop 10 CPU / 8 GB, postgres:18 image",
    "measuredAt": datetime.date.today().isoformat(),
}
json.dump({"meta": meta, "points": rows}, open("results/09-planner-sweep.json", "w"), ensure_ascii=False, indent=1)
