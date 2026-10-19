-- Bài 7. Index Scan tìm row trong heap như thế nào?
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/index-scan-tim-row-trong-heap
\pset pager off

-- Bỏ mọi index mà các bài khác đã tạo, chỉ giữ index của khoá chính.
DO $$ DECLARE i text; BEGIN
  FOR i IN SELECT indexrelid::regclass::text FROM pg_index
           WHERE indrelid = 'vehicles'::regclass AND NOT indisprimary
  LOOP EXECUTE 'DROP INDEX ' || i; END LOOP;
END $$;
CREATE INDEX vehicles_plate_idx ON vehicles (plate);

\echo '--- Một dòng: 3 page index + 1 page heap'
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate = '47P-600.55';

\echo '--- Các biển số liền nhau trong index nằm trên bao nhiêu page heap?'
SELECT count(*) AS rows, count(DISTINCT (ctid::text::point)[0]) AS heap_pages
FROM vehicles WHERE plate >= '47P-600' AND plate < '47P-700';

\echo '--- Cùng số dòng, nhưng tìm theo id'
SELECT count(*) AS rows, count(DISTINCT (ctid::text::point)[0]) AS heap_pages
FROM vehicles WHERE id BETWEEN 100000 AND 100213;

\echo '--- Bắt PostgreSQL đọc kiểu Index Scan để xem số page'
SET enable_bitmapscan = off;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate >= '47P-600' AND plate < '47P-700';
RESET enable_bitmapscan;
