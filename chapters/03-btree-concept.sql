-- Chương 3: vì sao cây nhiều nhánh chỉ cần vài tầng.
-- Dùng index thật trên plate (tạo ở lab chương 4) để biết một page chứa bao nhiêu key.
CREATE EXTENSION IF NOT EXISTS pageinspect;
CREATE INDEX IF NOT EXISTS vehicles_plate_idx ON vehicles (plate);
SELECT type, count(*) AS pages, round(avg(live_items)) AS keys_per_page
FROM bt_multi_page_stats('vehicles_plate_idx', 1, -1) GROUP BY type ORDER BY type DESC;

-- Mỗi tầng nhân số nhánh lên khoảng 200 lần.
SELECT tang, round(power(200, tang)) AS so_key_toi_da
FROM generate_series(1, 5) AS tang;

-- So với cây nhị phân (2 nhánh mỗi nút) và đọc tuần tự.
SELECT n AS so_key,
       ceil(log(2, n)) AS tang_cay_nhi_phan,
       ceil(log(200, n)) AS tang_cay_200_nhanh
FROM unnest(ARRAY[1000, 1000000, 5000000, 1000000000]::numeric[]) AS n;
