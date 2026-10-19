-- Chương 12: UPDATE tạo phiên bản mới; HOT; VACUUM; index phình.
CREATE EXTENSION IF NOT EXISTS pgstattuple;
CREATE EXTENSION IF NOT EXISTS pageinspect;
SET max_parallel_maintenance_workers = 0;

-- Hai bảng 200.000 xe giống nhau: một bảng đầy kín page (fillfactor 100, mặc định),
-- một bảng chừa 10% mỗi page (fillfactor 90).
DROP TABLE IF EXISTS u100, u90;
CREATE TABLE u100 WITH (fillfactor = 100) AS SELECT * FROM vehicles WHERE id <= 200000;
CREATE TABLE u90  WITH (fillfactor = 90)  AS SELECT * FROM vehicles WHERE id <= 200000;
ALTER TABLE u100 ADD PRIMARY KEY (id);  ALTER TABLE u90 ADD PRIMARY KEY (id);
CREATE INDEX u100_plate ON u100 (plate); CREATE INDEX u90_plate ON u90 (plate);
CREATE INDEX u100_price ON u100 (price_vnd); CREATE INDEX u90_price ON u90 (price_vnd);
VACUUM (ANALYZE) u100, u90;

-- Một UPDATE: phiên bản cũ vẫn nằm đó, phiên bản mới ở chỗ khác.
BEGIN;
SELECT ctid, xmin, xmax, seller_note IS NOT NULL AS has_note FROM u90 WHERE id = 1;
UPDATE u90 SET seller_note = 'Đã giảm giá' WHERE id = 1;
SELECT ctid, xmin FROM u90 WHERE id = 1;
SELECT lp, lp_flags, t_xmin, t_xmax, t_ctid FROM heap_page_items(get_raw_page('u90', 0)) WHERE lp IN (1) OR t_ctid = '(0,1)' OR lp > 24 ORDER BY lp;
ROLLBACK;

-- Sửa cột không có index (seller_note) cho 20.000 xe trên cả hai bảng.
UPDATE u100 SET seller_note = seller_note || ' (đã kiểm tra)' WHERE id % 10 = 0;
UPDATE u90  SET seller_note = seller_note || ' (đã kiểm tra)' WHERE id % 10 = 0;
SELECT pg_stat_force_next_flush();
SELECT relname, n_tup_upd, n_tup_hot_upd,
       round(100.0 * n_tup_hot_upd / nullif(n_tup_upd, 0), 1) AS hot_pct
FROM pg_stat_user_tables WHERE relname IN ('u100', 'u90') ORDER BY relname DESC;

-- Sửa cột CÓ index (price_vnd): không bao giờ là HOT.
UPDATE u90 SET price_vnd = price_vnd + 1000000 WHERE id % 10 = 1;
SELECT pg_stat_force_next_flush();
SELECT relname, n_tup_upd, n_tup_hot_upd FROM pg_stat_user_tables WHERE relname = 'u90';

-- Index phình: sửa giá toàn bộ bảng 3 lần, rồi đo trước và sau VACUUM, REINDEX.
DROP TABLE IF EXISTS b;
CREATE TABLE b AS SELECT * FROM vehicles WHERE id <= 200000;
ALTER TABLE b ADD PRIMARY KEY (id);
CREATE INDEX b_price ON b (price_vnd);
CREATE INDEX b_plate ON b (plate);
VACUUM (ANALYZE) b;
SELECT 'ban đầu' AS buoc, pg_size_pretty(pg_relation_size('b')) AS heap,
       pg_size_pretty(pg_relation_size('b_price')) AS price_idx, pg_size_pretty(pg_relation_size('b_plate')) AS plate_idx,
       (SELECT dead_tuple_count FROM pgstattuple('b')) AS dead;
UPDATE b SET price_vnd = price_vnd + 1000000;
UPDATE b SET price_vnd = price_vnd + 1000000;
UPDATE b SET price_vnd = price_vnd + 1000000;
SELECT 'sau 3 lần UPDATE' AS buoc, pg_size_pretty(pg_relation_size('b')) AS heap,
       pg_size_pretty(pg_relation_size('b_price')) AS price_idx, pg_size_pretty(pg_relation_size('b_plate')) AS plate_idx,
       (SELECT dead_tuple_count FROM pgstattuple('b')) AS dead;
VACUUM b;
SELECT 'sau VACUUM' AS buoc, pg_size_pretty(pg_relation_size('b')) AS heap,
       pg_size_pretty(pg_relation_size('b_price')) AS price_idx, pg_size_pretty(pg_relation_size('b_plate')) AS plate_idx,
       (SELECT dead_tuple_count FROM pgstattuple('b')) AS dead,
       (SELECT round(free_percent) FROM pgstattuple('b')) AS heap_free_pct;
SELECT 'b_price' AS idx, leaf_pages, avg_leaf_density FROM pgstatindex('b_price');
-- Ghi lại một lần nữa: dữ liệu mới dùng lại chỗ trống, bảng không phình thêm.
UPDATE b SET price_vnd = price_vnd + 1000000;
SELECT 'UPDATE lần 4 sau VACUUM' AS buoc, pg_size_pretty(pg_relation_size('b')) AS heap,
       pg_size_pretty(pg_relation_size('b_price')) AS price_idx;
VACUUM b;
REINDEX TABLE b;
VACUUM FULL b;
SELECT 'sau VACUUM FULL' AS buoc, pg_size_pretty(pg_relation_size('b')) AS heap,
       pg_size_pretty(pg_relation_size('b_price')) AS price_idx, pg_size_pretty(pg_relation_size('b_plate')) AS plate_idx;
DROP TABLE u100, u90, b;
