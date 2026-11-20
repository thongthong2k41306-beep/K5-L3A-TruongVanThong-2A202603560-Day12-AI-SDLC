# Nhật ký phối hợp AI

## Phase 1

- Công cụ: Codex; Godot 4.5.1; GDScript; Python standard library.
- Người dùng yêu cầu đọc lab, code game đúng yêu cầu, hỏi ý kiến khi có lựa chọn.
  Người dùng chọn Godot/GDScript và sau đó cho phép làm theo hướng dẫn trên bộ
  gameplay đã đề xuất. PRD-0 được gửi bằng attachment.
- AI xây mô hình chung GUI/headless trước, rồi validator/CLI, scene procedural,
  test black-box, test đơn vị và GUI lifecycle. Người dùng cần review trải nghiệm
  và giải thích được phần nộp.
- Bằng chứng: kết quả thực trong `docs/proof/phase-1/`; fixture/process log đầy đủ
  ở `.tools/test-runs/` tại máy chạy. Không sửa JSONL thủ công để làm test đạt.
- Lỗi AI gặp: dùng `:=` cho biến boolean suy từ model động trong script autoplay;
  Godot báo không suy được kiểu. Đổi sang `var interact: bool`, chạy lại thành công.
  Biện pháp: gate chạy script thực và quét SCRIPT ERROR, không chỉ tin exit 0.
- Môi trường: lần chạy đầu định ghi cache vào AppData ngoài workspace. Launcher
  được sửa để đặt cache/userdata vào `.tools/` và bật portable editor. Sandbox
  Windows báo không đọc được root certificate store; gameplay offline và test
  vẫn chạy. Engine tải từ bản phát hành chính thức.
- Tiết kiệm ngữ cảnh: một nguồn tuning, một mô phỏng chung, không thêm framework,
  mesh thủ tục thay asset tải ngoài, test đơn vị gọn và CLI scenario tái lập.
- Token/chi phí Phase 1: **chưa có số liệu đo được** trong công cụ phiên này.
  Không ghi con số giả. Học viên cần điền ước tính từ usage/billing tài khoản
  (ghi rõ là ước tính) trước khi nộp. Phiên này không cung cấp billing API.
- Reviewer độc lập: **chưa có**. Test và kiểm tra ảnh do cùng agent tạo code
  thực hiện; cần người dùng review để đáp ứng tối đa tiêu chí reviewer riêng.

## Phase 2

- Người dùng cung cấp Ticket-02 và yêu cầu nâng nhẹ đồ họa. Bản gửi thiếu bảng
  số liệu chuẩn Phần 1 và mã RGB; giá trị tạm được liệt kê trong [spec](phase-2.md).
- Codex dùng chung bản đồ và mô phỏng cho GUI và headless. Thêm scenario cho
  ba Đêm, bục nhảy, tạm dừng, Lướt, Bùa Gió, Gió Lạc và gió mạnh.
- Rà ảnh Đêm 3 phát hiện camera nhìn từ trên tầng 2 che mất Mây lúc xuất phát.
  Hạ camera dưới tầng khi Mây đi bên dưới. Test hồi quy pulse ban đầu dựa vào
  thứ tự mảng Bóng Mực, sau đó sửa để tìm đúng ID theo kết quả thật.
- Gộp bản vẽ cỏ và giảm tầm bóng đổ. Đo hiệu năng GUI với VSync tắt để tránh
  phụ thuộc mức làm mới của môi trường chạy.
- Chưa có số đo token, chi phí hoặc kết quả review độc lập.

## Phase 3

- Ticket-03 đổi vòng chơi sang giữ sáng đến bình minh. Dầu dùng số nguyên theo tick, chung cho UI và CLI.
- Thêm rừng, mái đình, đá phủ rêu và mẫu nhân vật Mây, cùng chế độ Khám phá rừng có bố trí đèn theo seed riêng. Các tọa độ chuẩn vẫn dùng trong chiến dịch và bộ chấm.
- GUI test phát hiện mảng mặt đất của Khám phá rừng chưa dùng kiểu `Array[float]`. Sửa bằng mảng có kiểu tường minh, kiểm tra lại khi mở chế độ từ menu và khi quay về chiến dịch.
- Test cài đặt màu đợi khung hình render hoàn tất trước khi đọc màu và biểu tượng. Dùng đường dẫn tệp riêng cho test để không ghi vào cài đặt của người chơi.
- Chưa có số đo token hoặc review độc lập.

## Phase 4

Chưa nhận ticket, chưa thực hiện.
