Loại: Feature + chuẩn hóa · Ưu tiên: Cao · Tag nộp: phase-2 · Contract: v1.1
Đêm 1 đã chạy được. Nhà sản xuất chơi thử bản của các bạn và thấy mỗi bản cho cảm giác điều khiển rất khác nhau. Ticket này có hai việc: (1) đồng bộ số liệu chuẩn để mọi bản cho cảm giác giống nhau, và (2) mở rộng game thành 3 Đêm cùng các tính năng mới.
Về sáng tạo: những gì bạn đã sáng tạo thêm ở Phase 1 vẫn được giữ và bạn vẫn được thêm ý riêng, kể cả nhân vật mới và kẻ địch mới (ngoài Bóng Mực và Gió Lạc), miễn là số liệu chuẩn, bản đồ chuẩn và Test Contract dưới đây không bị đổi và phần thêm không làm đổi đầu ra headless (ví dụ tắt khi chạy headless).
Logic chạy 60 tick/giây. Đơn vị: mét, giây. Trục Y hướng lên.
Điểm (chuẩn hóa): +10 mỗi đom đóm nạp · +100 mỗi đèn thắp · +5 mỗi Bóng Mực trúng Tỏa Sáng (mỗi con mỗi lần, kể cả con đang choáng) · khi thắng: + floor(giây còn lại) × 2 + 50 × Ngọn Lửa còn lại. Tổng điểm game là tổng điểm các Đêm đã thắng.
1. Đọc input (xử lý pause trước; nếu vừa tạm dừng thì dừng bước ở đây).
2. Giảm các bộ đếm: thời gian, hồi chiêu, bất tử, choáng, bùa, TTL đom đóm rơi, hồi bùa.
3. Di chuyển Mây (nhảy, lướt, bục nhảy, gió) rồi kiểm tra rơi khỏi đảo.
4. Nhặt đom đóm và bùa.
5. Tương tác với đèn.
6. Cập nhật vùng an toàn.
7. Tỏa Sáng.
8. Di chuyển Bóng Mực và Gió Lạc.
9. Chạm: Gió Lạc cướp trước, rồi Bóng Mực gây hit (xét theo id tăng dần).
10. Sinh đom đóm, Bóng Mực, Gió Lạc theo lịch (thực thể mới chỉ tương tác được từ tick sau).
11. Xét thắng/thua.
12. Ghi snapshot nếu tới lượt.
Khi đang tạm dừng: tick vẫn tăng nhưng sim_tick, thời gian, hồi chiêu, spawn, TTL đều đứng yên; snapshot ghi state: "paused".
Góc đo từ trục +X, ngược chiều kim đồng hồ khi nhìn từ trên xuống, trên mặt phẳng XZ.
- Đảo tròn tâm (0,0,0), bán kính 40 m. Ngoài 40 m là biển mây (rơi).
- Xuất phát (0,0,0), quay mặt về +Z.
- Đèn: L1 (0,0,25) · L2 (23.8,0,7.7) · L3 (14.7,0,−20.2) · L4 (−14.7,0,−20.2) · L5 (−23.8,0,7.7).
- Điểm sinh đom đóm: 8 điểm trên bán kính 12 m (mỗi 45°) và 16 điểm trên bán kính 33 m (mỗi 22.5°).
- Bóng Mực sinh trên 12 điểm bán kính 37 m (15°, 45°, …), cách người chơi ≥ 15 m; 2 con lúc giây thứ 5, sau đó mỗi 8 s; tối đa 6.
- Hai đảo tròn bán kính 28 m, tâm A (0,0,0) và B (70,0,0), nối bằng cầu tre x ∈ [26, 44], z ∈ [−2, 2], không lan can.
- Bục nhảy hình tròn bán kính 1 m tại (20,0,18) và (50,0,−18): chân Mây chạm bục thì được bắn lên với vận tốc Y 14 m/s và vận tốc ngang 24 m/s hướng về tâm đảo kia. Vận tốc phóng giữ nguyên tới khi chạm đất (phím di chuyển không ghi đè; vẫn được lướt). Bay khoảng 1.4 s, đáp trong đảo đích.
- Điểm sinh đom đóm mỗi đảo: 4 điểm trên bán kính 10 m (0°, 90°, 180°, 270°) và 8 điểm trên bán kính 22 m (mỗi 45°). Bóng Mực sinh trên 8 điểm bán kính 26 m mỗi đảo (22.5°, 67.5°, …).
- Đèn: (0,0,20), (17,0,−10), (−17,0,−10), (70,0,20), (87,0,−10), (53,0,−10), id L1…L6 theo thứ tự này.
- Bóng Mực: sinh mỗi 7 s, tối đa 8.
- Đảo tròn bán kính 45 m, có 3 tầng: tầng 0 (Y=0) toàn đảo; tầng 1 (Y=3) là vành khăn bán kính 12–24 m ở nửa có z > 0; tầng 2 (Y=6) là đĩa bán kính 8 m ở tâm.
- Mép các tầng là vách đứng (không đi lên được; bước ra thì rơi xuống tầng dưới).
- 2 dốc thẳng rộng 3 m dọc theo bán kính ở góc 30° và 150°: chân dốc ở bán kính 30 m (Y=0), đỉnh dốc ở bán kính 24 m (Y=3).
- Bục nhảy bán kính 1 m tại (0,3,13): vận tốc Y 12 m/s và vận tốc ngang 8 m/s hướng −Z, giữ tới khi chạm đất → đáp lên tầng 2.
- Tháp chuông cao 8 m ở tâm tầng 2, hình trụ bán kính 2 m, không leo được.
- Điểm sinh đom đóm (30): tầng 0 có 18 điểm bán kính 34 m (mỗi 20° từ 0°); tầng 1 có 8 điểm bán kính 18 m (20°, 40°, …, 160°); tầng 2 có 4 điểm bán kính 5 m (45°, 135°, 225°, 315°). Bóng Mực sinh trên 16 điểm bán kính 43 m (mỗi 22.5°).
- Đèn (L1…L7): (0,6,6), (18,3,10), (−18,3,10), (35,0,−10), (−35,0,−10), (20,0,−35), (−20,0,−35).
- Gió mạnh: mỗi 30 s có một cơn gió kéo dài 5 s theo hướng ngẫu nhiên, đẩy người chơi 2 m/s; báo trước 2 s bằng lá bay và âm thanh.
- Bóng Mực: sinh mỗi 6 s, tối đa 10.
1. Gió Lạc (Đêm 2 và 3): dải lụa xám xanh bay nhanh (7 m/s), tối đa 2 con, sinh tại tick 1200, 2400, … trên điểm sương ngẫu nhiên, id D1, D2, …
   - Trạng thái: idle (lượn chậm 2 m/s) → chase → flee → removed.
   - idle → chase khi Mây mang ≥ 5 đom đóm và cách ≤ 15 m (kiểm tra mỗi tick); điều kiện mất thì về idle.
   - Chạm (XZ ≤ 1.2 m): cướp min(3, đang mang) đom đóm, chuyển flee (bay ra xa Mây 7 m/s trong 240 tick rồi biến mất cùng số đã cướp). Mỗi con chỉ cướp 1 lần.
   - Tỏa Sáng trúng Gió Lạc đang chase → nó chuyển flee không cướp; trúng lúc flee có mang đồ → thả lại toàn bộ đom đóm đã cướp tại chỗ (thành đom đóm rơi), biến mất sau 120 tick.
   - Không làm mất Ngọn Lửa; vùng an toàn của đèn không chặn Gió Lạc; bất tử của Mây không ngăn bị cướp.
2. Bùa Gió: lá bùa đỏ viền vàng, id C1, C2. Nhặt theo luật như đom đóm. Hiệu lực 600 tick (nhặt lại thì làm mới): tốc độ chạy 7.2 m/s và Lướt không hồi chiêu (vẫn cần nhấn lại nút; nhấn khi đang lướt bị bỏ qua; lướt vẫn 14 m/s trong 12 tick). Bùa xuất hiện lại sau 2700 tick. Vị trí: Đêm 2 (35,0,0); Đêm 3 (30,0,25) và (−30,0,25).
3. Chuỗi 3 Đêm: Menu chính → giới thiệu Đêm (tên đảo, lời Ông Đăng) → chơi → kết quả → Đêm kế tiếp. Thắng Đêm 3 thì hiện màn hình Bình Minh với tổng điểm. Thua thì được chơi lại Đêm đó.
4. Tạm dừng (Esc/P): logic dừng hoàn toàn. Có Tiếp tục / Chơi lại Đêm / Cài đặt / Về menu.
5. Cài đặt: âm lượng và độ nhạy chuột, được lưu giữa các lần mở game.
6. Âm thanh: nhạc nền đêm và hiệu ứng cho: nhặt, thắp đèn, tỏa sáng, bị đánh, nhảy, lướt, thắng, thua, Bóng Mực xuất hiện, đếm ngược 10 s cuối.
7. HUD đầy đủ: Ngọn Lửa (trên trái), đồng hồ mm:ss (trên giữa, đổi màu đỏ và nhấp nháy khi ≤ 30 s), đèn k/n và điểm (trên phải), thanh đom đóm 10 ô (dưới giữa), biểu tượng hồi chiêu Lướt và Tỏa Sáng (dưới phải), nhắc "E — Nạp ánh sáng (x/10)" khi đứng gần đèn, mũi tên chỉ tới đèn chưa sáng gần nhất khi nó ở ngoài màn hình.
8. Bảng màu chuẩn (sai lệch tối đa 10% mỗi kênh RGB; áp dụng cho các thành phần liệt kê, màu cho chi tiết khác do bạn tự chọn):
Ánh sáng môi trường tăng theo tiến độ: cường độ = 0.15 + 0.55 × (đèn sáng / tổng đèn).
- contract_version: "1.1"; tuning phải khớp số chuẩn ở Phần 1, thêm các khóa dash_speed, dash_duration_s, dash_cooldown_s, night2_duration_s, night3_duration_s.
- --night nhận 1, 2, 3.
- Snapshot gốc thêm night, wind {active, dir_deg}. player thêm vel, grounded, invuln, dash_cd_s, pulse_cd_s, charm_s.
- Snapshot thêm các mảng bắt buộc: motes (id, pos, kind = random/dropped, ttl_s), drifters (id, pos, state, stolen), charms (id, available, respawn_s).
- Scenario thêm player.{invuln_ticks, dash_cd_ticks, pulse_cd_ticks, charm_ticks}, shades[].{state, state_ticks_left}, drifters, charms, cờ random_drifters, wind_enabled. Các mảng drifters, charms thay thế danh sách mặc định.
- Input thêm dash và pause (đều kích hoạt khi chuyển false → true).
- Sự kiện mới: dash {}, charm_picked {charm_id, charm_ticks}, drifter_steal {drifter_id, amount, carried}, drifter_drop {drifter_id, amount}, night_start {night}, paused {}, resumed {}. player_hit do rơi thêm trường lost.
- Từ v1.1, trạng thái Bóng Mực phải dùng đúng tên: spawning, wander, chase, recoil, stunned.
- Chạy headless một Đêm đầy đủ (tối đa 21.600 tick) phải xong trong ≤ 30 giây.
- Có bằng chứng game chạy đúng các yêu cầu của phase (định dạng tự chọn).
- Mọi test ẩn Phase 1 vẫn đạt khi chạy với số chuẩn (regression).
- Tài liệu spec của bạn (tên và vị trí tự chọn) có acceptance criteria cho từng mục ở Phần 3.
- File hướng dẫn agent (AGENTS.md hoặc tương đương) và các skill được cập nhật cho phạm vi mới (lịch sử git phải thể hiện).
- Test của bạn có ít nhất 1 scenario headless cho mỗi tính năng mới.
- Bản thường đạt ≥ 30 FPS trung bình ở 1280×720.