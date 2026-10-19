-- Chương 7: index nhiều cột, thứ tự cột quyết định vùng phải quét.
DROP INDEX IF EXISTS vehicles_prov_listed_idx, vehicles_listed_prov_idx;

-- Q2 khi chưa có index phù hợp.
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, listed_at FROM vehicles
WHERE province = 'Đà Nẵng' AND listed_at >= '2025-01-01'
ORDER BY listed_at DESC LIMIT 20;

SELECT count(*) AS match_rows FROM vehicles WHERE province = 'Đà Nẵng' AND listed_at >= '2025-01-01';
SELECT count(*) AS date_rows FROM vehicles WHERE listed_at >= '2025-01-01';

-- Thứ tự A: tỉnh trước, ngày sau.
CREATE INDEX vehicles_prov_listed_idx ON vehicles (province, listed_at DESC);
ANALYZE vehicles;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, listed_at FROM vehicles
WHERE province = 'Đà Nẵng' AND listed_at >= '2025-01-01'
ORDER BY listed_at DESC LIMIT 20;
-- Không LIMIT: đếm hết vùng khớp.
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM vehicles WHERE province = 'Đà Nẵng' AND listed_at >= '2025-01-01';
DROP INDEX vehicles_prov_listed_idx;

-- Thứ tự B: ngày trước, tỉnh sau.
CREATE INDEX vehicles_listed_prov_idx ON vehicles (listed_at DESC, province);
ANALYZE vehicles;
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM vehicles WHERE province = 'Đà Nẵng' AND listed_at >= '2025-01-01';
DROP INDEX vehicles_listed_prov_idx;

-- PostgreSQL 18: skip scan. Index (province, listed_at) dùng được cả khi không lọc tỉnh,
-- bằng cách nhảy qua từng giá trị province (xem "Index Searches").
CREATE INDEX vehicles_prov_listed_idx ON vehicles (province, listed_at DESC);
ANALYZE vehicles;
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM vehicles WHERE listed_at >= '2026-09-29';
SELECT count(DISTINCT province) AS provinces FROM vehicles;
