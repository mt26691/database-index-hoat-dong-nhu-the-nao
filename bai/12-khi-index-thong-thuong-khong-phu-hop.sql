-- Bài 12. Khi index thông thường không phù hợp thì làm gì?
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/khi-index-thong-thuong-khong-phu-hop
\pset pager off

-- Bỏ mọi index mà các bài khác đã tạo, chỉ giữ index của khoá chính.
DO $$ DECLARE i text; BEGIN
  FOR i IN SELECT indexrelid::regclass::text FROM pg_index
           WHERE indrelid = 'vehicles'::regclass AND NOT indisprimary
  LOOP EXECUTE 'DROP INDEX ' || i; END LOOP;
END $$;

\echo '--- Partial index: chỉ đưa xe còn đang bán vào index'
SELECT count(*) FILTER (WHERE sold_at IS NULL) AS dang_ban, count(*) AS tong FROM vehicles;
CREATE INDEX vehicles_prov_listed_idx ON vehicles (province, listed_at DESC);
CREATE INDEX vehicles_unsold_idx ON vehicles (province, listed_at DESC) WHERE sold_at IS NULL;
ANALYZE vehicles;
SELECT relname, pg_size_pretty(pg_relation_size(oid)) AS size
FROM pg_class WHERE relname IN ('vehicles_prov_listed_idx', 'vehicles_unsold_idx');

\echo '--- Câu có sold_at IS NULL: dùng được partial index'
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, plate, price_vnd, listed_at FROM vehicles
WHERE province = 'Đà Nẵng' AND sold_at IS NULL
ORDER BY listed_at DESC LIMIT 20;

\echo '--- Câu không nhắc tới sold_at: không dùng được partial index'
DROP INDEX vehicles_prov_listed_idx;
EXPLAIN SELECT id FROM vehicles WHERE province = 'Đà Nẵng' ORDER BY listed_at DESC LIMIT 20;

\echo '--- Expression index: người dùng gõ biển số không dấu, ví dụ 47P60055'
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM vehicles WHERE replace(replace(plate, '-', ''), '.', '') = '47P60055';
CREATE INDEX vehicles_plate_norm_idx ON vehicles ((replace(replace(plate, '-', ''), '.', '')));
ANALYZE vehicles;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM vehicles WHERE replace(replace(plate, '-', ''), '.', '') = '47P60055';

\echo '--- Đổi thứ tự hai lần replace là biểu thức khác, index không dùng được nữa'
EXPLAIN SELECT * FROM vehicles WHERE replace(replace(plate, '.', ''), '-', '') = '47P60055';
