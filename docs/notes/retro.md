# Đánh giá Phase 1

- Mô hình chung tránh việc game có đồ họa và headless dùng luật khác nhau.
- Test tick, biên bán kính, nút cạnh nhấn và fixture lỗi giúp contract có thể
  chạy lại; chỉ nhìn game chạy chưa đủ phát hiện các lỗi này.
- Autoplay dùng input thực từ màn mặc định chứng minh đủ đom đóm và có thể
  thắng trong thời gian cho phép, bên cạnh scenario đặt sẵn 4 đèn sáng.
- Test GUI kiểm tra start, pause, resume, win, lose, retry, về menu. Ảnh là
  screenshot engine thực, không phải mockup.
- Chưa thể kết luận qua test ẩn giảng viên; chỉ biết bộ test tự viết đã chạy.
- Bản nguồn có launcher Windows/macOS/Linux; đã xác nhận thực trên Windows.
  CI cấu hình cả 3 OS nhưng chưa có kết quả CI GitHub ở phiên này.
- Chưa có ticket Phase 2–4, tag/push, Release cuối, video MP4, review độc lập
  và số usage token từ tài khoản. Đây là các mục còn lại, không đánh dấu đạt.
- Nếu làm lại: nhận PRD/Test Contract ngay đầu phiên, chốt tuning một lần,
  dành thời gian để người thật chơi thử camera/độ khó và ghi số liệu quota.
