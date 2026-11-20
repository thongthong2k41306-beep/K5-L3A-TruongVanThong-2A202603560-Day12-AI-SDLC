# Quyết định thiết kế Phase 3

## ADR: Đèn cạn dầu và kết quả lúc bình minh

- Bản chơi và CLI dùng cùng mô phỏng. Mỗi đèn lưu lượng dầu nguyên theo đơn vị 1/60, dấu đã từng sáng và số lần thắp lại. Chỉ làm tròn tới 0,1 khi xuất dữ liệu. Điểm bình minh dùng phần nguyên của lượng dầu thực.
- Mỗi bước gameplay trừ hao dầu và cộng dồn lượng hút trước khi xử lý di chuyển, nạp đèn và Tỏa Sáng. Tắt đèn ngay khi hết dầu, trả tiến độ nạp về 0. Đèn từng sáng chỉ cần 5 đom đóm ở lần kế tiếp. Mỗi Bóng Mực phát sự kiện sau 60 tick hút liên tục.
- Bóng Mực lang thang ưu tiên đèn yếu gần nhất. Bóng đang đuổi Mây giữ mục tiêu. Bóng đang hút bỏ đèn để đuổi Mây trong 6 m. Vùng an toàn có hiệu lực từ 30 dầu trở lên. Khi vùng an toàn vừa bật, Bóng Mực trong 6 m được đẩy ra biên trong 30 tick và không gây sát thương trong lúc bị đẩy.
- Thắp đủ đèn sớm vẫn tiếp tục chơi. Tại tick hết giờ, hết Ngọn Lửa là thua trước. Nếu còn sống, xét số đèn sau toàn bộ cập nhật của tick cuối. Đèn đặt sẵn trong scenario không cộng điểm thắp hay sức chứa.
- Cảnh rừng, mái đình, đá phủ rêu và nhân vật được tạo bằng mesh và shader gốc trong dự án. Chế độ Khám phá rừng có bán kính 60 m, đèn rải ngẫu nhiên theo seed của chuyến chơi. Chiến dịch và CLI dùng bản đồ chuẩn và không kích hoạt chế độ này.

## Kiểm chứng

| Yêu cầu | Bằng chứng |
|---|---|
| Hao dầu, tắt, thắp lại và sức chứa | `test_phase3_decay_extinguish_relight_and_capacity` |
| Châm dầu, chọn đèn, làm tròn và đẩy Bóng Mực | `test_phase3_refuel_rounding_tie_and_repulsion` và test đơn vị đèn đầy |
| Hút cộng dồn, chọn đèn yếu, thưởng Tỏa Sáng | `test_phase3_drain_sums_and_pulse_bonus` và `test_phase3_wander_targets_weak_lamp_but_chase_does_not` |
| Ngưỡng từng Đêm, không thắng sớm, ưu tiên hết Ngọn Lửa | `test_phase3_last_tick_threshold_and_no_early_win` |
| Cài đặt màu lưu được, thanh dầu, đèn xẹp, vết rách | GUI test và ảnh đèn yếu, đèn tắt |
| Đảo rộng, vị trí đèn đổi và trở về tọa độ chuẩn | GUI test Khám phá rừng |
| Hồi quy | Chạy lại test Phase 1–2 với kỳ vọng thay đổi ghi trong changelog |

Xem [báo cáo Phase 3](../proof/phase-3/README.md). Xác minh chuỗi thắng bằng fixture, chưa chạy test ẩn của giảng viên. Thông số Phase 2 chưa có bảng chuẩn tiếp tục dùng giá trị tạm ở các luật Ticket-03 không thay thế.
