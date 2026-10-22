-- Bài 4. PostgreSQL lưu dữ liệu trên đĩa như thế nào?
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/postgresql-luu-du-lieu-tren-dia-nhu-the-nao
\pset pager off

\echo '--- File của bảng và số page'
SHOW block_size;
SELECT pg_relation_size('vehicles') AS bytes,
       pg_relation_size('vehicles') / 8192 AS pages,
       pg_relation_filepath('vehicles') AS file;

\echo '--- ctid là địa chỉ của dòng: (số page, số con trỏ trong page)'
SELECT ctid, id, plate FROM vehicles ORDER BY id LIMIT 3;
SELECT ctid, id, plate FROM vehicles WHERE plate = '25F-950.00';

\echo '--- Bên trong page 0: phần đầu page và các con trỏ dòng'
CREATE EXTENSION IF NOT EXISTS pageinspect;
SELECT lower, upper, pagesize, upper - lower AS free_bytes
FROM page_header(get_raw_page('vehicles', 0));
SELECT lp, lp_off, lp_len, t_ctid
FROM heap_page_items(get_raw_page('vehicles', 0)) ORDER BY lp LIMIT 5;

\echo '--- Sửa một dòng thì địa chỉ đổi (ROLLBACK để trả bảng về như cũ)'
-- Lần chạy đầu ra (192307,19). Chạy lại thì số con trỏ tăng dần (20, 21…), vì phiên bản bị ROLLBACK
-- vẫn chiếm chỗ trong page cuối cho tới khi VACUUM dọn nó.
BEGIN;
SELECT ctid FROM vehicles WHERE id = 3;
UPDATE vehicles SET mileage_km = mileage_km + 1 WHERE id = 3;
SELECT ctid FROM vehicles WHERE id = 3;
ROLLBACK;
