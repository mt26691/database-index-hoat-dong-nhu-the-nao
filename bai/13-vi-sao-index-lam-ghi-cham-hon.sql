-- Bài 13. Vì sao index làm INSERT và UPDATE chậm hơn?
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/vi-sao-index-lam-ghi-cham-hon
-- Dùng một bảng riêng vehicles_w, bảng vehicles không bị đụng tới.
\pset pager off
CREATE EXTENSION IF NOT EXISTS pgstattuple;
DROP TABLE IF EXISTS vehicles_w;
CREATE TABLE vehicles_w (LIKE vehicles);

\echo '--- Nạp 500.000 xe vào bảng chưa có index. Xem dòng WAL và Execution Time'
BEGIN;
EXPLAIN (ANALYZE, WAL, COSTS OFF)
INSERT INTO vehicles_w SELECT * FROM vehicles WHERE id <= 500000;
ROLLBACK;

\echo '--- Thêm 1 index (id)'
CREATE UNIQUE INDEX vehicles_w_id_idx ON vehicles_w (id);
BEGIN;
EXPLAIN (ANALYZE, WAL, COSTS OFF)
INSERT INTO vehicles_w SELECT * FROM vehicles WHERE id <= 500000;
ROLLBACK;

\echo '--- Thêm 2 index nữa (plate; province, listed_at), tổng cộng 3'
CREATE INDEX vehicles_w_plate_idx ON vehicles_w (plate);
CREATE INDEX vehicles_w_prov_listed_idx ON vehicles_w (province, listed_at DESC);
BEGIN;
EXPLAIN (ANALYZE, WAL, COSTS OFF)
INSERT INTO vehicles_w SELECT * FROM vehicles WHERE id <= 500000;
ROLLBACK;

\echo '--- Page split: id tăng dần chỉ ghi vào lá cuối, biển số rơi vào giữa cây'
INSERT INTO vehicles_w SELECT * FROM vehicles WHERE id <= 500000;
SELECT 'id' AS index, leaf_pages, avg_leaf_density FROM pgstatindex('vehicles_w_id_idx')
UNION ALL
SELECT 'plate', leaf_pages, avg_leaf_density FROM pgstatindex('vehicles_w_plate_idx');

\echo '--- Dựng lại index plate một lần trên dữ liệu đã có: ít page hơn, page đầy hơn'
REINDEX INDEX vehicles_w_plate_idx;
SELECT 'plate sau REINDEX' AS index, leaf_pages, avg_leaf_density FROM pgstatindex('vehicles_w_plate_idx');

\echo '--- Trên bảng vehicles: index nào chưa từng được đọc (idx_scan = 0) thì chỉ tốn công ghi'
SELECT indexrelname, idx_scan FROM pg_stat_user_indexes WHERE relname = 'vehicles';

DROP TABLE vehicles_w;
