-- Bài 4. PostgreSQL lưu dữ liệu trên đĩa như thế nào?
-- https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/postgresql-luu-du-lieu-tren-dia-nhu-the-nao
\pset pager off

\echo '--- File của bảng và số page'
SHOW block_size;
SELECT pg_relation_size('vehicles') AS bytes,
       pg_relation_size('vehicles') / 8192 AS pages,
       pg_relation_filepath('vehicles') AS file;

\echo '--- ctid là địa chỉ của dòng: (số page, số con trỏ trong page)'
SELECT ctid, id, plate FROM vehicles ORDER BY id LIMIT 10;
SELECT ctid, id FROM vehicles WHERE id = 12345;

\echo '--- Bên trong page 0: phần đầu page và các con trỏ dòng'
CREATE EXTENSION IF NOT EXISTS pageinspect;
SELECT lower, upper, pagesize FROM page_header(get_raw_page('vehicles', 0));
SELECT lp, lp_off, lp_len, t_ctid
FROM heap_page_items(get_raw_page('vehicles', 0)) ORDER BY lp LIMIT 5;

\echo '--- Sửa một dòng thì địa chỉ đổi (ROLLBACK để trả bảng về như cũ)'
BEGIN;
SELECT ctid FROM vehicles WHERE id = 3;
UPDATE vehicles SET mileage_km = mileage_km + 1 WHERE id = 3;
SELECT ctid FROM vehicles WHERE id = 3;
ROLLBACK;
