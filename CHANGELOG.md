# Changelog

## Phase 4 · Contract 1.3 · v1.0.0

- Thêm `bench_cmd`, `soak_cmd`, bảng điểm top 10 và lệnh xuất bảng điểm JSON.
- Thêm đổi phím, cảnh báo nhìn được, cỡ chữ từ 18 px, chế độ chữ lớn và giảm chuyển động.
- Thêm bản đóng gói Windows, demo, ảnh toàn cảnh 360° và thiết kế rừng, đèn, Mây, cỏ và đom đóm mới.
- Giữ định dạng đầu vào, trạng thái và sự kiện v1.2 hiện có.

## Phase 3 · Contract 1.2

- Thời lượng ba Đêm đổi thành 240/270/300 giây. Bỏ `all_lit`, thay bằng `dawn_survived` nếu sống và đủ đèn lúc bình minh. Test thắng cũ dùng fixture mới để chạy tới bình minh. Test mới xác minh thắp hết đèn vẫn chưa kết thúc.
- Đèn đang sáng nhận đom đóm để châm dầu, có thể cạn và thắp lại với 5 đom đóm. Test cạnh nhấn chọn lại vị trí để việc châm dầu không cản kiểm tra tương tác với đèn thứ hai.
- Bóng Mực thêm `drain`. Vùng đèn mất an toàn dưới 30 dầu. Test hết choáng kỳ vọng `wander` thay cho `chase`.
- Đổi công thức điểm nạp, thắp lại, Tỏa Sáng và thưởng bình minh. Bỏ thưởng thời gian. Cập nhật test điểm thắng.
- Sức chứa tăng 2 sau mỗi lần thắp đèn thành công, tối đa 20. Fixture mang trên 10 phải khai báo `successful_lights` tương ứng.
- Snapshot có thêm dầu, lịch sử thắp lại và sức chứa. Sự kiện `lantern_lit` thêm `relight`. Sự kiện mới gồm `refuel`, `lantern_out`, `fuel_drain`. Benchmark chạy trọn Đêm 3 với 18.000 tick theo thời lượng mới.

## Phase 2 · Contract 1.1

- Thêm ba Đêm, Lướt, gió, Gió Lạc, Bùa Gió, địa hình và cài đặt có lưu.
- Headless thêm trạng thái tạm dừng, `sim_tick` và các trường cho cơ chế mới.

## Phase 1 · Contract 1.0

- Triển khai màn Đảo Bến, gom đom đóm, thắp đèn, Bóng Mực và Tỏa Sáng.
- Thêm mô phỏng headless 60 Hz, seed tái lập, fixture và test cơ bản.
