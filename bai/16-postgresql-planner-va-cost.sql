-- Bài 16. PostgreSQL chọn cách chạy câu SQL như thế nào?
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/postgresql-planner-va-cost
\pset pager off

-- Bỏ mọi index mà các bài khác đã tạo, chỉ giữ index của khoá chính.
DO $$ DECLARE i text; BEGIN
  FOR i IN SELECT indexrelid::regclass::text FROM pg_index
           WHERE indrelid = 'vehicles'::regclass AND NOT indisprimary
  LOOP EXECUTE 'DROP INDEX ' || i; END LOOP;
END $$;
CREATE INDEX vehicles_province_idx ON vehicles (province);
ANALYZE vehicles;

\echo '--- Kế hoạch planner chọn cho Lai Châu, kèm cost ước tính (EXPLAIN không chạy câu SQL)'
EXPLAIN SELECT * FROM vehicles WHERE province = 'Lai Châu';

\echo '--- Cost của cách bị loại: tạm cấm hai cách đi qua index (chỉ để so, đừng làm vậy trên production)'
SET enable_bitmapscan = off;
SET enable_indexscan = off;
EXPLAIN SELECT * FROM vehicles WHERE province = 'Lai Châu';
RESET enable_bitmapscan;
RESET enable_indexscan;

\echo '--- Đổi sang TP.HCM: cùng index, kế hoạch đổi thành Seq Scan'
EXPLAIN SELECT * FROM vehicles WHERE province = 'TP.HCM';
