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

\echo '--- Một biển số cho 11 mẩu ba ký tự'
SELECT show_trgm('47P-600.55'), array_length(show_trgm('47P-600.55'), 1) AS so_mau;

\echo '--- Cắt riêng chuỗi 600.5 được 6 mẩu; mẫu LIKE %600.5% chỉ giữ 3: 600, "00 ", "  5"'
SELECT show_trgm('600.5');

\echo '--- Số biển có từng mẩu, và có đủ cả ba (mất vài giây: cắt 5 triệu biển)'
SELECT count(*) FILTER (WHERE t @> '{600}')               AS co_600,
       count(*) FILTER (WHERE t @> '{"00 "}')             AS co_00_cach,
       count(*) FILTER (WHERE t @> '{"  5"}')             AS co_cach_cach_5,
       count(*) FILTER (WHERE t @> '{600,"00 ","  5"}')   AS du_ca_ba,
       round(avg(array_length(t, 1)), 1)                  AS mau_moi_bien
FROM (SELECT show_trgm(plate) AS t FROM vehicles) s;

\echo '--- Index GIN trên các mẩu: 1.008 ứng viên, kiểm lại LIKE còn 500'
CREATE INDEX vehicles_plate_trgm_idx ON vehicles USING gin (plate gin_trgm_ops);
ANALYZE vehicles;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate LIKE '%600.5%';

\echo '--- Một mẩu: 5.000 ứng viên, cả 5.000 đều khớp'
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate LIKE '%600%';

\echo '--- Không mẩu nào: PostgreSQL đọc cả bảng'
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate LIKE '%60%';

\echo '--- Mẩu luôn là chữ thường: cùng index phục vụ ILIKE'
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate ILIKE '%47p-600%';

\echo '--- Gõ sai: LIKE không ra gì, độ giống thì có'
SELECT count(*) FROM vehicles WHERE plate LIKE '%47P-6005%';
SELECT show_trgm('47P-6005'),
       similarity('47P-6005', '47P-600.55') AS do_giong,
       '47P-6005' <-> '47P-600.55'          AS khoang_cach;

\echo '--- 10 biển gần nhất, chưa có index GiST: đọc và xếp cả bảng'
EXPLAIN (ANALYZE, BUFFERS) SELECT plate FROM vehicles ORDER BY plate <-> '47P-6005' LIMIT 10;

\echo '--- Index GiST cho tìm gần nhất (mất khoảng 40 giây để tạo)'
CREATE INDEX vehicles_plate_gist_idx ON vehicles USING gist (plate gist_trgm_ops);
ANALYZE vehicles;
EXPLAIN (ANALYZE, BUFFERS) SELECT plate FROM vehicles ORDER BY plate <-> '47P-6005' LIMIT 10;
SELECT plate, round((plate <-> '47P-6005')::numeric, 3) AS khoang_cach
FROM vehicles ORDER BY plate <-> '47P-6005' LIMIT 10;
SELECT pg_size_pretty(pg_relation_size('vehicles_plate_trgm_idx')) AS gin,
       pg_size_pretty(pg_relation_size('vehicles_plate_gist_idx')) AS gist;
DROP INDEX vehicles_plate_gist_idx;
