-- Bài 14. pg_trgm là gì? Tìm một đoạn giữa chuỗi bằng mẩu ba ký tự
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/pg-trgm-la-gi
\pset pager off
-- Một tiến trình cho kế hoạch dễ đọc; số page vẫn như khi chạy song song.
SET max_parallel_workers_per_gather = 0;

-- Bỏ mọi index mà các bài khác đã tạo, chỉ giữ index của khoá chính.
DO $$ DECLARE i text; BEGIN
  FOR i IN SELECT indexrelid::regclass::text FROM pg_index
           WHERE indrelid = 'vehicles'::regclass AND NOT indisprimary
  LOOP EXECUTE 'DROP INDEX ' || i; END LOOP;
END $$;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

\echo '--- Mẩu ba ký tự của 60055 (pg_trgm thêm khoảng trắng ở hai đầu)'
SELECT show_trgm('60055');

\echo '--- Một biển số cho 11 mẩu ba ký tự'
SELECT show_trgm('47P-600.55'), array_length(show_trgm('47P-600.55'), 1) AS so_mau;

\echo '--- Cắt riêng chuỗi 600.5 được 6 mẩu; mẫu LIKE %600.5% chỉ giữ 3: 600, "00 ", "  5"'
SELECT show_trgm('600.5');

\echo '--- 29A-1600.32 thiếu mẩu "  5"; 51A-600.45 đủ ba mẩu nhưng không chứa 600.5'
SELECT show_trgm('29A-1600.32'), show_trgm('51A-600.45'), '51A-600.45' LIKE '%600.5%' AS khop;

\echo '--- Số biển có từng mẩu, và có đủ cả ba (mất vài giây: cắt 5 triệu biển)'
SELECT count(*) FILTER (WHERE t @> '{600}')               AS co_600,
       count(*) FILTER (WHERE t @> '{"00 "}')             AS co_00_cach,
       count(*) FILTER (WHERE t @> '{"  5"}')             AS co_cach_cach_5,
       count(*) FILTER (WHERE t @> '{600,"00 ","  5"}')   AS du_ca_ba,
       round(avg(array_length(t, 1)), 1)                  AS mau_moi_bien
FROM (SELECT show_trgm(plate) AS t FROM vehicles) s;

\echo '--- Chưa có index: quét cả 192.308 page'
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate LIKE '%600.5%';

\echo '--- Index GIN trên các mẩu: 1.008 ứng viên, kiểm lại LIKE còn 500'
CREATE INDEX vehicles_plate_trgm_idx ON vehicles USING gin (plate gin_trgm_ops);
ANALYZE vehicles;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate LIKE '%600.5%';

\echo '--- Một mẩu: 5.000 ứng viên, cả 5.000 đều khớp'
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate LIKE '%600%';

\echo '--- Không mẩu nào: PostgreSQL đọc cả bảng'
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate LIKE '%60%';

\echo '--- Gõ thiếu dấu chấm: LIKE không ra xe nào, độ giống thì có (8 mẩu chung / 13 mẩu)'
SELECT count(*) FROM vehicles WHERE plate LIKE '%47P-60055%';
SELECT show_trgm('47P-60055'), similarity('47P-60055', '47P-600.55') AS do_giong;
