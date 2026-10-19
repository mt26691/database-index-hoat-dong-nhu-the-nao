-- Bài 1. Index là gì và vì sao cần nó?
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao
\pset pager off

-- Bỏ mọi index mà các bài khác đã tạo, chỉ giữ index của khoá chính.
DO $$ DECLARE i text; BEGIN
  FOR i IN SELECT indexrelid::regclass::text FROM pg_index
           WHERE indrelid = 'vehicles'::regclass AND NOT indisprimary
  LOOP EXECUTE 'DROP INDEX ' || i; END LOOP;
END $$;

\timing on

\echo '--- Bảng 10.000 xe, chưa có index trên plate'
SELECT id, plate, brand, model FROM vehicles_10k WHERE plate = '25F-950.00';

\echo '--- Bảng 5 triệu xe, cùng câu SQL'
SELECT id, plate, brand, model FROM vehicles WHERE plate = '25F-950.00';

\echo '--- Tạo index trên plate (mất vài giây)'
CREATE INDEX vehicles_plate_idx ON vehicles (plate);

\echo '--- Bảng 5 triệu xe, có index'
SELECT id, plate, brand, model FROM vehicles WHERE plate = '25F-950.00';

-- Chạy file này lần thứ hai, số mili giây sẽ ổn định hơn: lần đầu dữ liệu chưa nằm trong bộ nhớ.
