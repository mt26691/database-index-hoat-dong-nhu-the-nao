-- Bài 16. Vì sao index làm INSERT chậm hơn?
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/vi-sao-index-lam-ghi-cham-hon
-- Dùng một bảng riêng vehicles_w, bảng vehicles không bị đụng tới.
\pset pager off
CREATE EXTENSION IF NOT EXISTS pgstattuple;
DROP TABLE IF EXISTS vehicles_w;
CREATE TABLE vehicles_w (LIKE vehicles);

-- Mỗi lần đo làm lại bảng trống với đúng n index.
CREATE OR REPLACE PROCEDURE pg_temp.reset_w(n int) LANGUAGE plpgsql AS $$
BEGIN
  TRUNCATE vehicles_w;
  DROP INDEX IF EXISTS w_id, w_plate, w_prov_listed, w_price, w_brand, w_mileage;
  IF n >= 1 THEN CREATE UNIQUE INDEX w_id ON vehicles_w (id); END IF;
  IF n >= 3 THEN CREATE INDEX w_plate ON vehicles_w (plate);
                 CREATE INDEX w_prov_listed ON vehicles_w (province, listed_at DESC); END IF;
  IF n >= 6 THEN CREATE INDEX w_price ON vehicles_w (price_vnd);
                 CREATE INDEX w_brand ON vehicles_w (brand, model);
                 CREATE INDEX w_mileage ON vehicles_w (mileage_km); END IF;
END $$;

\echo '--- Một xe vào bảng chưa có index: 1 bản ghi WAL'
BEGIN;
EXPLAIN (ANALYZE, WAL, COSTS OFF) INSERT INTO vehicles_w SELECT * FROM vehicles WHERE id = 12345;
ROLLBACK;

\echo '--- Nạp 500.000 xe với 0, 1, 3 và 6 index. Xem dòng WAL và Execution Time'
CALL pg_temp.reset_w(0);
EXPLAIN (ANALYZE, WAL, COSTS OFF) INSERT INTO vehicles_w SELECT * FROM vehicles WHERE id <= 500000;
CALL pg_temp.reset_w(1);
EXPLAIN (ANALYZE, WAL, COSTS OFF) INSERT INTO vehicles_w SELECT * FROM vehicles WHERE id <= 500000;
CALL pg_temp.reset_w(3);
EXPLAIN (ANALYZE, WAL, COSTS OFF) INSERT INTO vehicles_w SELECT * FROM vehicles WHERE id <= 500000;
CALL pg_temp.reset_w(6);
EXPLAIN (ANALYZE, WAL, COSTS OFF) INSERT INTO vehicles_w SELECT * FROM vehicles WHERE id <= 500000;

\echo '--- Tách page: id tăng dần chỉ ghi vào page lá cuối, biển số rơi vào giữa cây'
SELECT 'id' AS index, leaf_pages, avg_leaf_density FROM pgstatindex('w_id')
UNION ALL
SELECT 'plate', leaf_pages, avg_leaf_density FROM pgstatindex('w_plate');

\echo '--- Dựng lại index plate một lần trên dữ liệu đã có: ít page hơn, page đầy hơn'
REINDEX INDEX w_plate;
SELECT 'plate sau REINDEX' AS index, leaf_pages, avg_leaf_density FROM pgstatindex('w_plate');

DROP TABLE vehicles_w;
