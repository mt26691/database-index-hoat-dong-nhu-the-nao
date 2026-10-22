-- Bài 3. Index giúp truy vấn nhanh hơn bằng cách nào?
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/index-hoat-dong-nhu-the-nao
\pset pager off

-- Bỏ mọi index mà các bài khác đã tạo, chỉ giữ index của khoá chính.
DO $$ DECLARE i text; BEGIN
  FOR i IN SELECT indexrelid::regclass::text FROM pg_index
           WHERE indrelid = 'vehicles'::regclass AND NOT indisprimary
  LOOP EXECUTE 'DROP INDEX ' || i; END LOOP;
END $$;

\echo '--- Tìm theo id: cột id là khoá chính, đã có sẵn index vehicles_pkey'
-- Chạy thường một lần trước, để lần đo không tính các page PostgreSQL đọc khi mới mở index.
SELECT id, plate FROM vehicles WHERE id = 5000;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM vehicles WHERE id = 5000;

\echo '--- Tạo index trên plate rồi chạy lại câu của bài trước'
CREATE INDEX vehicles_plate_idx ON vehicles (plate);
SELECT id, plate FROM vehicles WHERE plate = '25F-950.00';
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM vehicles WHERE plate = '25F-950.00';

\echo '--- Index trên plate có 3 tầng: level của page gốc là 2'
CREATE EXTENSION IF NOT EXISTS pageinspect;
SELECT level + 1 AS so_tang FROM bt_metap('vehicles_plate_idx');
