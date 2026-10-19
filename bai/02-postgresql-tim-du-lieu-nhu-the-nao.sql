-- Bài 2. PostgreSQL tìm dữ liệu như thế nào?
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/postgresql-tim-du-lieu-nhu-the-nao
\pset pager off

-- Bỏ mọi index mà các bài khác đã tạo, chỉ giữ index của khoá chính.
DO $$ DECLARE i text; BEGIN
  FOR i IN SELECT indexrelid::regclass::text FROM pg_index
           WHERE indrelid = 'vehicles'::regclass AND NOT indisprimary
  LOOP EXECUTE 'DROP INDEX ' || i; END LOOP;
END $$;

\echo '--- Mỗi page 8 KB. Bảng 5 triệu xe có bao nhiêu page?'
SHOW block_size;
SELECT pg_relation_size('vehicles') / 8192 AS pages,
       pg_size_pretty(pg_relation_size('vehicles')) AS size;

\echo '--- Quét tuần tự bằng một tiến trình. Cộng hit và read ở dòng Buffers là ra số page đã đọc'
SET max_parallel_workers_per_gather = 0;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM vehicles WHERE plate = '25F-950.00';

\echo '--- Cùng câu đó trên ba cỡ bảng'
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles_10k  WHERE plate = '25F-950.00';
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles_200k WHERE plate = '25F-950.00';
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles      WHERE plate = '25F-950.00';

\echo '--- Cho phép chạy song song: Gather chia page cho các Parallel Seq Scan'
RESET max_parallel_workers_per_gather;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM vehicles WHERE plate = '25F-950.00';
