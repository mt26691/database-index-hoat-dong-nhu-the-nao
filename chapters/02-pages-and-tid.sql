-- Chương 2: bảng là một dãy page 8 KB; mỗi dòng có một địa chỉ (block, item) gọi là ctid.
SHOW block_size;

SELECT pg_relation_size('vehicles') AS bytes,
       pg_relation_size('vehicles') / current_setting('block_size')::int AS pages,
       pg_relation_filepath('vehicles') AS file;

-- Mười dòng đầu và địa chỉ của chúng.
SELECT ctid, id, plate, province FROM vehicles ORDER BY id LIMIT 10;

-- Page 0 chứa bao nhiêu dòng?
SELECT count(*) AS rows_on_page_0 FROM vehicles WHERE (ctid::text::point)[0] = 0;

-- Nhìn vào bên trong page 0 bằng pageinspect (cần quyền superuser).
CREATE EXTENSION IF NOT EXISTS pageinspect;
SELECT lower, upper, special, pagesize FROM page_header(get_raw_page('vehicles', 0));
SELECT lp, lp_off, lp_len, t_ctid FROM heap_page_items(get_raw_page('vehicles', 0)) ORDER BY lp LIMIT 5;
SELECT lp, lp_off, lp_len, t_ctid FROM heap_page_items(get_raw_page('vehicles', 0)) ORDER BY lp DESC LIMIT 2;

-- ctid không phải khoá cố định: UPDATE tạo phiên bản mới ở chỗ khác.
BEGIN;
SELECT ctid, id FROM vehicles WHERE id = 3;
UPDATE vehicles SET mileage_km = mileage_km + 1 WHERE id = 3;
SELECT ctid, id FROM vehicles WHERE id = 3;
ROLLBACK;
