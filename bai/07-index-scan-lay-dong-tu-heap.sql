-- Bài 7. Index Scan lấy dòng từ heap như thế nào?
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/index-scan-lay-dong-tu-heap
\pset pager off

-- Bỏ mọi index mà các bài khác đã tạo, chỉ giữ index của khoá chính.
DO $$ DECLARE i text; BEGIN
  FOR i IN SELECT indexrelid::regclass::text FROM pg_index
           WHERE indrelid = 'vehicles'::regclass AND NOT indisprimary
  LOOP EXECUTE 'DROP INDEX ' || i; END LOOP;
END $$;
CREATE INDEX vehicles_plate_idx ON vehicles (plate);

\echo '--- Địa chỉ dòng của xe 47P-600.55: page 474, con trỏ 21'
SELECT ctid, id, plate, brand, price_vnd, province FROM vehicles WHERE plate = '47P-600.55';

\echo '--- Một dòng: 3 page index + 1 page của bảng = 4 page'
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate = '47P-600.55';
