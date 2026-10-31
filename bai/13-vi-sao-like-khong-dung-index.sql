-- Bài 13. Vì sao LIKE không dùng index?
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

\echo '--- Vì sao: thứ tự theo ngôn ngữ (en_US.utf8) đặt aB2 xen giữa ab1 và ab3; so từng ký tự ("C") thì không'
SELECT x, x LIKE 'ab%' AS khop FROM unnest(ARRAY['ab1','aB2','ab3']) x ORDER BY x;
SELECT x, x LIKE 'ab%' AS khop FROM unnest(ARRAY['ab1','aB2','ab3']) x ORDER BY x COLLATE "C";

\echo '--- Index với lớp toán tử text_pattern_ops: LIKE theo phần đầu dùng được, 5 page'
CREATE INDEX vehicles_plate_pattern_idx ON vehicles (plate text_pattern_ops);
ANALYZE vehicles;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate LIKE '47P-600%';
DROP INDEX vehicles_plate_pattern_idx;

\echo '--- Tìm ở giữa chuỗi: không có phần đầu, B-tree không giúp được'
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate LIKE '%600.5%';

