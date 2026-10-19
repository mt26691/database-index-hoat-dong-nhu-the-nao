-- Chương 10: partial index và expression index.
DROP INDEX IF EXISTS vehicles_province_idx, vehicles_price_idx, vehicles_prov_listed_idx,
  vehicles_unsold_idx, vehicles_plate_norm_idx;

-- Partial index: chỉ đưa vào index những xe còn đang bán.
SELECT count(*) FILTER (WHERE sold_at IS NULL) AS unsold, count(*) AS total FROM vehicles;
\timing on
CREATE INDEX vehicles_prov_listed_idx ON vehicles (province, listed_at DESC);
CREATE INDEX vehicles_unsold_idx ON vehicles (province, listed_at DESC) WHERE sold_at IS NULL;
\timing off
ANALYZE vehicles;
SELECT relname, pg_size_pretty(pg_relation_size(oid)) AS size, pg_relation_size(oid) / 8192 AS pages
FROM pg_class WHERE relname IN ('vehicles_prov_listed_idx', 'vehicles_unsold_idx');

-- Câu có sold_at IS NULL: planner chứng minh được câu khớp với điều kiện của index.
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, plate, price_vnd, listed_at FROM vehicles
WHERE province = 'Đà Nẵng' AND sold_at IS NULL
ORDER BY listed_at DESC LIMIT 20;

-- Câu không nói gì về sold_at: không dùng được partial index.
EXPLAIN SELECT id FROM vehicles WHERE province = 'Đà Nẵng' ORDER BY listed_at DESC LIMIT 20;
DROP INDEX vehicles_prov_listed_idx;
EXPLAIN SELECT id FROM vehicles WHERE province = 'Đà Nẵng' ORDER BY listed_at DESC LIMIT 20;

-- Expression index: người dùng gõ biển số không có dấu, ví dụ 47P60055.
SELECT plate AS p, replace(replace(plate, '-', ''), '.', '') AS norm FROM vehicles WHERE id = 12345 \gset
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM vehicles WHERE replace(replace(plate, '-', ''), '.', '') = :'norm';
\timing on
CREATE INDEX vehicles_plate_norm_idx ON vehicles ((replace(replace(plate, '-', ''), '.', '')));
\timing off
ANALYZE vehicles;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM vehicles WHERE replace(replace(plate, '-', ''), '.', '') = :'norm';
-- Viết biểu thức khác đi một chút là không khớp nữa.
EXPLAIN SELECT * FROM vehicles WHERE replace(replace(plate, '.', ''), '-', '') = :'norm';
SELECT pg_size_pretty(pg_relation_size('vehicles_plate_norm_idx')) AS norm_idx_size;
