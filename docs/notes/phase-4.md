# Phase 4 · Điều kiện phát hành

| Yêu cầu | Thực hiện và kiểm chứng |
|---|---|
| Đo đồ họa | `bench` dựng Đêm 1 ở 1280×720 với 200 Bóng Mực `wander`, 100 đom đóm và ba đèn đầy dầu. Camera quay 15 giây/vòng. Tắt VSync; đo 30 giây sau 3 giây khởi động. |
| Đo chạy lâu | `soak` xoay ba Đêm trong một tiến trình. Đọc RSS sau lúc dựng Đêm đầu và sau lúc giải phóng mô phỏng cuối. |
| Xếp hạng | Lưu top 10 ở `user://leaderboard.json`. Cùng điểm, lượt trước đứng trên. `play --export-leaderboard` xuất theo thứ tự. |
| Trợ năng | Đổi và khôi phục phím, báo trùng phím, chữ lớn, giảm chuyển động, báo Bóng Mực với mũi tên, gió, đếm ngược và đèn yếu. |
| Bản cài | `package` kiểm SHA512 template Godot 4.5.1 rồi xuất EXE có PCK nhúng và ZIP Windows x64. |
| Đồ họa | Mesh 3D được dựng từ các đặc trưng ảnh tham chiếu. Đom đóm bay quanh điểm nhặt. Ảnh panorama 2:1 là bản ý tưởng do ImageGen tạo. |

`load_ms` tính từ ngay trước khi chạy Godot đến khung đầu render xong. `frame_ms_p95` dùng thứ hạng `ceil(0.95 × N)`. RSS được lấy mẫu ngoài tiến trình bằng API Windows, `/proc` trên Linux hoặc `ps` trên macOS. Số MB trong báo cáo dùng đơn vị MiB.

Báo cáo địa phương đo trên Windows với Intel Iris Xe. Kết quả máy chấm và bộ test ẩn chưa có trong workspace. Xem [bằng chứng sinh từ các lần chạy](../proof/phase-4/README.md).
