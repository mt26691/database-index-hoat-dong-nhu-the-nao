-- Bài 6. PostgreSQL sử dụng B-tree làm index như thế nào?
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/postgresql-su-dung-b-tree-lam-index-nhu-the-nao
\pset pager off

-- Bỏ mọi index mà các bài khác đã tạo, chỉ giữ index của khoá chính.
DO $$ DECLARE i text; BEGIN
  FOR i IN SELECT indexrelid::regclass::text FROM pg_index
           WHERE indrelid = 'vehicles'::regclass AND NOT indisprimary
  LOOP EXECUTE 'DROP INDEX ' || i; END LOOP;
END $$;

\echo '--- Index trên plate (bài 3 đã tạo; file này tạo lại để chạy riêng được, mất vài giây)'
\timing on
CREATE INDEX vehicles_plate_idx ON vehicles (plate);
\timing off
CREATE EXTENSION IF NOT EXISTS pageinspect;

\echo '--- Page 0 của index (metapage) ghi page gốc nằm ở đâu và cây có mấy tầng'
SELECT root, level FROM bt_metap('vehicles_plate_idx');

\echo '--- Số page và số mục trung bình theo tầng: r = gốc, i = page trong, l = lá'
SELECT type, count(*) AS pages, round(avg(live_items)) AS items
FROM bt_multi_page_stats('vehicles_plate_idx', 1, -1)
GROUP BY type ORDER BY type DESC;

\echo '--- Bốn mục đầu của page gốc: ctid của mỗi mục chứa số page con'
SELECT root AS root_page FROM bt_metap('vehicles_plate_idx') \gset
SELECT itemoffset, ctid, data
FROM bt_page_items('vehicles_plate_idx', :root_page) LIMIT 4;

\echo '--- Biển 47P-600.55 (xe id 12345) nằm ở địa chỉ dòng nào?'
SELECT id, plate, ctid FROM vehicles WHERE plate = '47P-600.55';

\echo '--- Tìm một biển số: 3 page index (gốc, trong, lá) và 1 page của bảng'
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM vehicles WHERE plate = '47P-600.55';

\echo '--- Tìm một khoảng biển số: xuống lá một lần rồi đọc sang lá bên cạnh'
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM vehicles WHERE plate >= '47P-600' AND plate < '47P-700';
