# database-index-hoat-dong-nhu-the-nao — phòng lab của khoá "Database index hoạt động như thế nào?"

Repo này chứa **dữ liệu mẫu** và **file `.sql` của từng bài** trong khoá
[Database index hoạt động như thế nào?](https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao)
trên nguyenly.dev.

Mọi con số trong khoá (số page, số dòng đã kiểm tra, thời gian chạy) đều đo bằng đúng những file
ở đây, trên PostgreSQL 18. Bạn chạy lại được trên máy mình. Chỉ cần Docker.

Hướng dẫn từng bước có trong bài cuối của khoá:
[Repo thực hành: tự chạy lại mọi phép đo trong khoá](https://nguyenly.dev/khoa-hoc/database-index-hoat-dong-nhu-the-nao/repo-thuc-hanh).

## Dựng bảng 5 triệu xe

```bash
git clone https://github.com/mt26691/database-index-hoat-dong-nhu-the-nao.git
cd database-index-hoat-dong-nhu-the-nao
docker compose up -d                                    # PostgreSQL 18, cổng 5435, user/pass/db = lab
./psql.sh -v rows=5000000 -v ON_ERROR_STOP=1 < seed.sql   # khoảng 20 giây, bảng 1,5 GB
```

Vào database:

```bash
./psql.sh
```

Thử câu tìm biển số của bài 1:

```sql
SELECT * FROM vehicles WHERE plate = '25F-950.00';
```

Ra đúng một chiếc xe là xong. Gõ `\q` để thoát.

## Dữ liệu mẫu: một website mua bán xe cũ

Một bảng `vehicles`, 5 triệu xe giả, sinh theo `id` với `setseed(0.42)`, nên lần nào chạy cũng ra
cùng dữ liệu: biển số, tỉnh, hãng, dòng xe, năm, số km, giá, nhiên liệu, ngày đăng, ngày bán, ghi chú
của người bán. Khoá chính `id` là index duy nhất lúc đầu.

## Lab theo từng bài

Chạy lab một bài và lưu kết quả vào `results/`:

```bash
./run.sh 01        # → results/01.txt
```

Chạy theo thứ tự: lab sau dựa vào index mà lab trước tạo hoặc xoá.

| File | Bài trong khoá |
|---|---|
| `chapters/01-seq-scan.sql` | 1–3. Index là gì, PostgreSQL tìm dữ liệu thế nào, index giúp nhanh hơn ra sao |
| `chapters/02-pages-and-tid.sql` | 4. PostgreSQL lưu dữ liệu trên đĩa như thế nào? |
| `chapters/03-btree-concept.sql` | 5. B-tree là gì? |
| `chapters/04-btree-index.sql` | 6. PostgreSQL sử dụng B-tree làm index như thế nào? |
| `chapters/05-index-to-heap.sql` | 7. Index Scan tìm row trong heap như thế nào? |
| `chapters/06-index-only.sql` | 8. Index Only Scan tránh đọc heap bằng cách nào? |
| `chapters/07-composite-index.sql` | 9. Index nhiều cột hoạt động như thế nào? |
| `chapters/08-when-index-not-used.sql` | 10. Vì sao có index nhưng query không tận dụng được? |
| `chapters/09-query-planner.sql` | 11. PostgreSQL quyết định dùng index hay Seq Scan thế nào? |
| `chapters/10-specialized-indexes.sql` | 12. Khi index thông thường không phù hợp thì làm gì? |
| `chapters/11-write-cost.sql` | 13. Vì sao index làm INSERT và UPDATE chậm hơn? |
| `chapters/12-vacuum-hot-bloat.sql` | 14. Vì sao index phình to theo thời gian? |
| `chapters/13-slow-query-lab.sql` | 15. Tối ưu một truy vấn chậm bằng EXPLAIN ANALYZE |

Chú thích trong các file `.sql` còn ghi "Chương N" theo số chương cũ (lab viết trước khi bài 1 được
tách thành ba bài). Bảng trên là cách đối chiếu.

## Các file khác

| File | Làm gì |
|---|---|
| `bench.py` | đo thời gian dùng trong bài: 1 lần làm nóng + 7 lần đo, lấy trung vị → `results/bench.json` |
| `planner_sweep.py` | bài 11: cost của planner cho ba cách đọc khi đổi tỷ lệ dòng khớp → `results/09-planner-sweep.json` |
| `results/` | kết quả thô của lần chạy ngày 09/10/2026 (Apple M5, Docker) |

Máy khác sẽ cho số mili giây khác. Số page và số dòng thì giống hệt, vì chúng chỉ phụ thuộc vào dữ liệu.

## Lưu ý

Đừng chạy `EXPLAIN ANALYZE` trên `INSERT` hay `UPDATE` ở database thật mà không bọc trong
`BEGIN … ROLLBACK`: `ANALYZE` chạy câu lệnh thật.

Dừng và xoá database lab:

```bash
docker compose down -v
```
