-- Bài 18. Vì sao index phình to theo thời gian?
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/vi-sao-index-phinh-to
-- Dùng một bảng riêng 200.000 xe (b), bảng vehicles không bị đụng tới.
\pset pager off
CREATE EXTENSION IF NOT EXISTS pgstattuple;
DROP TABLE IF EXISTS b;

CREATE TABLE b AS SELECT * FROM vehicles WHERE id <= 200000;
ALTER TABLE b ADD PRIMARY KEY (id);
CREATE INDEX b_price ON b (price_vnd);
CREATE INDEX b_plate ON b (plate);
VACUUM (ANALYZE) b;

\echo '--- Ban đầu'
SELECT pg_size_pretty(pg_relation_size('b')) AS bang,
       pg_size_pretty(pg_relation_size('b_price')) AS index_gia,
       pg_size_pretty(pg_relation_size('b_plate')) AS index_bien_so;

\echo '--- Sửa giá cả bảng ba lần: bảng và index to ra'
UPDATE b SET price_vnd = price_vnd + 1000000;
UPDATE b SET price_vnd = price_vnd + 1000000;
UPDATE b SET price_vnd = price_vnd + 1000000;
SELECT pg_size_pretty(pg_relation_size('b')) AS bang,
       pg_size_pretty(pg_relation_size('b_price')) AS index_gia,
       pg_size_pretty(pg_relation_size('b_plate')) AS index_bien_so;

\echo '--- VACUUM dọn phiên bản cũ, nhưng file không nhỏ lại'
VACUUM b;
SELECT pg_size_pretty(pg_relation_size('b')) AS bang,
       pg_size_pretty(pg_relation_size('b_price')) AS index_gia,
       (SELECT round(free_percent) FROM pgstattuple('b')) AS phan_tram_trong;
SELECT leaf_pages, round(avg_leaf_density) AS mat_do_page_la FROM pgstatindex('b_price');

\echo '--- UPDATE lần 4 dùng lại chỗ trống, bảng không to thêm'
UPDATE b SET price_vnd = price_vnd + 1000000;
SELECT pg_size_pretty(pg_relation_size('b')) AS bang,
       pg_size_pretty(pg_relation_size('b_price')) AS index_gia;

\echo '--- VACUUM FULL viết lại bảng và index (khoá bảng trong lúc chạy)'
VACUUM FULL b;
SELECT pg_size_pretty(pg_relation_size('b')) AS bang,
       pg_size_pretty(pg_relation_size('b_price')) AS index_gia,
       pg_size_pretty(pg_relation_size('b_plate')) AS index_bien_so;

DROP TABLE b;
