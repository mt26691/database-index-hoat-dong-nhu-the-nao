-- Chương 11: mỗi index là thêm một chỗ phải ghi khi INSERT.
CREATE EXTENSION IF NOT EXISTS pgstattuple;
DROP TABLE IF EXISTS vehicles_w;
CREATE TABLE vehicles_w (LIKE vehicles INCLUDING DEFAULTS);
ALTER TABLE vehicles_w ALTER COLUMN id DROP IDENTITY IF EXISTS;

-- Một dòng, đo bằng EXPLAIN (ANALYZE, BUFFERS, WAL) trong transaction rồi ROLLBACK.
\echo '--- 0 index'
BEGIN;
EXPLAIN (ANALYZE, BUFFERS, WAL, COSTS OFF) INSERT INTO vehicles_w SELECT * FROM vehicles WHERE id = 12345;
ROLLBACK;

-- Nạp 500.000 dòng với 0, 1, 3 và 6 index; mỗi lần làm lại bảng từ đầu.
CREATE OR REPLACE PROCEDURE load_w(n_idx int) LANGUAGE plpgsql AS $$
BEGIN
  TRUNCATE vehicles_w;
  DROP INDEX IF EXISTS w_id, w_plate, w_prov_listed, w_price, w_brand, w_mileage;
  IF n_idx >= 1 THEN CREATE UNIQUE INDEX w_id ON vehicles_w (id); END IF;
  IF n_idx >= 3 THEN CREATE INDEX w_plate ON vehicles_w (plate);
                     CREATE INDEX w_prov_listed ON vehicles_w (province, listed_at DESC); END IF;
  IF n_idx >= 6 THEN CREATE INDEX w_price ON vehicles_w (price_vnd);
                     CREATE INDEX w_brand ON vehicles_w (brand, model);
                     CREATE INDEX w_mileage ON vehicles_w (mileage_km); END IF;
END $$;

CHECKPOINT;
CALL load_w(0);
EXPLAIN (ANALYZE, BUFFERS, WAL, COSTS OFF, SUMMARY ON) INSERT INTO vehicles_w SELECT * FROM vehicles WHERE id <= 500000;
CALL load_w(1);
EXPLAIN (ANALYZE, BUFFERS, WAL, COSTS OFF, SUMMARY ON) INSERT INTO vehicles_w SELECT * FROM vehicles WHERE id <= 500000;
CALL load_w(3);
EXPLAIN (ANALYZE, BUFFERS, WAL, COSTS OFF, SUMMARY ON) INSERT INTO vehicles_w SELECT * FROM vehicles WHERE id <= 500000;
CALL load_w(6);
EXPLAIN (ANALYZE, BUFFERS, WAL, COSTS OFF, SUMMARY ON) INSERT INTO vehicles_w SELECT * FROM vehicles WHERE id <= 500000;

-- Page split: id tăng dần chỉ ghi vào page lá cuối; biển số ngẫu nhiên rơi vào giữa cây.
SELECT 'w_id (id tăng dần)' AS idx, leaf_pages, avg_leaf_density FROM pgstatindex('w_id')
UNION ALL SELECT 'w_plate (biển số ngẫu nhiên)', leaf_pages, avg_leaf_density FROM pgstatindex('w_plate');
-- So với index dựng một lần bằng CREATE INDEX trên cùng dữ liệu.
REINDEX INDEX w_plate;
SELECT 'w_plate sau REINDEX' AS idx, leaf_pages, avg_leaf_density FROM pgstatindex('w_plate');
DROP TABLE vehicles_w;
DROP PROCEDURE load_w;
