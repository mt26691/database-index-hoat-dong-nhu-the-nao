-- Bài 15. GIN index là gì? Index đảo ngược tra từ mẩu ra dòng
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/gin-index-la-gi
\pset pager off
-- Một tiến trình cho kế hoạch dễ đọc; số page vẫn như khi chạy song song.
SET max_parallel_workers_per_gather = 0;

-- Bỏ mọi index mà các bài khác đã tạo, chỉ giữ index của khoá chính.
DO $$ DECLARE i text; BEGIN
  FOR i IN SELECT indexrelid::regclass::text FROM pg_index
           WHERE indrelid = 'vehicles'::regclass AND NOT indisprimary
  LOOP EXECUTE 'DROP INDEX ' || i; END LOOP;
END $$;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pageinspect;

\echo '--- B-tree thường: một mục cho mỗi dòng'
CREATE INDEX vehicles_plate_idx ON vehicles (plate);
\echo '--- GIN trên các mẩu ba ký tự'
CREATE INDEX vehicles_plate_trgm_idx ON vehicles USING gin (plate gin_trgm_ops);
ANALYZE vehicles;
SELECT pg_size_pretty(pg_relation_size('vehicles_plate_idx'))      AS btree,
       pg_size_pretty(pg_relation_size('vehicles_plate_trgm_idx')) AS gin;

\echo '--- Bên trong GIN: n_entries là số mẩu khác nhau, n_entry_pages là cây khoá, n_data_pages là danh sách dòng'
SELECT n_entries, n_entry_pages, n_data_pages, n_pending_pages, n_pending_tuples
FROM gin_metapage_info(get_raw_page('vehicles_plate_trgm_idx', 0));

\echo '--- Mẩu hiếm nhất và phổ biến nhất (mất vài giây)'
SELECT t AS mau, count(*) AS so_dong
FROM (SELECT unnest(show_trgm(plate)) AS t FROM vehicles) s
GROUP BY t ORDER BY count(*) LIMIT 3;
SELECT t AS mau, count(*) AS so_dong
FROM (SELECT unnest(show_trgm(plate)) AS t FROM vehicles) s
GROUP BY t ORDER BY count(*) DESC LIMIT 3;

\echo '--- Giao ba danh sách: Bitmap Index Scan ra 1.008 ứng viên'
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate LIKE '%600.5%';

\echo '--- Chi phí ghi: chèn 100.000 xe vào ba bản sao của vehicles_200k'
CREATE TEMP TABLE xe_moi AS SELECT * FROM vehicles WHERE id > 4900000;
CREATE TABLE w_btree (LIKE vehicles_200k);
CREATE TABLE w_gin_cho (LIKE vehicles_200k);
CREATE TABLE w_gin_thang (LIKE vehicles_200k);
INSERT INTO w_btree     SELECT * FROM vehicles_200k;
INSERT INTO w_gin_cho   SELECT * FROM vehicles_200k;
INSERT INTO w_gin_thang SELECT * FROM vehicles_200k;
CREATE INDEX ON w_btree (plate);
CREATE INDEX w_gin_cho_idx   ON w_gin_cho   USING gin (plate gin_trgm_ops);
CREATE INDEX w_gin_thang_idx ON w_gin_thang USING gin (plate gin_trgm_ops) WITH (fastupdate = off);
\timing on
INSERT INTO w_btree     SELECT * FROM xe_moi;
INSERT INTO w_gin_thang SELECT * FROM xe_moi;
INSERT INTO w_gin_cho   SELECT * FROM xe_moi;
\timing off

\echo '--- Những dòng còn nằm trong danh sách chờ'
SELECT n_pending_pages, n_pending_tuples
FROM gin_metapage_info(get_raw_page('w_gin_cho_idx', 0));
SHOW gin_pending_list_limit;

DROP TABLE w_btree, w_gin_cho, w_gin_thang;
