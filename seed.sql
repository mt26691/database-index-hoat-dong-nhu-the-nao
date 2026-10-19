-- Tạo bảng vehicles 5 triệu xe giả. Docker chạy file này một lần, lúc database mới được tạo.
-- Dữ liệu sinh theo id với hạt giống cố định, nên máy nào cũng ra cùng một bảng.

SET timezone = 'Asia/Ho_Chi_Minh';

CREATE TABLE vehicles (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  plate       text        NOT NULL,   -- biển số, không UNIQUE
  province    text        NOT NULL,
  brand       text        NOT NULL,
  model       text        NOT NULL,
  year        int         NOT NULL,
  mileage_km  int         NOT NULL,
  price_vnd   bigint      NOT NULL,
  fuel        text        NOT NULL,
  listed_at   timestamptz NOT NULL,   -- ngày đăng bán
  sold_at     timestamptz,            -- NULL nghĩa là xe còn đang bán
  seller_note text        NOT NULL
);

SELECT setseed(0.42);

INSERT INTO vehicles (plate, province, brand, model, year, mileage_km, price_vnd,
                      fuel, listed_at, sold_at, seller_note)
SELECT
  -- Biển số sinh từ (id * 7919) % 234000000, nên thứ tự biển số không theo thứ tự id.
  (10 + n / 2600000)::text || chr(65 + ((n / 100000) % 26)::int) || '-'
    || substr(lpad((n % 100000)::text, 5, '0'), 1, 3) || '.'
    || substr(lpad((n % 100000)::text, 5, '0'), 4, 2),
  -- TP.HCM và Hà Nội chiếm hơn nửa bảng, Lai Châu rất ít.
  CASE
    WHEN p < 0.30  THEN 'TP.HCM'
    WHEN p < 0.55  THEN 'Hà Nội'
    WHEN p < 0.63  THEN 'Đồng Nai'
    WHEN p < 0.69  THEN 'Hải Phòng'
    WHEN p < 0.75  THEN 'Đà Nẵng'
    WHEN p < 0.80  THEN 'Cần Thơ'
    WHEN p < 0.84  THEN 'Quảng Ninh'
    WHEN p < 0.88  THEN 'Khánh Hòa'
    WHEN p < 0.91  THEN 'Lâm Đồng'
    WHEN p < 0.94  THEN 'Nghệ An'
    WHEN p < 0.97  THEN 'Thanh Hóa'
    WHEN p < 0.995 THEN 'Huế'
    ELSE 'Lai Châu'
  END,
  (ARRAY['Toyota','Honda','Hyundai','Kia','Mazda','Ford','VinFast','Mitsubishi'])[1 + (id % 8)],
  (ARRAY['Vios','City','Accent','Morning','CX-5','Ranger','VF 5','Xpander','Innova','Civic'])[1 + (id % 10)],
  2010 + (id % 16)::int,
  (random() * 200000)::int,
  (200 + random() * 1800)::bigint * 1000000,
  (ARRAY['xăng','dầu','điện','hybrid'])[1 + (id % 4)],
  listed,
  -- Xe đăng càng lâu càng dễ đã bán. Khoảng một phần mười bảng còn đang bán.
  CASE WHEN random() < 0.97 - 0.25 * (id::float / 5000000)
       THEN least(listed + (random() * 60) * interval '1 day', timestamptz '2026-09-30 00:00:00+07') END,
  'Xe chính chủ, bảo dưỡng định kỳ, nội thất còn mới. Ghi chú người bán số ' || id
    || repeat(' ...', 20)
FROM (
  SELECT id,
         (id * 7919) % 234000000 AS n,
         random() AS p,
         timestamptz '2019-01-01 00:00:00+07'
           + (id::float / 5000000) * (timestamptz '2026-09-30 00:00:00+07' - timestamptz '2019-01-01 00:00:00+07') AS listed
  FROM generate_series(1::bigint, 5000000) AS id
) s;

-- Hai bảng nhỏ hơn để so với bảng 5 triệu xe (bài 1 và bài 2).
CREATE TABLE vehicles_10k  AS SELECT * FROM vehicles WHERE id <= 10000;
CREATE TABLE vehicles_200k AS SELECT * FROM vehicles WHERE id <= 200000;

VACUUM (ANALYZE) vehicles, vehicles_10k, vehicles_200k;
