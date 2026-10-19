-- Chương 9: planner ước lượng số dòng từ thống kê rồi chọn đường đọc rẻ nhất theo cost.
DROP INDEX IF EXISTS vehicles_province_idx, vehicles_price_idx;
CREATE INDEX vehicles_province_idx ON vehicles (province);
CREATE INDEX vehicles_price_idx ON vehicles (price_vnd);
ANALYZE vehicles;

-- Thống kê ANALYZE lưu lại: các giá trị phổ biến nhất và tần suất của chúng.
SELECT most_common_vals, most_common_freqs FROM pg_stats
WHERE tablename = 'vehicles' AND attname = 'province';
SELECT n_distinct, array_length(histogram_bounds, 1) AS histogram_buckets FROM pg_stats
WHERE tablename = 'vehicles' AND attname = 'price_vnd';

-- Cùng một câu, khác giá trị: tỉnh hiếm và tỉnh phổ biến.
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE province = 'Lai Châu';
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE province = 'TP.HCM';

-- Cost của từng đường đọc, khi tắt bớt các đường khác (chỉ để so sánh, đừng làm thế ở production).
SHOW seq_page_cost; SHOW random_page_cost; SHOW cpu_tuple_cost; SHOW cpu_index_tuple_cost; SHOW cpu_operator_cost;
SET enable_bitmapscan = off; SET enable_seqscan = off;
EXPLAIN SELECT * FROM vehicles WHERE province = 'TP.HCM';
RESET enable_bitmapscan; RESET enable_seqscan;

-- Giá xe phân bố đều từ 200 triệu tới 2 tỷ: đổi ngưỡng là đổi tỷ lệ dòng khớp.
EXPLAIN SELECT * FROM vehicles WHERE price_vnd < 201000000;
EXPLAIN SELECT * FROM vehicles WHERE price_vnd < 236000000;
EXPLAIN SELECT * FROM vehicles WHERE price_vnd < 560000000;

-- "shared hit" là page đã có trong bộ nhớ đệm của PostgreSQL (shared buffers); "read" là phải
-- xin hệ điều hành, có thể vẫn lấy từ cache của hệ điều hành chứ chưa chắc từ SSD.
-- Chạy hai lần liền: lần hai phần lớn page đã nằm trong shared buffers.
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate >= '33K-000' AND plate < '33K-300';
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate >= '33K-000' AND plate < '33K-300';
