-- Bài 14. Vì sao index phình to theo thời gian?
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/vi-sao-index-phinh-to
-- Dùng các bảng riêng 200.000 xe (u100, u90, b), bảng vehicles không bị đụng tới.
\pset pager off
CREATE EXTENSION IF NOT EXISTS pgstattuple;
DROP TABLE IF EXISTS u100, u90, b;

\echo '--- Hai bảng giống nhau: u100 đầy kín page, u90 chừa 10% mỗi page'
CREATE TABLE u100 WITH (fillfactor = 100) AS SELECT * FROM vehicles WHERE id <= 200000;
CREATE TABLE u90  WITH (fillfactor = 90)  AS SELECT * FROM vehicles WHERE id <= 200000;
ALTER TABLE u100 ADD PRIMARY KEY (id);
ALTER TABLE u90  ADD PRIMARY KEY (id);
CREATE INDEX ON u100 (plate);     CREATE INDEX ON u90 (plate);
CREATE INDEX ON u100 (price_vnd); CREATE INDEX ON u90 (price_vnd);
VACUUM (ANALYZE) u100, u90;

\echo '--- Sửa cột không có index (seller_note): bảng còn chỗ thì UPDATE thành HOT'
UPDATE u100 SET seller_note = seller_note || ' (đã kiểm tra)' WHERE id % 10 = 0;
UPDATE u90  SET seller_note = seller_note || ' (đã kiểm tra)' WHERE id % 10 = 0;
SELECT pg_stat_force_next_flush();
SELECT relname, n_tup_upd, n_tup_hot_upd
FROM pg_stat_user_tables WHERE relname IN ('u100', 'u90') ORDER BY relname DESC;

\echo '--- Sửa cột có index (price_vnd): không bao giờ là HOT'
UPDATE u90 SET price_vnd = price_vnd + 1000000 WHERE id % 10 = 1;
SELECT pg_stat_force_next_flush();
SELECT relname, n_tup_upd, n_tup_hot_upd FROM pg_stat_user_tables WHERE relname = 'u90';

\echo '--- Sửa giá cả bảng ba lần: bảng và index phình ra'
CREATE TABLE b AS SELECT * FROM vehicles WHERE id <= 200000;
ALTER TABLE b ADD PRIMARY KEY (id);
CREATE INDEX b_price ON b (price_vnd);
CREATE INDEX b_plate ON b (plate);
VACUUM (ANALYZE) b;
SELECT 'ban đầu' AS buoc, pg_size_pretty(pg_relation_size('b')) AS bang,
       pg_size_pretty(pg_relation_size('b_price')) AS index_price;
UPDATE b SET price_vnd = price_vnd + 1000000;
UPDATE b SET price_vnd = price_vnd + 1000000;
UPDATE b SET price_vnd = price_vnd + 1000000;
SELECT 'sau 3 lần UPDATE' AS buoc, pg_size_pretty(pg_relation_size('b')) AS bang,
       pg_size_pretty(pg_relation_size('b_price')) AS index_price,
       (SELECT dead_tuple_count FROM pgstattuple('b')) AS dong_chet;

\echo '--- VACUUM không làm file nhỏ lại, nhưng lần ghi sau dùng lại chỗ trống'
VACUUM b;
UPDATE b SET price_vnd = price_vnd + 1000000;
SELECT 'UPDATE lần 4 sau VACUUM' AS buoc, pg_size_pretty(pg_relation_size('b')) AS bang,
       pg_size_pretty(pg_relation_size('b_price')) AS index_price;

\echo '--- VACUUM FULL viết lại bảng và index, trả chỗ cho hệ điều hành (khoá bảng trong lúc chạy)'
VACUUM FULL b;
SELECT 'sau VACUUM FULL' AS buoc, pg_size_pretty(pg_relation_size('b')) AS bang,
       pg_size_pretty(pg_relation_size('b_price')) AS index_price;

DROP TABLE u100, u90, b;
