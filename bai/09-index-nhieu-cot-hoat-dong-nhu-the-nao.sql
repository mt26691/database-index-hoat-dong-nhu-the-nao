-- Bài 9. Index nhiều cột (composite index) hoạt động như thế nào?
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/index-nhieu-cot-hoat-dong-nhu-the-nao
\pset pager off

-- Bỏ mọi index mà các bài khác đã tạo, chỉ giữ index của khoá chính.
DO $$ DECLARE i text; BEGIN
  FOR i IN SELECT indexrelid::regclass::text FROM pg_index
           WHERE indrelid = 'vehicles'::regclass AND NOT indisprimary
  LOOP EXECUTE 'DROP INDEX ' || i; END LOOP;
END $$;

\echo '--- Chưa có index phù hợp'
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, listed_at FROM vehicles
WHERE province = 'Đà Nẵng' AND listed_at >= '2025-01-01'
ORDER BY listed_at DESC LIMIT 20;

\echo '--- Index (province, listed_at): tỉnh trước, ngày sau'
CREATE INDEX vehicles_prov_listed_idx ON vehicles (province, listed_at DESC);
ANALYZE vehicles;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, listed_at FROM vehicles
WHERE province = 'Đà Nẵng' AND listed_at >= '2025-01-01'
ORDER BY listed_at DESC LIMIT 20;

\echo '--- Đếm hết các xe khớp với thứ tự cột này'
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM vehicles WHERE province = 'Đà Nẵng' AND listed_at >= '2025-01-01';

\echo '--- PostgreSQL 18 skip scan: không lọc tỉnh vẫn dùng được index, xem dòng Index Searches'
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM vehicles WHERE listed_at >= '2026-09-29';

\echo '--- Đổi thứ tự cột: (listed_at, province), đếm lại'
DROP INDEX vehicles_prov_listed_idx;
CREATE INDEX vehicles_listed_prov_idx ON vehicles (listed_at DESC, province);
ANALYZE vehicles;
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM vehicles WHERE province = 'Đà Nẵng' AND listed_at >= '2025-01-01';
