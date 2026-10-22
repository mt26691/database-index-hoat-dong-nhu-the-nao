-- Bài 9. Index Only Scan tránh đọc heap bằng cách nào?
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/index-only-scan-tranh-doc-heap
\pset pager off

-- Bỏ mọi index mà các bài khác đã tạo, chỉ giữ index của khoá chính.
DO $$ DECLARE i text; BEGIN
  FOR i IN SELECT indexrelid::regclass::text FROM pg_index
           WHERE indrelid = 'vehicles'::regclass AND NOT indisprimary
  LOOP EXECUTE 'DROP INDEX ' || i; END LOOP;
END $$;
CREATE EXTENSION IF NOT EXISTS pg_visibility;
CREATE INDEX vehicles_plate_idx ON vehicles (plate);
VACUUM (ANALYZE) vehicles;

\echo '--- Index thường: muốn lấy giá vẫn phải vào heap'
EXPLAIN (ANALYZE, BUFFERS) SELECT price_vnd FROM vehicles WHERE plate = '47P-600.55';

\echo '--- Index có INCLUDE (price_vnd): giá nằm sẵn trong page lá'
CREATE INDEX vehicles_plate_price_idx ON vehicles (plate) INCLUDE (price_vnd);
VACUUM (ANALYZE) vehicles;
SELECT pg_size_pretty(pg_relation_size('vehicles_plate_idx'))       AS plate_only,
       pg_size_pretty(pg_relation_size('vehicles_plate_price_idx')) AS plate_include_price;

\echo '--- Bản đồ hiển thị của cả bảng: 48 kB, tức 6 page'
SELECT pg_size_pretty(pg_relation_size('vehicles', 'vm')) AS vm_size,
       pg_relation_size('vehicles', 'vm') / 8192         AS vm_pages;

\echo '--- Xe nằm ở page 474. Page đó đang được đánh dấu all-visible'
SELECT ctid FROM vehicles WHERE plate = '47P-600.55';
SELECT blkno, all_visible FROM pg_visibility_map('vehicles') WHERE blkno = 474;
\echo '--- Heap Fetches: 0. Buffers vẫn 4: 3 page index + 1 page bản đồ hiển thị'
EXPLAIN (ANALYZE, BUFFERS) SELECT price_vnd FROM vehicles WHERE plate = '47P-600.55';

\echo '--- 214 biển số nằm trên 172 page khác nhau của bảng, nhưng chỉ cần 6 page bản đồ'
SELECT count(*) AS rows,
       count(DISTINCT (ctid::text::point)[0]) AS heap_pages,
       count(DISTINCT ((ctid::text::point)[0])::int / 32672) AS vm_pages
FROM vehicles WHERE plate >= '47P-600' AND plate < '47P-700';
EXPLAIN (ANALYZE, BUFFERS) SELECT plate, price_vnd FROM vehicles WHERE plate >= '47P-600' AND plate < '47P-700';

\echo '--- Sửa một xe khác cùng page 474: page mất bit all-visible, Heap Fetches thành 1'
UPDATE vehicles SET mileage_km = mileage_km + 1 WHERE id = 12325;
SELECT blkno, all_visible FROM pg_visibility_map('vehicles') WHERE blkno = 474;
EXPLAIN (ANALYZE, BUFFERS) SELECT price_vnd FROM vehicles WHERE plate = '47P-600.55';

\echo '--- VACUUM thường: bảng có quá ít dòng chết nên bỏ qua bước dọn index, bit vẫn tắt'
VACUUM vehicles;
SELECT blkno, all_visible FROM pg_visibility_map('vehicles') WHERE blkno = 474;

\echo '--- VACUUM dọn cả index, page được đánh dấu all-visible trở lại'
VACUUM (INDEX_CLEANUP ON) vehicles;
SELECT blkno, all_visible FROM pg_visibility_map('vehicles') WHERE blkno = 474;
EXPLAIN (ANALYZE, BUFFERS) SELECT price_vnd FROM vehicles WHERE plate = '47P-600.55';
