-- Bài 5. B-tree là gì?
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/b-tree-la-gi
\pset pager off

\echo '--- Số tầng của cây nhị phân và cây 200 nhánh ở bốn cỡ dữ liệu'
SELECT n AS so_key,
       ceil(log(2, n + 1)) AS cay_nhi_phan,
       ceil(log(200, n))   AS cay_200_nhanh
FROM unnest(ARRAY[1000, 1000000, 5000000, 1000000000]::numeric[]) AS n;

\echo '--- Index thật trên plate: mỗi page chứa bao nhiêu key? (r = gốc, i = page trong, l = lá)'
CREATE EXTENSION IF NOT EXISTS pageinspect;
CREATE INDEX IF NOT EXISTS vehicles_plate_idx ON vehicles (plate);
SELECT type, count(*) AS pages, round(avg(live_items)) AS keys_per_page
FROM bt_multi_page_stats('vehicles_plate_idx', 1, -1)
GROUP BY type ORDER BY type DESC;
