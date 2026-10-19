-- Chương 13: tối ưu Q3 từ đầu tới cuối: đo trước, đặt giả thuyết, tạo index, đo lại.
-- Trạng thái ban đầu: chỉ có khoá chính và index trên plate.
DROP INDEX IF EXISTS vehicles_unsold_idx, vehicles_plate_norm_idx, vehicles_prov_listed_idx,
  vehicles_province_idx, vehicles_price_idx, vehicles_plate_price_idx;
VACUUM (ANALYZE) vehicles;
SELECT indexrelid::regclass AS index, pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_index WHERE indrelid = 'vehicles'::regclass;

-- 1. Đo trước.
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, plate, price_vnd, listed_at FROM vehicles
WHERE province = 'Đà Nẵng' AND sold_at IS NULL
ORDER BY listed_at DESC LIMIT 20;

-- Ước lượng của planner so với thực tế.
SELECT count(*) AS actual_unsold_danang FROM vehicles WHERE province = 'Đà Nẵng' AND sold_at IS NULL;

-- 2. Giả thuyết: câu chỉ cần xe chưa bán của một tỉnh, mới nhất trước.
--    Index: (province, listed_at DESC) chỉ cho dòng sold_at IS NULL.
-- 3. Tạo index không khoá ghi (ngoài production luôn dùng CONCURRENTLY).
\timing on
CREATE INDEX CONCURRENTLY vehicles_unsold_idx ON vehicles (province, listed_at DESC) WHERE sold_at IS NULL;
\timing off
ANALYZE vehicles;
SELECT pg_size_pretty(pg_relation_size('vehicles_unsold_idx')) AS new_index_size;

-- 4. Đo lại đúng câu đó.
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, plate, price_vnd, listed_at FROM vehicles
WHERE province = 'Đà Nẵng' AND sold_at IS NULL
ORDER BY listed_at DESC LIMIT 20;

-- 5. Giá phải trả: khi một xe được bán, dòng đó phải rời khỏi index (UPDATE không thể là HOT).
BEGIN;
EXPLAIN (ANALYZE, BUFFERS, WAL, COSTS OFF)
UPDATE vehicles SET sold_at = now()
WHERE id = (SELECT id FROM vehicles WHERE province = 'Đà Nẵng' AND sold_at IS NULL ORDER BY listed_at DESC LIMIT 1);
ROLLBACK;

-- 6. Câu khác có đổi kế hoạch không? Câu không lọc sold_at vẫn như cũ.
EXPLAIN SELECT id FROM vehicles WHERE province = 'Đà Nẵng' ORDER BY listed_at DESC LIMIT 20;
