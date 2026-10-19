-- Chương 6: Index Only Scan và visibility map.
CREATE EXTENSION IF NOT EXISTS pg_visibility;
CREATE EXTENSION IF NOT EXISTS pageinspect;
SELECT plate AS p FROM vehicles WHERE id = 12345 \gset

-- Index thường trên plate: SELECT price_vnd vẫn phải vào heap lấy giá.
EXPLAIN (ANALYZE, BUFFERS) SELECT price_vnd FROM vehicles WHERE plate = :'p';

-- Index có INCLUDE: giá nằm sẵn trong leaf.
DROP INDEX IF EXISTS vehicles_plate_price_idx;
CREATE INDEX vehicles_plate_price_idx ON vehicles (plate) INCLUDE (price_vnd);
VACUUM (ANALYZE) vehicles;
SELECT pg_size_pretty(pg_relation_size('vehicles_plate_idx')) AS plate_only,
       pg_size_pretty(pg_relation_size('vehicles_plate_price_idx')) AS plate_include_price;

-- Trang heap 474 (chứa xe id 12345) đang được đánh dấu all-visible.
SELECT blkno, all_visible FROM pg_visibility_map('vehicles') WHERE blkno = 474;
EXPLAIN (ANALYZE, BUFFERS) SELECT price_vnd FROM vehicles WHERE plate = :'p';

-- SELECT * thì không đủ: các cột khác không có trong index.
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate = :'p';

-- Sửa một dòng khác nằm cùng page 474: page mất bit all-visible.
SELECT id AS other_id FROM vehicles WHERE (ctid::text::point)[0] = 474 AND id <> 12345 LIMIT 1 \gset
UPDATE vehicles SET mileage_km = mileage_km + 1 WHERE id = :other_id;
SELECT blkno, all_visible FROM pg_visibility_map('vehicles') WHERE blkno = 474;
EXPLAIN (ANALYZE, BUFFERS) SELECT price_vnd FROM vehicles WHERE plate = :'p';

-- VACUUM thường: khi quá ít dòng chết, PostgreSQL bỏ qua bước dọn index để tiết kiệm.
-- Con trỏ dòng chết (lp_flags = 3) vẫn nằm lại, nên page chưa được đánh dấu all-visible.
VACUUM vehicles;
SELECT blkno, all_visible FROM pg_visibility_map('vehicles') WHERE blkno = 474;
SELECT lp, lp_flags FROM heap_page_items(get_raw_page('vehicles', 474)) WHERE lp_flags <> 1;
EXPLAIN (ANALYZE, BUFFERS) SELECT price_vnd FROM vehicles WHERE plate = :'p';

-- Bắt dọn cả index: con trỏ chết được gỡ, page được đánh dấu all-visible trở lại.
VACUUM (INDEX_CLEANUP ON) vehicles;
SELECT blkno, all_visible FROM pg_visibility_map('vehicles') WHERE blkno = 474;
EXPLAIN (ANALYZE, BUFFERS) SELECT price_vnd FROM vehicles WHERE plate = :'p';

-- Kích thước visibility map so với bảng.
SELECT pg_size_pretty(pg_relation_size('vehicles', 'vm')) AS vm_size,
       pg_size_pretty(pg_relation_size('vehicles')) AS heap_size;
