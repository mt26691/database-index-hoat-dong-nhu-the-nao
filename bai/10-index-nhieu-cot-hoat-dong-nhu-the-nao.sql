-- Bài 10. Index nhiều cột (composite index) hoạt động như thế nào?
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/index-nhieu-cot-hoat-dong-nhu-the-nao
\pset pager off

-- Bỏ mọi index mà các bài khác đã tạo, chỉ giữ index của khoá chính.
DO $$ DECLARE i text; BEGIN
  FOR i IN SELECT indexrelid::regclass::text FROM pg_index
           WHERE indrelid = 'vehicles'::regclass AND NOT indisprimary
  LOOP EXECUTE 'DROP INDEX ' || i; END LOOP;
END $$;

\echo '--- Chưa có index phù hợp: đọc cả bảng để đếm'
SET max_parallel_workers_per_gather = 0;
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM vehicles WHERE province = 'Đà Nẵng' AND listed_at >= '2025-01-01';
RESET max_parallel_workers_per_gather;

\echo '--- Index (province, listed_at DESC): tỉnh trước, ngày sau'
CREATE INDEX vehicles_prov_listed_idx ON vehicles (province, listed_at DESC);
ANALYZE vehicles;
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM vehicles WHERE province = 'Đà Nẵng' AND listed_at >= '2025-01-01';

\echo '--- Đổi thứ tự cột: (listed_at DESC, province), đếm lại'
DROP INDEX vehicles_prov_listed_idx;
CREATE INDEX vehicles_listed_prov_idx ON vehicles (listed_at DESC, province);
ANALYZE vehicles;
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM vehicles WHERE province = 'Đà Nẵng' AND listed_at >= '2025-01-01';

\echo '--- Hai index to gần bằng nhau'
CREATE INDEX vehicles_prov_listed_idx ON vehicles (province, listed_at DESC);
SELECT indexrelid::regclass AS index, pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_index WHERE indrelid = 'vehicles'::regclass AND NOT indisprimary;
