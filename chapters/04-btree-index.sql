-- Chương 4: tạo index B-tree trên plate rồi nhìn vào các page của nó bằng pageinspect.
CREATE EXTENSION IF NOT EXISTS pageinspect;
DROP INDEX IF EXISTS vehicles_plate_idx;
\timing on
CREATE INDEX vehicles_plate_idx ON vehicles (plate);
\timing off
VACUUM (ANALYZE) vehicles;

SELECT pg_size_pretty(pg_relation_size('vehicles_plate_idx')) AS index_size,
       pg_relation_size('vehicles_plate_idx') / 8192 AS index_pages,
       pg_size_pretty(pg_relation_size('vehicles')) AS heap_size;

-- Trang meta (block 0) cho biết root nằm ở block nào và cây cao mấy tầng.
SELECT root, level, fastroot, fastlevel FROM bt_metap('vehicles_plate_idx');

-- Đếm page theo loại: r = root, i = internal, l = leaf.
SELECT type, count(*) AS pages, round(avg(live_items)) AS avg_items, round(avg(avg_item_size)) AS avg_item_bytes
FROM bt_multi_page_stats('vehicles_plate_idx', 1, -1) GROUP BY type ORDER BY type DESC;

-- Đọc key dạng chữ từ cột data (varlena 1 byte header) để lần theo đường đi.
CREATE OR REPLACE FUNCTION bt_key(data text) RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN data IS NULL OR data = '' THEN NULL
         ELSE convert_from(substring(decode(replace(data, ' ', ''), 'hex') FROM 2
                 FOR (get_byte(decode(replace(data, ' ', ''), 'hex'), 0) >> 1) - 1), 'UTF8') END $$;

SELECT plate AS p FROM vehicles WHERE id = 12345 \gset
\echo 'Tìm biển số' :p

-- Lần theo từ root xuống leaf: ở mỗi page, chọn item cuối cùng có key <= biển số cần tìm.
WITH RECURSIVE walk(depth, blk, pg_type) AS (
  SELECT 0, root, 'root' FROM bt_metap('vehicles_plate_idx')
  UNION ALL
  SELECT w.depth + 1, (c.ctid::text::point)[0]::int,
         CASE WHEN s.btpo_level = 1 THEN 'leaf' ELSE 'internal' END
  FROM walk w
  CROSS JOIN LATERAL bt_page_stats('vehicles_plate_idx', w.blk) s
  CROSS JOIN LATERAL (
    SELECT i.ctid FROM bt_page_items('vehicles_plate_idx', w.blk) i
    WHERE (i.itemoffset = 1 AND s.btpo_next = 0) OR (i.itemoffset = 1 AND bt_key(i.data) IS NULL)
          OR (i.itemoffset > 1 AND bt_key(i.data) <= :'p') OR (s.btpo_next <> 0 AND i.itemoffset = 2 AND bt_key(i.data) <= :'p')
    ORDER BY i.itemoffset DESC LIMIT 1) c
  WHERE s.btpo_level > 0
)
SELECT w.depth, w.blk, w.pg_type, s.live_items, s.btpo_level AS level
FROM walk w CROSS JOIN LATERAL bt_page_stats('vehicles_plate_idx', w.blk) s ORDER BY depth;

-- Ba key đầu của root: key dẫn đường cho từng nhánh.
SELECT r.itemoffset, bt_key(r.data) AS key, (r.ctid::text::point)[0]::int AS child_block
FROM bt_metap('vehicles_plate_idx') m, LATERAL bt_page_items('vehicles_plate_idx', m.root) r
ORDER BY r.itemoffset LIMIT 4;

-- Câu Q1 bây giờ.
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vehicles WHERE plate = :'p';

-- Kiểm lại đường đi bằng tay (số block lấy từ kết quả ở trên, mỗi máy một khác).
SELECT root AS root_blk FROM bt_metap('vehicles_plate_idx') \gset
SELECT itemoffset, bt_key(data) AS key, (ctid::text::point)[0]::int AS child
FROM bt_page_items('vehicles_plate_idx', :root_blk)
WHERE bt_key(data) <= :'p' ORDER BY itemoffset DESC LIMIT 1 \gset lvl1_
SELECT :lvl1_child AS internal_blk \gset
SELECT itemoffset, bt_key(data) AS key, (ctid::text::point)[0]::int AS child
FROM bt_page_items('vehicles_plate_idx', :internal_blk)
WHERE itemoffset > 1 AND bt_key(data) <= :'p' ORDER BY itemoffset DESC LIMIT 1 \gset lvl2_
\echo 'root' :root_blk '→ key' :'lvl1_key' '→ internal' :internal_blk '→ key' :'lvl2_key' '→ leaf' :lvl2_child
SELECT itemoffset, bt_key(data) AS key, htid FROM bt_page_items('vehicles_plate_idx', :lvl2_child)
WHERE bt_key(data) = :'p';
SELECT ctid FROM vehicles WHERE plate = :'p';
SELECT btpo_prev, btpo_next FROM bt_page_stats('vehicles_plate_idx', :lvl2_child);
