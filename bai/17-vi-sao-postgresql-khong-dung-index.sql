-- Bài 17. Vì sao PostgreSQL không dùng index dù đã có index?
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/vi-sao-postgresql-khong-dung-index
\pset pager off

-- Bỏ mọi index mà các bài khác đã tạo, chỉ giữ index của khoá chính.
DO $$ DECLARE i text; BEGIN
  FOR i IN SELECT indexrelid::regclass::text FROM pg_index
           WHERE indrelid = 'vehicles'::regclass AND NOT indisprimary
  LOOP EXECUTE 'DROP INDEX ' || i; END LOOP;
END $$;
CREATE INDEX vehicles_province_idx ON vehicles (province);
CREATE INDEX vehicles_price_idx ON vehicles (price_vnd);
ANALYZE vehicles;

\echo '--- Cùng một index, hai tỉnh, hai kế hoạch'
EXPLAIN SELECT * FROM vehicles WHERE province = 'Lai Châu';
EXPLAIN SELECT * FROM vehicles WHERE province = 'TP.HCM';

\echo '--- Số xe thật của từng tỉnh'
SELECT province, count(*) AS so_xe, round(100.0 * count(*) / sum(count(*)) OVER (), 2) AS phan_tram
FROM vehicles GROUP BY province ORDER BY so_xe DESC;

\echo '--- Thống kê ANALYZE lưu lại: các tỉnh hay gặp và tần suất ước tính (mỗi lần ANALYZE lấy mẫu khác nên số lệch một chút)'
SELECT most_common_vals, most_common_freqs
FROM pg_stats WHERE tablename = 'vehicles' AND attname = 'province';

\echo '--- Xe khớp nằm trên bao nhiêu page của bảng (192.308 page)'
SELECT province, count(DISTINCT (ctid::text::point)[0]) AS so_page
FROM vehicles WHERE province IN ('Lai Châu', 'TP.HCM') GROUP BY province;

\echo '--- Cost của cả ba cách đọc: tạm cấm từng cách để planner lộ cost của cách còn lại (chỉ để so)'
SET enable_bitmapscan = off; SET enable_seqscan = off;
EXPLAIN SELECT * FROM vehicles WHERE province = 'Lai Châu';  -- Index Scan
EXPLAIN SELECT * FROM vehicles WHERE province = 'TP.HCM';
RESET ALL;
SET enable_indexscan = off; SET enable_seqscan = off;
EXPLAIN SELECT * FROM vehicles WHERE province = 'TP.HCM';    -- Bitmap Heap Scan
RESET ALL;
SET enable_indexscan = off; SET enable_bitmapscan = off;
EXPLAIN SELECT * FROM vehicles WHERE province = 'Lai Châu';  -- quét bảng
RESET ALL;

\echo '--- Giá xe trải đều 200 triệu tới 2 tỷ: đổi ngưỡng giá là đổi số dòng khớp'
EXPLAIN SELECT * FROM vehicles WHERE price_vnd < 201000000;
EXPLAIN SELECT * FROM vehicles WHERE price_vnd < 236000000;
EXPLAIN SELECT * FROM vehicles WHERE price_vnd < 560000000;

\echo '--- Số dòng planner đoán (rows=) so với số dòng thật (actual rows=); ANALYZE chạy thật câu SQL'
EXPLAIN ANALYZE SELECT * FROM vehicles WHERE province = 'Lai Châu';
