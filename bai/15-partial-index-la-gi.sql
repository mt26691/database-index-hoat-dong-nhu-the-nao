-- Bài 15. Partial index là gì và khi nào nên dùng?
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/partial-index-la-gi
\pset pager off
-- Một tiến trình cho kế hoạch dễ đọc; số page vẫn như khi chạy song song.
SET max_parallel_workers_per_gather = 0;

-- Bỏ mọi index mà các bài khác đã tạo, chỉ giữ index của khoá chính.
DO $$ DECLARE i text; BEGIN
  FOR i IN SELECT indexrelid::regclass::text FROM pg_index
           WHERE indrelid = 'vehicles'::regclass AND NOT indisprimary
  LOOP EXECUTE 'DROP INDEX ' || i; END LOOP;
END $$;

\echo '--- Bao nhiêu xe còn đang bán?'
SELECT count(*) FILTER (WHERE sold_at IS NULL) AS dang_ban, count(*) AS tong FROM vehicles;

\echo '--- Index cho cả bảng và index chỉ cho xe chưa bán'
CREATE INDEX vehicles_prov_listed_idx ON vehicles (province, listed_at DESC);
CREATE INDEX vehicles_unsold_idx ON vehicles (province, listed_at DESC) WHERE sold_at IS NULL;
ANALYZE vehicles;
SELECT relname, pg_size_pretty(pg_relation_size(oid)) AS size
FROM pg_class WHERE relname IN ('vehicles_prov_listed_idx', 'vehicles_unsold_idx');
SHOW shared_buffers;

\echo '--- Câu có sold_at IS NULL: dùng được partial index, không cần Sort'
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, plate, price_vnd, listed_at FROM vehicles
WHERE province = 'Đà Nẵng' AND sold_at IS NULL
ORDER BY listed_at DESC LIMIT 20;

\echo '--- Chỉ còn partial index, câu không nhắc tới sold_at: quét cả bảng rồi sắp xếp'
DROP INDEX vehicles_prov_listed_idx;
EXPLAIN SELECT id FROM vehicles WHERE province = 'Đà Nẵng' ORDER BY listed_at DESC LIMIT 20;
