-- Bài 17. UPDATE trong PostgreSQL hoạt động như thế nào?
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/update-trong-postgresql-hoat-dong-nhu-the-nao
-- Dùng các bảng riêng 200.000 xe (u100, u90), bảng vehicles chỉ bị sửa trong một transaction rồi ROLLBACK.
\pset pager off
CREATE EXTENSION IF NOT EXISTS pageinspect;
DROP TABLE IF EXISTS u100, u90;

\echo '--- Sửa một cột không có index, địa chỉ của dòng vẫn đổi (ROLLBACK để trả bảng về như cũ)'
BEGIN;
SELECT ctid FROM vehicles WHERE id = 3;
UPDATE vehicles SET mileage_km = mileage_km + 1 WHERE id = 3;
SELECT ctid FROM vehicles WHERE id = 3;
ROLLBACK;

\echo '--- Hai bảng giống nhau: u100 lấp kín page, u90 chừa 10% mỗi page'
CREATE TABLE u100 WITH (fillfactor = 100) AS SELECT * FROM vehicles WHERE id <= 200000;
CREATE TABLE u90  WITH (fillfactor = 90)  AS SELECT * FROM vehicles WHERE id <= 200000;
ALTER TABLE u100 ADD PRIMARY KEY (id);
ALTER TABLE u90  ADD PRIMARY KEY (id);
CREATE INDEX ON u100 (plate);     CREATE INDEX ON u90 (plate);
CREATE INDEX ON u100 (price_vnd); CREATE INDEX ON u90 (price_vnd);
VACUUM (ANALYZE) u100, u90;

\echo '--- Sửa ghi chú xe 1 trên u90, rồi xem page 0: phiên bản cũ trỏ sang phiên bản mới cùng page'
UPDATE u90 SET seller_note = seller_note || ' (đã kiểm tra)' WHERE id = 1;
SELECT lp, t_xmin, t_xmax, t_ctid
FROM heap_page_items(get_raw_page('u90', 0))
WHERE lp = 1 OR t_ctid = (SELECT ctid FROM u90 WHERE id = 1);

\echo '--- Sửa ghi chú (cột không có index) của 20.000 xe: bảng còn chỗ thì UPDATE thành HOT'
UPDATE u100 SET seller_note = seller_note || ' (đã kiểm tra)' WHERE id % 10 = 0;
UPDATE u90  SET seller_note = seller_note || ' (đã kiểm tra)' WHERE id % 10 = 0;
SELECT pg_stat_force_next_flush();
SELECT relname, n_tup_upd, n_tup_hot_upd,
       round(100.0 * n_tup_hot_upd / n_tup_upd, 1) AS hot_percent
FROM pg_stat_user_tables WHERE relname IN ('u100', 'u90') ORDER BY relname DESC;

\echo '--- Sửa giá (cột có index) của 20.000 xe trên u90: số lần HOT không tăng'
UPDATE u90 SET price_vnd = price_vnd + 1000000 WHERE id % 10 = 1;
SELECT pg_stat_force_next_flush();
SELECT relname, n_tup_upd, n_tup_hot_upd FROM pg_stat_user_tables WHERE relname = 'u90';

DROP TABLE u100, u90;
