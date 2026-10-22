-- Bài 14. PostgreSQL quyết định dùng index hay Seq Scan thế nào?
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/postgresql-chon-index-hay-seq-scan
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

\echo '--- Thống kê mà ANALYZE lưu lại: các tỉnh phổ biến nhất và tỷ lệ của chúng'
SELECT most_common_vals, most_common_freqs
FROM pg_stats WHERE tablename = 'vehicles' AND attname = 'province';

\echo '--- Cùng một câu, tỉnh hiếm và tỉnh phổ biến cho ra hai kế hoạch khác nhau'
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE province = 'Lai Châu';
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE province = 'TP.HCM';

\echo '--- Cost nếu bắt dùng index (chỉ để so, đừng làm vậy trên production)'
SET enable_seqscan = off; SET enable_bitmapscan = off;
EXPLAIN SELECT * FROM vehicles WHERE province = 'TP.HCM';
RESET enable_seqscan; RESET enable_bitmapscan;

\echo '--- Giá xe trải đều 200 triệu tới 2 tỷ: đổi ngưỡng giá là đổi số dòng khớp'
EXPLAIN SELECT * FROM vehicles WHERE price_vnd < 201000000;
EXPLAIN SELECT * FROM vehicles WHERE price_vnd < 236000000;
EXPLAIN SELECT * FROM vehicles WHERE price_vnd < 560000000;
