-- Bài 8. Vì sao nhiều dòng khớp thì Index Scan chậm?
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/index-scan-nhieu-dong-bitmap-heap-scan
\pset pager off

-- Bỏ mọi index mà các bài khác đã tạo, chỉ giữ index của khoá chính.
DO $$ DECLARE i text; BEGIN
  FOR i IN SELECT indexrelid::regclass::text FROM pg_index
           WHERE indrelid = 'vehicles'::regclass AND NOT indisprimary
  LOOP EXECUTE 'DROP INDEX ' || i; END LOOP;
END $$;
CREATE INDEX vehicles_plate_idx ON vehicles (plate);

\echo '--- 214 biển số liền nhau trong index nằm trên bao nhiêu page của bảng? (172)'
SELECT count(*) AS rows, count(DISTINCT (ctid::text::point)[0]) AS heap_pages
FROM vehicles WHERE plate >= '47P-600' AND plate < '47P-700';

\echo '--- Cùng số dòng, nhưng tìm theo id (9 page liền nhau)'
SELECT count(*) AS rows, count(DISTINCT (ctid::text::point)[0]) AS heap_pages
FROM vehicles WHERE id BETWEEN 100000 AND 100213;

\echo '--- Bắt PostgreSQL đọc kiểu Index Scan cho khoảng biển số'
SET enable_bitmapscan = off;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate >= '47P-600' AND plate < '47P-700';
RESET enable_bitmapscan;

\echo '--- Lai Châu, tỉnh ít xe nhất: Bitmap Index Scan gom địa chỉ, Bitmap Heap Scan đọc 23.402 page'
CREATE INDEX vehicles_province_idx ON vehicles (province);
ANALYZE vehicles;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE province = 'Lai Châu';
