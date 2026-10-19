-- Bài 10. Vì sao có index nhưng query không tận dụng được?
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/vi-sao-query-khong-tan-dung-index
\pset pager off

-- Bỏ mọi index mà các bài khác đã tạo, chỉ giữ index của khoá chính.
DO $$ DECLARE i text; BEGIN
  FOR i IN SELECT indexrelid::regclass::text FROM pg_index
           WHERE indrelid = 'vehicles'::regclass AND NOT indisprimary
  LOOP EXECUTE 'DROP INDEX ' || i; END LOOP;
END $$;
CREATE INDEX vehicles_plate_idx ON vehicles (plate);
ANALYZE vehicles;

\echo '--- So sánh thẳng với cột: dùng được index'
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate = '47P-600.55';

\echo '--- Bọc cột trong hàm: index lưu plate, không lưu lower(plate)'
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE lower(plate) = '47p-600.55';

\echo '--- Ép kiểu cột: cũng không khớp index'
EXPLAIN SELECT * FROM vehicles WHERE id::text = '12345';
EXPLAIN SELECT * FROM vehicles WHERE plate::varchar(20) = '47P-600.55';

\echo '--- Tìm đoạn giữa chuỗi: thứ tự chữ cái không giúp gì'
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate LIKE '%600.5%';

\echo '--- Tìm theo đầu chuỗi: với collation en_US.utf8, LIKE không dùng được index thường'
SELECT datcollate FROM pg_database WHERE datname = current_database();
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate LIKE '47P-600%';

\echo '--- Viết thành một khoảng thì dùng được'
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate >= '47P-600' AND plate < '47P-601';

\echo '--- Vì sao: en_US.utf8 bỏ qua dấu - khi sắp xếp, còn "C" so từng byte'
SELECT x FROM unnest(ARRAY['47P-600.55','47P600.00','47P-601.04','47P-599.99']) x ORDER BY x;
SELECT x FROM unnest(ARRAY['47P-600.55','47P600.00','47P-601.04','47P-599.99']) x ORDER BY x COLLATE "C";

\echo '--- Tìm giữa chuỗi bằng index trigram (GIN), mất khoảng nửa phút để tạo'
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX vehicles_plate_trgm_idx ON vehicles USING gin (plate gin_trgm_ops);
ANALYZE vehicles;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate LIKE '%600.5%';
SELECT pg_size_pretty(pg_relation_size('vehicles_plate_idx'))      AS btree,
       pg_size_pretty(pg_relation_size('vehicles_plate_trgm_idx')) AS gin_trgm;
