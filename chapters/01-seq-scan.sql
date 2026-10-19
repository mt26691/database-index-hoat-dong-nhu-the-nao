-- Chương 1: cùng một câu tìm biển số trên ba bảng 10 nghìn, 200 nghìn và 5 triệu dòng.
-- Chưa có index nào trên plate; chỉ có vehicles_pkey trên id.
DROP TABLE IF EXISTS vehicles_10k, vehicles_200k;
CREATE TABLE vehicles_10k  AS SELECT * FROM vehicles WHERE id <= 10000;
CREATE TABLE vehicles_200k AS SELECT * FROM vehicles WHERE id <= 200000;
VACUUM (ANALYZE) vehicles_10k, vehicles_200k;

-- Biển số của xe id = 5000, có trong cả ba bảng.
SELECT plate AS p FROM vehicles WHERE id = 5000 \gset
\echo 'Tìm biển số' :p

SELECT 'vehicles_10k' AS bang, (SELECT count(*) FROM vehicles_10k) AS so_dong,
       pg_relation_size('vehicles_10k') / 8192 AS so_page, pg_size_pretty(pg_relation_size('vehicles_10k')) AS dung_luong
UNION ALL SELECT 'vehicles_200k', (SELECT count(*) FROM vehicles_200k),
       pg_relation_size('vehicles_200k') / 8192, pg_size_pretty(pg_relation_size('vehicles_200k'))
UNION ALL SELECT 'vehicles', (SELECT count(*) FROM vehicles),
       pg_relation_size('vehicles') / 8192, pg_size_pretty(pg_relation_size('vehicles'));

-- Chạy hai lần cho mỗi bảng: lần đầu làm nóng cache, lần sau là số được ghi lại.
SELECT * FROM vehicles_10k  WHERE plate = :'p';
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles_10k  WHERE plate = :'p';
SELECT * FROM vehicles_200k WHERE plate = :'p';
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles_200k WHERE plate = :'p';
SELECT * FROM vehicles      WHERE plate = :'p';
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles      WHERE plate = :'p';

-- Không cho chạy song song để thấy một tiến trình phải đọc bao nhiêu.
SET max_parallel_workers_per_gather = 0;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate = :'p';
RESET max_parallel_workers_per_gather;

-- Tìm theo id thì khác: id đã có index của khoá chính.
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE id = 5000;
