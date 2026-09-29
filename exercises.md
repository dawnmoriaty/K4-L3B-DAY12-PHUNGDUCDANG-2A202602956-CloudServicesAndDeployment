# Phiếu Phản Ánh — K4 Level 3B, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: điền câu trả lời chi tiết vào bên dưới từng câu hỏi.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Phùng Đức Đăng  Mã học viên: 2A202602956

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Tình huống: Khi triển khai lên môi trường Cloud/Staging hoặc Production, kỹ sư quên cấu hình biến môi trường `AGENT_API_KEY` trong dashboard (ví dụ Render/Railway) hoặc gõ sai tên biến môi trường.
- Nếu để giá trị mặc định là `"changeme"`: Service vẫn khởi động bình thường, endpoint `/health` vẫn trả về HTTP 200 OK. Hệ thống monitoring tưởng rằng ứng dụng hoạt động tốt. Tuy nhiên, toàn bộ client thực tế với key thật sẽ bị từ chối 401 Unauthorized, trong khi bất kỳ ai quét bot công khai trên Internet thử key mặc định `"changeme"` đều có thể truy cập trái phép vào API nội bộ và tiêu tốn ngân sách/tài nguyên. Lỗi này có thể âm thầm kéo dài mà không bị phát hiện lúc deploy.
- Nếu fail fast (bắt buộc có key): Ứng dụng sẽ crash ngay lập tức trong 1-2 giây đầu khởi động khi Pydantic Settings raise ValidationError. Container không pass được liveness probe, orchestrator/nền tảng cloud báo Deploy Failed ngay và giữ container cũ. Kỹ sư được cảnh báo lập tức trong log triển khai để bổ sung key trước khi người dùng thực tế bị gián đoạn.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

Dòng log JSON thực tế thu được từ service:
```json
{"timestamp":"2026-09-29T04:12:45.123456Z","level":"info","event":"ask_request","user_id":"dangpd","question":"Xin chao","history_length":3,"spent":0.004}
```

Hai việc làm được với log JSON mà lệnh print dạng chuỗi thô không làm được:
1. **Lọc, truy vấn và tổng hợp tự động trên Log Aggregator (Elasticsearch/Datadog/Grafana Loki):** Do log có cấu trúc key-value (JSON), hệ thống có thể dễ dàng chạy các bộ lọc phức tạp như `event: "ask_request" AND spent > 0.05` hoặc vẽ biểu đồ aggregate tính tổng `spent` theo từng `user_id` theo thời gian thực mà không cần viết regex bóc tách chuỗi phức tạp và dễ gãy.
2. **Theo dõi ngữ cảnh và truy vết lỗi (Tracing & Correlation):** Mỗi dòng log gắn liền với các metadata chuẩn hóa (`timestamp` chuẩn ISO 8601 UTC, `level`, `user_id`, `request_id`). Khi có sự cố, hệ thống alerting có thể lọc theo `level: "error"` và nhóm theo `user_id` để biết chính xác người dùng nào đang gặp lỗi và vào thời điểm nào mà không bị lẫn lộn giữa hàng triệu dòng text của nhiều worker chạy song song.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | ~420 MB |
| Multi-stage | 269 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

Phần dung lượng chênh lệch (~151 MB) bao gồm:
1. Thư mục cache cài đặt của pip (`/root/.cache/pip`), các file wheel và tarball tạm thời tải về trong quá trình build package.
2. Các công cụ build tool, trình biên dịch (gcc/g++) và header files tạm thời (nếu có compile C-extensions trong stage builder).
3. Lịch sử các layer trung gian và file rác phát sinh khi chạy `pip install`. Trong multi-stage build, runtime stage chỉ copy kết quả cuối cùng từ `/root/.local` sang một image base sạch, loại bỏ hoàn toàn toàn bộ artifact thừa thãi của quá trình build.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

- Với Dockerfile hiện tại (copy `requirements.txt` trước, chạy `pip install`, rồi mới `COPY app/ app/`):
  Khi sửa một ký tự trong `app/main.py`:
  + Các layer: tải base image `python:3.11-slim`, `COPY requirements.txt .`, và `RUN pip install ...` đều được DÙNG LẠI TỪ CACHE (CACHED) vì nội dung `requirements.txt` không thay đổi.
  + Chỉ có layer `COPY app/ app/` và các lệnh sau đó (như thiết lập USER, EXPOSE, CMD) mới phải chạy lại. Quá trình build chỉ mất chưa đầy 1 giây.
- Nếu đặt `COPY . .` lên trước `RUN pip install`:
  Mỗi khi sửa dù chỉ 1 ký tự trong `app/main.py`, checksum của context `COPY . .` sẽ bị thay đổi, làm mất hiệu lực (bust cache) toàn bộ các layer phía sau nó. Do đó, Docker sẽ buộc phải chạy lại toàn bộ lệnh `RUN pip install -r requirements.txt`, tải lại và cài đặt lại toàn bộ dependencies từ đầu mỗi lần build, khiến thời gian build tăng từ vài giây lên vài phút và tốn băng thông mạng vô ích.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

Chuỗi sự kiện leo quyền:
1. Kẻ tấn công phát hiện lỗ hổng thực thi mã từ xa (RCE) trong code Python (ví dụ: deserialize không an toàn với `pickle`, template injection, hoặc lỗi trong một thư viện bên thứ ba).
2. Lỗ hổng cho phép kẻ tấn công thực thi arbitrary shell commands bên trong container.
3. Nếu container chạy với user mặc định là `root` (UID 0), tiến trình trong container có đặc quyền root (UID 0 khớp với root trên Linux host nếu không bật user namespaces).
4. Từ quyền root trong container, kẻ tấn công có thể khai thác các lỗ hổng container breakout (ví dụ các CVE của Linux kernel, gắn cờ privileged, truy cập vào unix socket `/var/run/docker.sock` hoặc các mount nhạy cảm từ host) để thoát khỏi container và chiếm quyền điều khiển root trên toàn bộ máy chủ vật lý/host machine.

Lệnh `USER appuser` cắt đứt chuỗi tấn công ở bước 3: Tiến trình Python bị giới hạn dưới quyền một user thường không có đặc quyền (unprivileged user UID 1000). Ngay cả khi khai thác được RCE trong ứng dụng, kẻ tấn công chỉ có quyền đọc/ghi hạn chế trong thư mục app, không thể cài package hệ thống, không sửa đổi được file cấu hình của container và không có quyền root để thực hiện các cuộc tấn công breakout kernel nhắm vào máy host.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

- Số request tối đa có thể gửi trong 2 giây liên tiếp: **20 request**.
- Giải thích (hiện tượng Fixed Window Burst):
  Giả sử hạn mức là 10 request/phút theo giờ đồng hồ (ví dụ từ phút 00 đến phút 01).
  + Ở giây thứ 59 của phút thứ 1 (ví dụ 10:00:59): Người dùng gửi 10 request. Vì trong phút 10:00 chưa dùng hết hạn mức, hệ thống cho phép cả 10 request đi qua.
  + Ngay 1 giây sau, đồng hồ chuyển sang phút tiếp theo (10:01:00): Bộ đếm của hệ thống tự động reset về 0. Người dùng lập tức gửi tiếp 10 request nữa trong giây 10:01:00.
  => Kết quả: Trong khoảng thời gian 2 giây liên tiếp (10:00:59 đến 10:01:00), hệ thống đã tiếp nhận tới 20 request (gấp đôi hạn mức cho phép), có thể làm sập hoặc nghẽn dịch vụ backend. Sliding window (cửa sổ trượt dùng Redis Sorted Set) giải quyết triệt để vấn đề này vì nó luôn tính tổng request trong đúng 60 giây gần nhất tính từ thời điểm hiện tại.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

- Điểm khác nhau cốt lõi:
  + Rate limit bảo vệ **tính sẵn sàng và độ ổn định tức thời** của hạ tầng (tần suất gọi: số request trên một đơn vị thời gian ngắn như giây/phút), ngăn chặn tấn công DoS, brute force hoặc request burst làm quá tải server.
  + Cost guard bảo vệ **ngân sách tài chính dài hạn** (tổng chi phí tích lũy theo tháng/kỳ thanh toán dựa trên lượng tài nguyên tiêu thụ như token LLM, tiền USD), ngăn ngừa thâm hụt tài chính do người dùng gọi vượt quota chi phí.
- Tình huống Rate limit cho qua nhưng Cost guard chặn:
  Người dùng gọi chỉ 1 request duy nhất trong cả giờ (tần suất cực thấp, hoàn toàn thỏa mãn rate limit 10 request/phút), nhưng tài khoản của người dùng này đã tiêu hết ngân sách tháng ($10.00 / $10.00). Cost guard sẽ chặn ngay lập tức và trả về HTTP 402 Payment Required.
- Tình huống Cost guard cho qua nhưng Rate limit chặn:
  Một người dùng mới đăng ký, ngân sách còn nguyên $10.00 chưa tiêu xu nào (chi phí $0). Nhưng người dùng này chạy một script gửi dồn dập 50 request trong 3 giây. Mặc dù chi phí 50 request này chỉ tốn vài cent (rất nhỏ so với ngân sách $10), Rate limit sẽ kích hoạt ngay từ request thứ 11 để bảo vệ server khỏi bị nghẽn và trả về HTTP 429 Too Many Requests.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

Thứ tự sự kiện xảy ra khi gộp kiểm tra Redis vào Liveness Probe (/health):
1. **Giây 0:** Redis gặp sự cố mạng hoặc khởi động lại, mất kết nối trong 30 giây.
2. **Giây 1 - 5:** Bộ điều phối (Kubernetes / Docker Compose orchestrator) định kỳ gửi healthcheck tới `/health` của cả 3 container agent. Do kiểm tra Redis bị lỗi, endpoint `/health` trên cả 3 container đồng loạt trả về HTTP 503 (hoặc timeout/exception).
3. **Giây 5 - 15:** Orchestrator nhận định cả 3 container agent đều đã "chết" (Liveness failed). Nó tiến hành kill (SIGKILL/SIGTERM) và khởi động lại (restart) toàn bộ 3 container cùng lúc.
4. **Giây 15 - 30:** Các container mới được spawn lên, trong quá trình khởi động lại gửi probe tới Redis, Redis vẫn chưa online nên container lại fail healthcheck tiếp. Hệ thống rơi vào vòng lặp restart liên hoàn (CrashLoopBackOff). Toàn bộ CPU và tài nguyên bị tiêu tốn cho việc khởi động lại app.
5. **Hậu quả:** Thay vì chỉ tạm ngưng nhận traffic nhưng vẫn giữ nguyên process và phục vụ được các tác vụ độc lập (hoặc chờ Redis online lại là nhận request ngay), toàn bộ cụm agent bị xóa sổ hoàn toàn, không thể phản hồi bất kỳ request nào (kể cả static hay in-flight requests), gây ra downtime nghiêm trọng (Cascading Failure).
Tách riêng `/ready` (Readiness) chỉ báo cho Load Balancer ngắt traffic tạm thời, còn `/health` (Liveness) vẫn 200 để orchestrator không khởi động lại container vô ích.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

- Khi dùng Redis chung (Stateless container):
  Tất cả 3 container đều đọc/ghi lịch sử hội thoại vào Redis tập trung. Bất kể load balancer phân phối request đến container 1, container 2 hay container 3, `history_length` luôn tăng dần một cách nhất quán và liên tục: 1, 2, 3, 4, 5... cho cùng một `X-User-Id`.
- Nếu lưu trong dict Python (Stateful trong bộ nhớ process):
  Bộ nhớ của 3 container là hoàn toàn cô lập với nhau. Mỗi request đến từ cùng một người dùng sẽ được Load Balancer điều phối round-robin ngẫu nhiên tới 1 trong 3 container.
  + Bạn sẽ thấy `history_length` nhảy nhót bất thường và không nhất quán. Ví dụ: gọi lần 1 vào container A -> length = 1; gọi lần 2 vào container B -> length lại là 1; gọi lần 3 vào container C -> length là 1; gọi lần 4 quay lại container A -> length mới thành 2.
  + Người dùng sẽ thấy AI agent bị "mất trí nhớ", quên ngữ cảnh câu hỏi vừa chat ở request trước nếu request sau rơi vào container khác.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

- **Lỗi gặp phải:** Container bị crash khi khởi động trên Cloud do thiếu biến môi trường cấu hình và sai cổng bind `$PORT`.
- **Thông báo lỗi trong log:**
  ```text
  pydantic_core._pydantic_core.ValidationError: 1 validation error for Settings
  agent_api_key: Field required [type=missing, input_value={}, input_type=dict]
  ```
  và health check báo timeout không nhận được phản hồi trên port mặc định của Cloud platform.
- **Cách tìm ra nguyên nhân:**
  + Mở tab "Logs" trên Web Dashboard của Render/Cloud Provider để đọc output trực tiếp từ Uvicorn và container runtime.
  + Nhận thấy tiến trình Uvicorn chết ngay lập tức ở giai đoạn `lifecycle` khi Pydantic Settings đọc cấu hình và phát hiện `AGENT_API_KEY` chưa được gán trong Environment Variables của service trên dashboard.
  + Đồng thời nhận thấy Cloud provider cấp động một cổng qua biến môi trường `$PORT` (ví dụ 10000 trên Render), trong khi Uvicorn nếu cố định cổng 8000 sẽ không map được với router bên ngoài.
- **Cách sửa:**
  + Vào mục Settings → Environment của Cloud service trên dashboard, thêm đầy đủ các biến môi trường: `AGENT_API_KEY` (khóa bí mật), `REDIS_URL` (kết nối Redis instance nội bộ).
  + Trong Dockerfile và lệnh chạy uvicorn, cấu hình bind vào `0.0.0.0` và cổng động: `--port ${PORT:-8000}`, giúp ứng dụng linh hoạt nhận đúng cổng mà Cloud orchestrator chỉ định. Sau đó kích hoạt deploy lại và service chuyển sang trạng thái "Live" thành công.
