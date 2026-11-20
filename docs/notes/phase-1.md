# Phase 1 — Yêu cầu, giả định và quyết định

Nguồn: [PRD-0 nguyên văn](../spec/PRD-0.txt), Test Contract v1.0 trong cùng tệp.
Người dùng chọn Godot 4 + GDScript, đồng ý triển khai theo hướng dẫn sau khi nhận
đề xuất gameplay, điều khiển và tải Godot portable. Chỉ có PRD-0; chưa có Ticket-02/03/04.

## Tiêu chí nghiệm thu và cách kiểm chứng

| Yêu cầu | Tiêu chí | Kiểm chứng |
|---|---|---|
| Một màn 3D, 5 đèn | Đảo tròn, Mây đội nón lá, camera thứ ba | GUI, ảnh gameplay/menu |
| Đi và nhảy | WASD tương đối camera; Space nâng chân khỏi Y=0 và hạ xuống | Test movement/jump và GUI |
| Gom đom đóm | Trong bán kính XZ, không vượt sức chứa | Test pickup boundary/capacity |
| Nạp đèn | E cạnh đèn nạp tối đa phần còn thiếu; nạp đủ thì sáng | Test partial/nearest/radius/win |
| Bóng Mực | Đuổi, chạm mất máu, sợ vùng đèn đã sáng | Test damage/safety/spawn |
| Tỏa sáng | Q tiêu ánh sáng, đẩy và làm choáng, có cooldown | Test pulse/stun/edge |
| Thắng/thua/điểm | Đủ 5 đèn thắng; hết máu hoặc hết giờ thua | Scenario thắng, thua, lượt chơi default |
| HUD và chơi lại | Hiện máu/đom đóm/giờ/điểm/đèn; retry reset | GUI lifecycle |
| Headless | 60Hz, tick 0, event tick k+1, JSONL có end | Toàn bộ test contract |
| Tất định | Cùng seed/input cho output byte-for-byte giống nhau | SHA256 hai output thực |
| Fixture lỗi | JSON/schema sai trả 2 và stderr | Test malformed fixtures |

## Giả định cho phần PRD để mở

- Toàn bộ tuning ở `game.contract.json` được đọc trực tiếp bởi mô phỏng. Không có
  bộ tuning riêng cho đồ họa. Bán kính đảo 35m, mép chặn; `fall_enabled=false`.
- Người chơi: tốc độ 6m/s, tối đa 30 đom đóm, 3 ngọn lửa. Nhảy vận tốc đầu
  7m/s, trọng lực 20m/s². Nhảy không né sát thương vì khoảng cách contract là XZ.
- Năm đèn đặt trên vòng tròn 23m. Mỗi đèn cần 10 đom đóm. E là cạnh nhấn,
  nạp vào đèn chưa sáng gần nhất trong 3m; bằng khoảng cách chọn theo L1..L5.
- Nhặt tự động trong 1,5m, kể cả khi nhảy. Nhặt trước nạp và pulse cùng tick.
- Bị chạm: mất 1 máu, mất `floor(carried*0.25)` đom đóm; số mất tiêu tán,
  không tạo lại vật phẩm để tránh farm điểm. Miễn sát thương 90 tick.
- Pulse cần 3 đom đóm, bán kính 6m, đẩy 3m, choáng 120 tick, hồi 180 tick.
  Pulse có hiệu lực trước Bóng Mực di chuyển/tấn công. Không đủ đom đóm hoặc
  chưa hồi thì không tiêu tài nguyên, không phát event. Nút giữ không tự lặp.
- Vùng an toàn 5m chỉ có quanh đèn đã sáng. Bóng Mực dừng tại biên vùng;
  scenario đặt Bóng Mực bên trong thì được đưa ra biên ở bước gameplay đầu tiên.
- Đêm 300 giây; `time_left_s` trong scenario thay thời lượng ban đầu.
  Thứ tự kết thúc nếu cùng tick: hết máu, đủ đèn, hết giờ. Không tiếp tục bước sau end.
- 150 đom đóm đầu màn; mỗi 120 tick bù 1 con nếu còn dưới 150. Có 3 Bóng Mực
  đầu màn; mỗi 600 tick sinh 1 con tới tối đa 8. Các cờ random=false tắt tương ứng.
  Các mảng scenario thay danh sách đầu màn; nếu random=true, sinh định kỳ vẫn bật.
- Scenario dựng sẵn không nhặt đồ, không tính điểm, không phát event. `lit=true`
  đặt deposited bằng giá đèn; deposited đủ giá mặc định tự đánh dấu lit.
- Điểm: +10/nhặt; +100/thắp đèn; +20/mỗi Bóng Mực trúng pulse (kể cả đang
  choáng). Thắng thêm `floor(time_left_s)*2 + flames*50`; thua không có thưởng.
- CLI chấp nhận `dash` boolean để đọc fixture, nhưng Phase 1 không có dash.
- Snapshot chỉ ở tick 0 và các bội số snapshot-every; end luôn là dòng cuối,
  kể cả kết thúc giữa hai snapshot. Có mảng motes theo khuyến nghị contract.
- Trang trí không có collider và không đổi kết quả headless. Chuột xoay camera;
  Esc tạm dừng, chỉ ảnh hưởng bản đồ họa; R restart khi kết thúc.

## Kiến trúc

`simulation.gd` là mô hình thuần RefCounted, random riêng có seed, không cửa sổ,
GPU hay physics engine. `headless.gd` kiểm tra fixture và xuất JSONL. `game.gd`
chuyển input trực tiếp vào cùng mô hình ở 60Hz, render mesh và cập nhật HUD.
`minimap.gd` chỉ vẽ trạng thái, không tạo thực thể gameplay. Python chỉ tải/khởi
động Godot và kiểm chứng black-box, không viết lại logic game.

## Thay đổi yêu cầu

Chưa có ticket sau Phase 1. Không suy đoán cơ chế cho phase sau, không tạo tag
phase-2/3/4 hoặc Release v1.0.0 để giả lập việc hoàn tất lab.
