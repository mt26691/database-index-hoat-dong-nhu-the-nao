-- Bài 21. HOT update là gì?
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/hot-update-la-gi
-- Dùng hai bảng riêng 200.000 xe (u100, u90), bảng vehicles không bị đụng tới.
-- Mỗi bảng có hai index B-tree: khoá chính id và biển số.
\pset pager off
DROP TABLE IF EXISTS u100, u90;

\echo '--- Hai bảng giống nhau: u100 lấp kín page (mặc định), u90 chừa 10% mỗi page'
CREATE TABLE u100 WITH (fillfactor = 100) AS SELECT * FROM vehicles WHERE id <= 200000 ORDER BY id;
CREATE TABLE u90  WITH (fillfactor = 90)  AS SELECT * FROM vehicles WHERE id <= 200000 ORDER BY id;
ALTER TABLE u100 ADD PRIMARY KEY (id);
ALTER TABLE u90  ADD PRIMARY KEY (id);
CREATE INDEX ON u100 (plate);
CREATE INDEX ON u90 (plate);
VACUUM (ANALYZE) u100, u90;
SELECT relname, pg_size_pretty(pg_relation_size(oid)) AS bang_luc_tao
FROM pg_class WHERE relname IN ('u100', 'u90') ORDER BY relname DESC;

\echo '--- Sửa ghi chú (cột không có index) của 20.000 xe trên cả hai bảng'
UPDATE u100 SET seller_note = seller_note || ' Đã kiểm tra.' WHERE id % 10 = 0;
UPDATE u90  SET seller_note = seller_note || ' Đã kiểm tra.' WHERE id % 10 = 0;
SELECT pg_stat_force_next_flush();
SELECT relname, n_tup_upd, n_tup_hot_upd,
       round(100.0 * n_tup_hot_upd / n_tup_upd, 1) AS phan_tram_hot,
       n_tup_newpage_upd AS sang_page_khac
FROM pg_stat_user_tables WHERE relname IN ('u100', 'u90') ORDER BY relname DESC;

\echo '--- Sửa biển số (cột có index) của 20.000 xe khác trên u90: gần hết phiên bản mới vẫn nằm trong page cũ, nhưng số lần HOT không tăng'
UPDATE u90 SET plate = '99A-' || lpad(id::text, 6, '0') WHERE id % 10 = 1;
SELECT pg_stat_force_next_flush();
SELECT relname, n_tup_upd, n_tup_hot_upd, n_tup_newpage_upd AS sang_page_khac
FROM pg_stat_user_tables WHERE relname = 'u90';

DROP TABLE u100, u90;
