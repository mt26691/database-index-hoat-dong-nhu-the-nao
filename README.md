# Database index hoạt động như thế nào?

SQL đi kèm khoá học [Database index hoạt động như thế nào?](https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao) trên nguyenly.dev.

Bạn chỉ cần Docker.

## Cài đặt

```bash
git clone https://github.com/mt26691/database-index-hoat-dong-nhu-the-nao.git
cd database-index-hoat-dong-nhu-the-nao
docker compose up -d --wait
```

Lần đầu, lệnh này tải PostgreSQL 18 và tạo bảng `vehicles` 5 triệu xe, mất khoảng một phút.

## Chạy SQL của một bài

```bash
docker compose exec db psql -f bai/01-index-la-gi.sql
```

Đổi tên file để chạy bài khác. Mỗi file chạy riêng được, không cần theo thứ tự.

Muốn gõ SQL tự do:

```bash
docker compose exec db psql
```

## Các bài

| File | Bài |
|---|---|
| [`01-index-la-gi.sql`](bai/01-index-la-gi.sql) | Index là gì và vì sao cần nó? |
| [`02-postgresql-tim-du-lieu-nhu-the-nao.sql`](bai/02-postgresql-tim-du-lieu-nhu-the-nao.sql) | PostgreSQL tìm dữ liệu như thế nào? |
| [`03-index-hoat-dong-nhu-the-nao.sql`](bai/03-index-hoat-dong-nhu-the-nao.sql) | Index giúp truy vấn nhanh hơn bằng cách nào? |
| [`04-postgresql-luu-du-lieu-tren-dia-nhu-the-nao.sql`](bai/04-postgresql-luu-du-lieu-tren-dia-nhu-the-nao.sql) | PostgreSQL lưu dữ liệu trên đĩa như thế nào? |
| [`05-b-tree-la-gi.sql`](bai/05-b-tree-la-gi.sql) | B-tree là gì? |
| [`06-postgresql-su-dung-b-tree-lam-index-nhu-the-nao.sql`](bai/06-postgresql-su-dung-b-tree-lam-index-nhu-the-nao.sql) | PostgreSQL sử dụng B-tree làm index như thế nào? |
| [`07-index-scan-lay-dong-tu-heap.sql`](bai/07-index-scan-lay-dong-tu-heap.sql) | Index Scan lấy dòng từ heap như thế nào? |
| [`08-index-scan-nhieu-dong-bitmap-heap-scan.sql`](bai/08-index-scan-nhieu-dong-bitmap-heap-scan.sql) | Vì sao nhiều dòng khớp thì Index Scan chậm? |
| [`09-index-only-scan-tranh-doc-heap.sql`](bai/09-index-only-scan-tranh-doc-heap.sql) | Index Only Scan tránh đọc heap bằng cách nào? |
| [`10-index-nhieu-cot-hoat-dong-nhu-the-nao.sql`](bai/10-index-nhieu-cot-hoat-dong-nhu-the-nao.sql) | Index nhiều cột (composite index) hoạt động như thế nào? |
| [`11-index-giup-order-by-limit-nhu-the-nao.sql`](bai/11-index-giup-order-by-limit-nhu-the-nao.sql) | Index giúp ORDER BY và LIMIT nhanh hơn thế nào? |
| [`12-vi-sao-query-khong-tan-dung-index.sql`](bai/12-vi-sao-query-khong-tan-dung-index.sql) | Vì sao có index nhưng query không tận dụng được? |
| [`13-vi-sao-like-khong-dung-index.sql`](bai/13-vi-sao-like-khong-dung-index.sql) | Vì sao LIKE vẫn quét cả bảng dù có index? |
| [`14-postgresql-chon-index-hay-seq-scan.sql`](bai/14-postgresql-chon-index-hay-seq-scan.sql) | PostgreSQL quyết định dùng index hay Seq Scan thế nào? |
| [`15-partial-index-la-gi.sql`](bai/15-partial-index-la-gi.sql) | Partial index là gì và khi nào nên dùng? |
| [`16-vi-sao-index-lam-ghi-cham-hon.sql`](bai/16-vi-sao-index-lam-ghi-cham-hon.sql) | Vì sao index làm INSERT chậm hơn? |
| [`17-update-trong-postgresql-hoat-dong-nhu-the-nao.sql`](bai/17-update-trong-postgresql-hoat-dong-nhu-the-nao.sql) | UPDATE trong PostgreSQL hoạt động như thế nào? |
| [`18-vi-sao-index-phinh-to.sql`](bai/18-vi-sao-index-phinh-to.sql) | Vì sao index phình to theo thời gian? |
| [`19-toi-uu-truy-van-cham-postgresql.sql`](bai/19-toi-uu-truy-van-cham-postgresql.sql) | Tối ưu một truy vấn chậm bằng EXPLAIN ANALYZE |
| [`20-bai-tap.sql`](bai/20-bai-tap.sql) | Bài tập: tự lần theo một câu SQL |

## Dữ liệu

Bảng `vehicles` là 5 triệu xe giả của một website mua bán xe cũ: biển số, tỉnh, hãng, giá, ngày đăng, ngày bán. Dữ liệu sinh từ [`seed.sql`](seed.sql) với hạt giống cố định, nên máy nào cũng ra cùng một bảng. Hai bảng nhỏ `vehicles_10k` và `vehicles_200k` dùng để so sánh ở bài 1 và bài 2.

Số mili giây trên máy bạn sẽ khác số trong bài. Số page và số dòng thì giống hệt.

## Kết nối bằng công cụ khác

PostgreSQL mở ở cổng `5435`, user `postgres`, mật khẩu `postgres`, database `postgres`. Dùng được với DBeaver, TablePlus, pgAdmin.

## Xoá

```bash
docker compose down -v
```
