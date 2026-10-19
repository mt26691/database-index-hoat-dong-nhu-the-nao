-- Chương 5: index chỉ cho địa chỉ; các cột còn lại nằm trong heap.
SELECT plate AS p FROM vehicles WHERE id = 12345 \gset

-- Một dòng: 3 page index + 1 page heap.
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate = :'p';
SELECT ctid, id, brand, model, price_vnd FROM vehicles WHERE plate = :'p';

-- Nhiều dòng: các biển số liền nhau trong index nằm rải rác khắp heap.
SELECT count(*) AS rows, count(DISTINCT (ctid::text::point)[0]) AS heap_pages
FROM vehicles WHERE plate >= '47P-600' AND plate < '47P-700';
SELECT plate, ctid FROM vehicles WHERE plate >= '47P-600' AND plate < '47P-700' ORDER BY plate LIMIT 8;

SET enable_bitmapscan = off;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate >= '47P-600' AND plate < '47P-700';
RESET enable_bitmapscan;

-- Cùng số dòng nhưng theo id: các dòng liền nhau trong index cũng nằm liền nhau trong heap.
SELECT count(*) AS rows, count(DISTINCT (ctid::text::point)[0]) AS heap_pages
FROM vehicles WHERE id BETWEEN 100000 AND 100213;
SET enable_bitmapscan = off;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE id BETWEEN 100000 AND 100213;
RESET enable_bitmapscan;

-- Kế hoạch planner tự chọn cho khoảng biển số.
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate >= '47P-600' AND plate < '47P-700';
