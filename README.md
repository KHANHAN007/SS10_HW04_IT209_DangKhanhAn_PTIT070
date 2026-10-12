# 1. Khởi chạy hệ thống

Sử dụng lại image Backend `hw-backend:v1` từ bài 2.

```bash
chmod +x commands.sh
bash -n commands.sh
./commands.sh
```

# 2. Kiểm tra network và volume

```bash
docker network ls | grep app-net
```

Kết quả:

```text
7840474c8823   app-net   bridge   local
```

```bash
docker volume ls | grep db-data
```

Kết quả:

```text
local     db-data
```

```bash
docker network inspect app-net
```

Trích thông tin container trong network:

| Container | Địa chỉ IPv4 |
|---|---|
| db-server | 172.22.0.2/16 |
| app-container | 172.22.0.3/16 |

# 3. Kiểm tra DNS nội bộ

```bash
docker exec app-container ping -c 2 db-server
```

Kết quả:

```text
PING db-server (172.22.0.2): 56 data bytes
64 bytes from 172.22.0.2: seq=0 ttl=64 time=0.106 ms
64 bytes from 172.22.0.2: seq=1 ttl=64 time=0.237 ms

--- db-server ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
round-trip min/avg/max = 0.106/0.171/0.237 ms
```

Tên `db-server` được phân giải thành IP nội bộ thông qua DNS
của Custom Bridge Network.

# 4. Kiểm tra Backend

```bash
curl -i http://localhost:8081
```

Trích kết quả:

```text
HTTP/1.1 200 OK
X-Powered-By: Express
Content-Type: application/json; charset=utf-8
```

Response:

```json
{
  "status": "success",
  "message": "Hello from Docker Single-stage!",
  "student": "Dang Khanh An - PTIT070"
}
```

Backend đã nhận các biến môi trường kết nối DB, nhưng mã nguồn
bài 2 chưa thực hiện truy vấn PostgreSQL. Phần kiểm thử database
dưới đây sử dụng công cụ `psql` trong container DB.

# 5. Thêm dữ liệu trước khi xóa container

Tạo bảng:

```bash
docker exec db-server psql -U appuser -d appdb -c \
"CREATE TABLE IF NOT EXISTS students (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL
);"
```

Kết quả:

```text
CREATE TABLE
```

Thêm dữ liệu:

```bash
docker exec db-server psql -U appuser -d appdb -c \
"INSERT INTO students (name) VALUES ('Dang Khanh An - PTIT070');"
```

Kết quả:

```text
INSERT 0 1
```

Đọc dữ liệu:

```bash
docker exec db-server psql -U appuser -d appdb -c \
"SELECT * FROM students;"
```

Kết quả trước khi xóa:

```text
 id |          name
----+-------------------------
  1 | Dang Khanh An - PTIT070
(1 row)
```

# 6. Xóa và tạo lại container PostgreSQL

Xóa cứng container:

```bash
docker rm -f db-server
```

Kết quả:

```text
db-server
```

Kiểm tra volume vẫn tồn tại:

```bash
docker volume ls | grep db-data
```

Kết quả:

```text
local     db-data
```

Tạo container DB mới gắn cùng volume:

```bash
docker run -d \
  --name db-server \
  --network app-net \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_PASSWORD=LabPassword123 \
  -e POSTGRES_DB=appdb \
  -v db-data:/var/lib/postgresql/data \
  postgres:15-alpine
```

Container mới được tạo với ID:

```text
28f074d4735996c643184cfacbafc4a6acbf2bd3e869313c1fdfaec70cc092b9
```

Kiểm tra PostgreSQL sẵn sàng:

```bash
docker exec db-server pg_isready -U appuser -d appdb
```

Kết quả:

```text
/var/run/postgresql:5432 - accepting connections
```
# 7. Xác minh dữ liệu sau khi tạo lại container

```bash
docker exec db-server psql -U appuser -d appdb -c \
"SELECT * FROM students;"
```

Kết quả:

```text
 id |          name
----+-------------------------
  1 | Dang Khanh An - PTIT070
(1 row)
```

Không thực hiện tạo bảng hoặc thêm dữ liệu lại sau khi tái tạo
container. Bản ghi vẫn tồn tại, chứng minh dữ liệu được giữ
trong Named Volume `db-data`.

# 8. Kết luận

- Hai container tham gia chung network `app-net`.
- Backend phân giải được hostname `db-server`.
- Backend trả HTTP 200 và JSON.
- Dữ liệu PostgreSQL vẫn nguyên vẹn sau khi xóa container DB
  và tạo container mới sử dụng cùng volume `db-data`.
