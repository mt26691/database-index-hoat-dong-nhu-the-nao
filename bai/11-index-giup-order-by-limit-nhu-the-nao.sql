-- Bài 11. Index giúp ORDER BY và LIMIT nhanh hơn thế nào?
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/index-giup-order-by-limit-nhu-the-nao
\pset pager off

-- Bỏ mọi index mà các bài khác đã tạo, chỉ giữ index của khoá chính.
DO $$ DECLARE i text; BEGIN
  FOR i IN SELECT indexrelid::regclass::text FROM pg_index
           WHERE indrelid = 'vehicles'::regclass AND NOT indisprimary
  LOOP EXECUTE 'DROP INDEX ' || i; END LOOP;
END $$;

\echo '--- Chưa có index phù hợp: lọc cả bảng rồi Sort'
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, listed_at FROM vehicles
WHERE province = 'Đà Nẵng' AND listed_at >= '2025-01-01'
ORDER BY listed_at DESC LIMIT 20;

\echo '--- Index (province, listed_at DESC): đọc 20 mục đầu đoạn rồi dừng, không có Sort'
CREATE INDEX vehicles_prov_listed_idx ON vehicles (province, listed_at DESC);
ANALYZE vehicles;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, listed_at FROM vehicles
WHERE province = 'Đà Nẵng' AND listed_at >= '2025-01-01'
ORDER BY listed_at DESC LIMIT 20;

\echo '--- PostgreSQL 18 skip scan: không lọc tỉnh vẫn dùng được index, xem dòng Index Searches'
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM vehicles WHERE listed_at >= '2026-09-29';

\echo '--- Có bao nhiêu tỉnh?'
SELECT count(DISTINCT province) AS provinces FROM vehicles;
