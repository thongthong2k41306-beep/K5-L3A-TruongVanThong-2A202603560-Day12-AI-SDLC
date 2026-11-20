# Retro · Đảo Đèn Lồng

## Kết quả qua bốn phase

Phase 1 đặt nền cho việc đổi luật: bản 3D và CLI dùng chung một mô phỏng 60 Hz. Fixture nhỏ tách lỗi nhặt, cạnh nút bấm và thời điểm kết thúc khỏi ảnh hưởng của camera.

Phase 2 thêm bản đồ, Gió Lạc, Bùa Gió và điều khiển. Ticket nhận được thiếu bảng chuẩn nên một số giá trị là giả định tạm, được ghi trong ADR. Bục nhảy và tạm dừng có scenario riêng. Luồng chuyển qua ba Đêm được kiểm tra bằng fixture.

Phase 3 đổi điều kiện thắng. Lưu dầu theo đơn vị 1/60 và xử lý cùng thứ tự trong GUI/CLI giúp kiểm chính xác lúc đèn tắt, nhiều Bóng Mực hút cùng lúc và mất Ngọn Lửa đúng tick bình minh. Test thắng sớm và hết choáng được cập nhật kèm lý do.

Phase 4 thêm phép đo có thể chạy lại. Lần đo thử dưới mục tiêu do cảnh 200 Bóng Mực tạo quá nhiều lần vẽ. Gom các bộ phận tương ứng thành lô mesh rồi đo lại giúp cải thiện số FPS. Soak đo RSS trong một tiến trình. Các lượt test GUI cũng kiểm tra đổi phím, chữ lớn, cài đặt và lưu điểm.

## Cách làm việc với AI

Giữ luật và câu lệnh trong `AGENTS.md`, dùng test trước khi báo kết quả và lưu bằng chứng xuất thẳng từ chương trình giúp tránh nhầm trạng thái. Hook cùng `tools/verify.py` cố định trình tự build → unit → contract. Kiểm tra GUI phát hiện camera Đêm 3 bị tầng trên che, mảng bề mặt Khám phá rừng sai kiểu và kiểm màu chạy trước khung hình kế tiếp. Các lỗi được tái lập trước khi sửa.

Ảnh tham chiếu giúp duyệt hướng mỹ thuật. Vật thể nhiều góc nhìn dùng mesh Godot. Ảnh 360° ImageGen dùng để xem ý tưởng. Tách nghệ thuật khỏi mô phỏng chuẩn giúp thay cỏ, đèn và nhân vật mà vẫn giữ input của các scenario.

Không có thống kê usage hay hóa đơn trong workspace. Ước lượng rất thô cho triển khai và rà soát qua nhiều lượt là 90.000–180.000 token ngữ cảnh và đầu ra. Không có cơ sở quy đổi thành tiền theo gói tài khoản. Tái sử dụng mô phỏng, shader, harness và fixture nhỏ giúp tránh xử lý lặp.

Nếu làm lại, tôi sẽ lấy bảng chuẩn đầy đủ trước khi viết luật, gắn tag ngay khi xong từng phase, chuẩn bị template xuất trước và duy trì một lượt chơi thủ công từ menu tới Bình Minh để đánh giá độ khó. Nên đo cảnh 200 Bóng Mực trước khi thêm các chi tiết tốn lượt vẽ.
