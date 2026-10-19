-- Bảng học của cả khoá. Mọi dữ liệu là giả, sinh theo id, không có thông tin người thật.
-- Chạy:  psql ... -v rows=5000000 -f seed.sql      (mặc định trong khoá: 5 triệu dòng)
\if :{?rows}
\else
  \set rows 200000
\endif

DROP TABLE IF EXISTS vehicles CASCADE;
SET timezone = 'Asia/Ho_Chi_Minh';

CREATE TABLE vehicles (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  plate       text        NOT NULL,   -- không UNIQUE: để chưa có index nào trên plate
  province    text        NOT NULL,
  brand       text        NOT NULL,
  model       text        NOT NULL,
  year        int         NOT NULL,
  mileage_km  int         NOT NULL,
  price_vnd   bigint      NOT NULL,
  fuel        text        NOT NULL,
  listed_at   timestamptz NOT NULL,
  sold_at     timestamptz,
  seller_note text        NOT NULL
);

SELECT setseed(0.42);

INSERT INTO vehicles (plate, province, brand, model, year, mileage_km, price_vnd,
                      fuel, listed_at, sold_at, seller_note)
SELECT
  -- Biển số giả: hoán vị id * 7919 mod 234.000.000, nên thứ tự biển số không theo thứ tự id.
  (10 + n / 2600000)::text || chr(65 + ((n / 100000) % 26)::int) || '-'
    || substr(lpad((n % 100000)::text, 5, '0'), 1, 3) || '.'
    || substr(lpad((n % 100000)::text, 5, '0'), 4, 2),
  -- Tỉnh lệch có chủ đích: TP.HCM và Hà Nội chiếm hơn nửa bảng, Lai Châu rất hiếm.
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
  -- Xe đăng càng lâu càng dễ đã bán; khoảng một phần mười bảng còn đang bán.
  CASE WHEN random() < 0.97 - 0.25 * (id::float / :rows)
       THEN least(listed + (random() * 60) * interval '1 day', timestamptz '2026-09-30 00:00:00+07') END,
  'Xe chính chủ, bảo dưỡng định kỳ, nội thất còn mới. Ghi chú người bán số ' || id
    || repeat(' ...', 20)
FROM (
  SELECT id,
         (id * 7919) % 234000000 AS n,
         random() AS p,
         timestamptz '2019-01-01 00:00:00+07'
           + (id::float / :rows) * (timestamptz '2026-09-30 00:00:00+07' - timestamptz '2019-01-01 00:00:00+07') AS listed
  FROM generate_series(1::bigint, :rows) AS id
) s;

VACUUM (ANALYZE) vehicles;
