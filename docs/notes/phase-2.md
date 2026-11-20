# Phase 2 — Tiêu chí và giả định

Nguồn: [Ticket-02](../spec/Ticket-02.txt). Các bản nhận được thiếu bảng số liệu chuẩn Phần 1 và danh sách màu RGB.

| Tính năng | Tiêu chí nghiệm thu | Kiểm chứng |
|---|---|---|
| Ba bản đồ | 5/6/7 đèn đúng tọa độ, cầu tre, tầng và dốc; bục phóng tới đảo hoặc tầng đích | Scenario ba Đêm, ảnh Đêm 2/3 |
| Gió Lạc | Sinh tick 1200, đuổi nếu mang đủ và ở trong tầm, cướp trước Bóng Mực; Tỏa Sáng buộc thả đồ | Scenario cướp, thả đồ và lịch sinh |
| Bùa Gió | Hiệu lực 600 tick, chạy 7,2 m/s, Lướt 14 m/s trong 12 tick, không hồi chiêu khi có bùa; bùa hồi sau 2700 tick | Scenario bùa, lướt, thời hạn và bộ đếm hồi |
| Chuỗi Đêm | Giới thiệu có lời Ông Đăng, thắng mở Đêm sau, thắng Đêm 3 hiện tổng điểm Bình Minh, thua có chơi lại | Test GUI với fixture |
| Tạm dừng | Esc/P mở menu; đồng hồ gameplay đứng yên, headless tiếp tục đếm tick | Scenario pause và test GUI |
| Cài đặt | Âm lượng và độ nhạy chuột được ghi vào `user://settings.cfg` | Kiểm tra mã; chưa chạy lại trong phiên thứ hai |
| Âm thanh | Nhạc đêm và hiệu ứng theo sự kiện, báo gió trước 2 giây | Tổng hợp và phát từ trạng thái game; chưa đánh giá nghe độc lập |
| HUD | Thời gian đỏ và nhấp nháy từ 30 giây; máu, đèn, điểm, 10 ô đom đóm, hồi chiêu, nhắc E và mũi tên ngoài màn hình | Ảnh và GUI |
| Màu và ánh sáng | Môi trường = `0.15 + 0.55 × tỷ lệ đèn sáng`; màu chờ đối chiếu mã RGB | Ảnh màn chơi |
| Tất định | Cùng seed/input ghi output giống nhau, pause không tăng sim_tick | SHA256, replay và pause |
| Hiệu năng | Headless chạy 21.600 bước trong 30 giây; bản 1280×720 đạt trung bình 30 FPS | Báo cáo headless và GUI |

## Thông số tạm

- Các giá trị ghi rõ trong Ticket-02 được áp dụng. Tốc độ thường, máu, bán kính và chi phí tương tác giữ giá trị Phase 1 trong lúc chờ bảng chuẩn. Sức chứa 10 theo HUD. Thời lượng tạm 300/330/360 giây, hồi Lướt thường 2 giây.
- Nhảy dùng vận tốc 7 m/s và trọng lực 20 m/s². Khi rơi dưới −5 m, Mây mất 1 Ngọn Lửa và số đom đóm đang mang, rồi về tâm đảo. Đom đóm rơi có TTL tạm 600 tick. Đom đóm sinh ở điểm hợp lệ còn trống mỗi 120 tick.
- Tạm dùng 30 tick spawning, khoảng phát hiện 18 m khi wander và recoil 20 tick. Tên trạng thái theo v1.1.
- Tạm giữ đo tương tác XZ từ Phase 1. Góc có Z dương cho các điểm tầng 1 và dốc Đêm 3 để nằm đúng nửa đảo trong mô tả.
- Cập nhật test Phase 1 cho phần luật bị thay: điểm nạp, lịch sinh, sức chứa và hành vi rơi. Replay kiểm tra cùng input cho cùng kết quả. Input của bot hiện có thể thua, nên chuỗi thắng qua ba Đêm chỉ được xác minh qua fixture.
- Chưa xác nhận bộ test ẩn hoặc đủ mã RGB. Chưa gắn tag hay push.
