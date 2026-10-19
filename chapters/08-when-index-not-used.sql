-- Chương 8: có index trên plate nhưng điều kiện WHERE không khớp với cách index sắp xếp.
-- Chỉ giữ index thường trên plate để thấy rõ.
DROP INDEX IF EXISTS vehicles_plate_price_idx, vehicles_plate_trgm_idx, vehicles_plate_lower_idx, vehicles_prov_listed_idx;
SELECT plate AS p, lower(plate) AS lp FROM vehicles WHERE id = 12345 \gset
SELECT datcollate, datlocprovider FROM pg_database WHERE datname = current_database();

-- 1. So sánh bằng trực tiếp với cột: khớp index.
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate = :'p';

-- 2. Bọc cột trong một hàm: index lưu plate, không lưu lower(plate).
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE lower(plate) = :'lp';

-- 3. Tìm đoạn ở giữa chuỗi: thứ tự chữ cái không giúp gì.
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate LIKE '%600.5%';

-- 4. Tìm theo đầu chuỗi: với collation en_US.utf8, LIKE 'abc%' không dùng được index thường.
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate LIKE '47P-600%';
-- Viết thành khoảng thì dùng được.
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate >= '47P-600' AND plate < '47P-601';

-- 5. Kiểu dữ liệu lệch: so sánh text với một giá trị ép kiểu khác.
EXPLAIN SELECT * FROM vehicles WHERE plate::varchar(20) = :'p';
EXPLAIN SELECT * FROM vehicles WHERE id::text = '12345';

-- Hướng khác cho tìm giữa chuỗi: trigram (pg_trgm) với index GIN.
CREATE EXTENSION IF NOT EXISTS pg_trgm;
\timing on
CREATE INDEX vehicles_plate_trgm_idx ON vehicles USING gin (plate gin_trgm_ops);
\timing off
ANALYZE vehicles;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate LIKE '%600.5%';
SELECT pg_size_pretty(pg_relation_size('vehicles_plate_idx')) AS btree,
       pg_size_pretty(pg_relation_size('vehicles_plate_trgm_idx')) AS gin_trgm;
DROP INDEX vehicles_plate_trgm_idx;
