-- Bài 13. Vì sao LIKE vẫn quét cả bảng dù có index?
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/vi-sao-like-khong-dung-index
\pset pager off
-- Một tiến trình cho kế hoạch dễ đọc; số page vẫn như khi chạy song song.
SET max_parallel_workers_per_gather = 0;

-- Bỏ mọi index mà các bài khác đã tạo, chỉ giữ index của khoá chính.
DO $$ DECLARE i text; BEGIN
  FOR i IN SELECT indexrelid::regclass::text FROM pg_index
           WHERE indrelid = 'vehicles'::regclass AND NOT indisprimary
  LOOP EXECUTE 'DROP INDEX ' || i; END LOOP;
END $$;
CREATE INDEX vehicles_plate_idx ON vehicles (plate);
ANALYZE vehicles;

\echo '--- Viết thành một khoảng: dùng được index, 5 page'
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate >= '47P-600' AND plate < '47P-601';

\echo '--- Cùng ý bằng LIKE theo phần đầu: với collation en_US.utf8, quét cả bảng'
SELECT datcollate FROM pg_database WHERE datname = current_database();
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate LIKE '47P-600%';

\echo '--- Vì sao: en_US.utf8 bỏ qua dấu - khi sắp xếp, còn "C" so từng byte'
SELECT x FROM unnest(ARRAY['47P-600.55','47P600.00','47P-601.04','47P-599.99']) x ORDER BY x;
SELECT x FROM unnest(ARRAY['47P-600.55','47P600.00','47P-601.04','47P-599.99']) x ORDER BY x COLLATE "C";

\echo '--- Bảng vehicles không có biển số nào thiếu dấu gạch'
SELECT count(*) AS khong_co_gach FROM vehicles WHERE plate NOT LIKE '%-%';

\echo '--- Index với lớp toán tử text_pattern_ops: LIKE theo phần đầu dùng được, 5 page'
CREATE INDEX vehicles_plate_pattern_idx ON vehicles (plate text_pattern_ops);
ANALYZE vehicles;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate LIKE '47P-600%';
DROP INDEX vehicles_plate_pattern_idx;

\echo '--- Tìm ở giữa chuỗi: B-tree không giúp được'
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate LIKE '%600.5%';

\echo '--- pg_trgm cắt chuỗi thành các mẩu ba ký tự'
CREATE EXTENSION IF NOT EXISTS pg_trgm;
SELECT show_trgm('600.5');

\echo '--- Index GIN trên các mẩu ba ký tự, mất vài giây để tạo'
CREATE INDEX vehicles_plate_trgm_idx ON vehicles USING gin (plate gin_trgm_ops);
ANALYZE vehicles;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate LIKE '%600.5%';
SELECT pg_size_pretty(pg_relation_size('vehicles_plate_idx'))      AS btree,
       pg_size_pretty(pg_relation_size('vehicles_plate_trgm_idx')) AS gin_trgm;
