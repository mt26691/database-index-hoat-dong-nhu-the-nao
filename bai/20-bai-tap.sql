-- Bài 20. Bài tập: tự lần theo một câu SQL
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/bai-tap
-- Nên gõ từng bài tập trong psql và tự trả lời câu hỏi trước khi xem đáp án.
-- File này chạy cả sáu bài tập liền một lượt, để đối chiếu số.
\pset pager off

-- Bỏ mọi index mà các bài khác đã tạo, chỉ giữ index của khoá chính.
DO $$ DECLARE i text; BEGIN
  FOR i IN SELECT indexrelid::regclass::text FROM pg_index
           WHERE indrelid = 'vehicles'::regclass AND NOT indisprimary
  LOOP EXECUTE 'DROP INDEX ' || i; END LOOP;
END $$;

\echo '--- Bài tập 1. Quét cả bảng đọc bao nhiêu page?'
SET max_parallel_workers_per_gather = 0;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM vehicles WHERE plate = '25F-950.00';
RESET max_parallel_workers_per_gather;

\echo '--- Bài tập 2. Sửa một dòng thì địa chỉ đổi thế nào?'
SELECT ctid FROM vehicles WHERE id = 5000;
BEGIN;
SELECT ctid FROM vehicles WHERE id = 3;
UPDATE vehicles SET mileage_km = mileage_km + 1 WHERE id = 3;
SELECT ctid FROM vehicles WHERE id = 3;
ROLLBACK;

\echo '--- Bài tập 3. Index Scan đọc những page nào?'
CREATE INDEX vehicles_plate_idx ON vehicles (plate);
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM vehicles WHERE plate = '47P-600.55';
CREATE EXTENSION IF NOT EXISTS pageinspect;
SELECT root, level FROM bt_metap('vehicles_plate_idx');

\echo '--- Bài tập 4. Index Only Scan có phải lúc nào cũng bỏ qua bảng?'
CREATE INDEX vehicles_plate_price_idx ON vehicles (plate) INCLUDE (price_vnd);
VACUUM vehicles;
EXPLAIN (ANALYZE, BUFFERS)
SELECT price_vnd FROM vehicles WHERE plate = '47P-600.55';
BEGIN;
UPDATE vehicles SET mileage_km = mileage_km + 1 WHERE id = 12325;
EXPLAIN (ANALYZE, BUFFERS)
SELECT price_vnd FROM vehicles WHERE plate = '47P-600.55';
ROLLBACK;
VACUUM vehicles;

\echo '--- Bài tập 5. Đổi thứ tự hai cột thì đọc bao nhiêu?'
CREATE INDEX vehicles_prov_listed_idx ON vehicles (province, listed_at DESC);
VACUUM vehicles;
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM vehicles
WHERE province = 'Đà Nẵng' AND listed_at >= '2025-01-01';
DROP INDEX vehicles_prov_listed_idx;
CREATE INDEX vehicles_listed_prov_idx ON vehicles (listed_at DESC, province);
VACUUM vehicles;
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM vehicles
WHERE province = 'Đà Nẵng' AND listed_at >= '2025-01-01';

\echo '--- Bài tập 6. Tự làm lại vòng tối ưu'
DROP INDEX IF EXISTS vehicles_plate_price_idx, vehicles_listed_prov_idx;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, plate, price_vnd, listed_at FROM vehicles
WHERE province = 'Đà Nẵng' AND sold_at IS NULL
ORDER BY listed_at DESC LIMIT 20;
CREATE INDEX CONCURRENTLY vehicles_unsold_idx
ON vehicles (province, listed_at DESC)
WHERE sold_at IS NULL;
ANALYZE vehicles;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, plate, price_vnd, listed_at FROM vehicles
WHERE province = 'Đà Nẵng' AND sold_at IS NULL
ORDER BY listed_at DESC LIMIT 20;
BEGIN;
EXPLAIN (ANALYZE, BUFFERS, WAL, COSTS OFF)
UPDATE vehicles SET sold_at = now()
WHERE id = (SELECT id FROM vehicles
            WHERE province = 'Đà Nẵng' AND sold_at IS NULL
            ORDER BY listed_at DESC LIMIT 1);
ROLLBACK;
