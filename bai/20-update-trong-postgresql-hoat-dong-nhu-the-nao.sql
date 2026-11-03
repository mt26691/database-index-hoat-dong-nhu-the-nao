-- Bài 20. UPDATE trong PostgreSQL hoạt động như thế nào?
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/update-trong-postgresql-hoat-dong-nhu-the-nao
-- Dùng một bảng riêng 200.000 xe (u), bảng vehicles không bị đụng tới.
\pset pager off
CREATE EXTENSION IF NOT EXISTS pageinspect;
DROP TABLE IF EXISTS u;

CREATE TABLE u AS SELECT * FROM vehicles WHERE id <= 200000 ORDER BY id;
ALTER TABLE u ADD PRIMARY KEY (id);
CREATE INDEX u_plate_idx ON u (plate);
VACUUM (ANALYZE) u;

\echo '--- Xe 13E-832.74 đang rao 500 triệu'
SELECT id, plate, price_vnd, ctid FROM u WHERE id = 1046;

\echo '--- Đổi giá thành 480 triệu: phiên bản mới nằm ở địa chỉ khác'
BEGIN;
UPDATE u SET price_vnd = 480000000 WHERE id = 1046;
SELECT id, plate, price_vnd, ctid FROM u WHERE id = 1046;

\echo '--- Phiên bản cũ vẫn ở chỗ cũ, được đánh dấu là đã bị thay và chỉ sang phiên bản mới'
SELECT lp, t_xmax <> 0 AS da_bi_thay, t_ctid AS phien_ban_moi
FROM heap_page_items(get_raw_page('u', 40))
WHERE lp = 6;
COMMIT;

\echo '--- Sửa ghi chú của cả 200.000 xe: không biển số nào đổi, nhưng index biển số vẫn to ra'
SELECT pg_size_pretty(pg_relation_size('u_plate_idx')) AS index_bien_so;
UPDATE u SET seller_note = seller_note || ' Đã kiểm tra.';
SELECT pg_size_pretty(pg_relation_size('u_plate_idx')) AS index_bien_so;

DROP TABLE u;
