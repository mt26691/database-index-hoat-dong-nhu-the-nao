-- Bài 19. Tối ưu một truy vấn chậm bằng EXPLAIN ANALYZE
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/toi-uu-truy-van-cham-postgresql
\pset pager off

-- Bỏ mọi index mà các bài khác đã tạo, chỉ giữ index của khoá chính.
DO $$ DECLARE i text; BEGIN
  FOR i IN SELECT indexrelid::regclass::text FROM pg_index
           WHERE indrelid = 'vehicles'::regclass AND NOT indisprimary
  LOOP EXECUTE 'DROP INDEX ' || i; END LOOP;
END $$;
CREATE INDEX vehicles_plate_idx ON vehicles (plate);
VACUUM (ANALYZE) vehicles;

\echo '--- Bước 1: đo trước khi sửa'
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, plate, price_vnd, listed_at FROM vehicles
WHERE province = 'Đà Nẵng' AND sold_at IS NULL
ORDER BY listed_at DESC LIMIT 20;

\echo '--- Bước 1: PostgreSQL đoán khoảng 46 nghìn xe khớp. Thực tế là bao nhiêu?'
SELECT count(*) AS xe_dang_ban_o_da_nang FROM vehicles WHERE province = 'Đà Nẵng' AND sold_at IS NULL;

\echo '--- Bước 3: tạo index mà không chặn ghi'
CREATE INDEX CONCURRENTLY vehicles_unsold_idx
ON vehicles (province, listed_at DESC) WHERE sold_at IS NULL;
ANALYZE vehicles;

\echo '--- Bước 4: đo lại đúng câu đó'
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, plate, price_vnd, listed_at FROM vehicles
WHERE province = 'Đà Nẵng' AND sold_at IS NULL
ORDER BY listed_at DESC LIMIT 20;

\echo '--- Bước 5: cái giá. Index chiếm bao nhiêu chỗ, và bán một xe thì phải ghi thêm gì'
SELECT pg_size_pretty(pg_relation_size('vehicles_unsold_idx')) AS index_size;
BEGIN;
EXPLAIN (ANALYZE, BUFFERS, WAL, COSTS OFF)
UPDATE vehicles SET sold_at = now()
WHERE id = (SELECT id FROM vehicles
            WHERE province = 'Đà Nẵng' AND sold_at IS NULL
            ORDER BY listed_at DESC LIMIT 1);
ROLLBACK;

\echo '--- Bước 5: mỗi index đã được dùng để tìm kiếm bao nhiêu lần?'
SELECT indexrelname, idx_scan
FROM pg_stat_user_indexes
WHERE relname = 'vehicles';
