-- Bài 15. GIN index là gì? Tìm biển số chứa một đoạn bất kỳ như thế nào?
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/gin-index-la-gi
\pset pager off

-- Bỏ mọi index mà các bài khác đã tạo, chỉ giữ index của khoá chính.
DO $$ DECLARE i text; BEGIN
  FOR i IN SELECT indexrelid::regclass::text FROM pg_index
           WHERE indrelid = 'vehicles'::regclass AND NOT indisprimary
  LOOP EXECUTE 'DROP INDEX ' || i; END LOOP;
END $$;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pageinspect;

\echo '--- Dung lượng bảng cùng index khoá chính, trước khi có GIN'
SELECT pg_size_pretty(pg_total_relation_size('vehicles')) AS chua_co_gin;

\echo '--- Không có GIN: quét cả bảng'
EXPLAIN (ANALYZE) SELECT * FROM vehicles WHERE plate LIKE '%600.5%';

\echo '--- Tạo GIN trên các mẩu ba ký tự'
CREATE INDEX vehicles_plate_trgm_idx ON vehicles USING GIN (plate gin_trgm_ops);
ANALYZE vehicles;
SELECT pg_size_pretty(pg_relation_size('vehicles_plate_trgm_idx')) AS gin,
       pg_size_pretty(pg_total_relation_size('vehicles'))           AS co_gin;

\echo '--- Có GIN: Bitmap Index Scan ra 1.008 ứng viên, kiểm lại còn 500'
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate LIKE '%600.5%';

\echo '--- Số biển có mỗi mẩu, và số biển có đủ cả ba (mất vài giây)'
SELECT count(*) FILTER (WHERE show_trgm(plate) @> ARRAY['600'])   AS mau_600,
       count(*) FILTER (WHERE show_trgm(plate) @> ARRAY['00 '])   AS mau_00_,
       count(*) FILTER (WHERE show_trgm(plate) @> ARRAY['  5'])   AS mau__5,
       count(*) FILTER (WHERE show_trgm(plate) @> ARRAY['600', '00 ', '  5']) AS du_ba_mau
FROM vehicles;

\echo '--- Bên trong GIN: n_entries là số mẩu khác nhau, n_data_pages là phần danh sách dòng'
SELECT n_entries, n_entry_pages, n_data_pages, n_total_pages
FROM gin_metapage_info(get_raw_page('vehicles_plate_trgm_idx', 0));

\echo '--- Chi phí ghi: chèn 100.000 xe vào bốn bản sao 200.000 xe'
CREATE TEMP TABLE xe_cu  AS SELECT * FROM vehicles ORDER BY id LIMIT 200000;
CREATE TEMP TABLE xe_moi AS SELECT * FROM vehicles ORDER BY id OFFSET 200000 LIMIT 100000;
CREATE TABLE w_khong (LIKE vehicles);
CREATE TABLE w_btree (LIKE vehicles);
CREATE TABLE w_gin_cho (LIKE vehicles);
CREATE TABLE w_gin_thang (LIKE vehicles);
INSERT INTO w_khong     SELECT * FROM xe_cu;
INSERT INTO w_btree     SELECT * FROM xe_cu;
INSERT INTO w_gin_cho   SELECT * FROM xe_cu;
INSERT INTO w_gin_thang SELECT * FROM xe_cu;
CREATE INDEX ON w_btree (plate);
CREATE INDEX w_gin_cho_idx   ON w_gin_cho   USING GIN (plate gin_trgm_ops);
CREATE INDEX w_gin_thang_idx ON w_gin_thang USING GIN (plate gin_trgm_ops) WITH (fastupdate = off);
VACUUM ANALYZE w_khong, w_btree, w_gin_cho, w_gin_thang;
\timing on
INSERT INTO w_khong     SELECT * FROM xe_moi;
INSERT INTO w_btree     SELECT * FROM xe_moi;
INSERT INTO w_gin_cho   SELECT * FROM xe_moi;
INSERT INTO w_gin_thang SELECT * FROM xe_moi;
\timing off

\echo '--- Phần còn nằm trong danh sách chờ, rồi dọn nốt'
SELECT n_pending_pages, n_pending_tuples
FROM gin_metapage_info(get_raw_page('w_gin_cho_idx', 0));
SHOW gin_pending_list_limit;
\timing on
SELECT gin_clean_pending_list('w_gin_cho_idx');
\timing off

DROP TABLE w_khong, w_btree, w_gin_cho, w_gin_thang;
