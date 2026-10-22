-- Bài 12. Vì sao có index nhưng query không tận dụng được?
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/vi-sao-query-khong-tan-dung-index
\pset pager off
-- Một tiến trình cho kế hoạch dễ đọc; số page vẫn như khi chạy song song.
SET max_parallel_workers_per_gather = 0;

-- Bỏ mọi index mà các bài khác đã tạo, chỉ giữ index của khoá chính.
DO $$ DECLARE i text; BEGIN
  FOR i IN SELECT indexrelid::regclass::text FROM pg_index
           WHERE indrelid = 'vehicles'::regclass AND NOT indisprimary
  LOOP EXECUTE 'DROP INDEX ' || i; END LOOP;
END $$;
CREATE INDEX vehicles_plate_idx ON vehicles (plate);
ANALYZE vehicles;

\echo '--- So sánh thẳng với cột: dùng được index, 4 page'
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate = '47P-600.55';

\echo '--- Bọc cột trong hàm: index lưu plate, không lưu lower(plate)'
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE lower(plate) = '47p-600.55';

\echo '--- Ép kiểu cột: cũng không khớp index'
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE id::text = '12345';
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate::varchar(20) = '47P-600.55';

\echo '--- plate::varchar không đổi gì trong dữ liệu, nên vẫn dùng được index'
EXPLAIN SELECT * FROM vehicles WHERE plate::varchar = '47P-600.55';

\echo '--- Để nguyên cột, đưa giá trị về đúng kiểu của cột'
EXPLAIN SELECT * FROM vehicles WHERE id = 12345;

\echo '--- Index trên biểu thức lower(plate)'
CREATE INDEX vehicles_plate_lower_idx ON vehicles (lower(plate));
ANALYZE vehicles;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE lower(plate) = '47p-600.55';
SELECT relname, pg_size_pretty(pg_relation_size(oid)) AS size
FROM pg_class WHERE relname IN ('vehicles_plate_idx', 'vehicles_plate_lower_idx');

\echo '--- Biển số không dấu, ví dụ 47P60055: chưa có index biểu thức'
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM vehicles WHERE replace(replace(plate, '-', ''), '.', '') = '47P60055';

\echo '--- Có index trên đúng biểu thức đó'
CREATE INDEX vehicles_plate_norm_idx ON vehicles ((replace(replace(plate, '-', ''), '.', '')));
ANALYZE vehicles;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM vehicles WHERE replace(replace(plate, '-', ''), '.', '') = '47P60055';

\echo '--- Đổi thứ tự hai lần replace là biểu thức khác, index không dùng được nữa'
EXPLAIN SELECT * FROM vehicles WHERE replace(replace(plate, '.', ''), '-', '') = '47P60055';
