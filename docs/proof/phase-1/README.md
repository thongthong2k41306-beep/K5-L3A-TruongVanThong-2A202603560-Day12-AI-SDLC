# Bằng chứng Phase 1

Các file report/JSONL được chương trình xuất khi chạy test, không viết tay để
đánh dấu đạt. Ảnh do Godot render và chụp viewport trong test GUI. Báo cáo contract
kèm SHA256 source để đối chiếu mã. Chưa có tag/push hoặc kết quả test ẩn.

## Truy vết

| Yêu cầu | Ca kiểm chứng thực | File kết quả |
|---|---|---|
| Mây, nón lá, đảo 3D, 5 đèn, HUD | GUI mở scene thật | `menu.png`, `gameplay.png`, `gui-report.json` |
| Đi theo camera, chuẩn hóa đường chéo | movement/sticky_frames, diagonal/camera | `test-report.json` |
| Nhảy và cạnh nhấn | jump_edges_and_landing, GUI W/Space | `test-report.json`, `gui-report.json` |
| Nhặt, giới hạn sức chứa, khoảng cách XZ | pickup_radius_xz_and_capacity | `test-report.json` |
| Nạp từng phần, đèn gần nhất, biên bán kính | partial_deposit, interact_edge_and_exact_radius | `test-report.json` |
| Đủ 5 đèn thắng, điểm đúng | winning_and_score, full_default_night_replay | `win.jsonl`, `autoplay.jsonl` |
| Bóng Mực đuổi, mất máu, rơi đom đóm, invuln | damage_drop_invulnerability_and_loss | `test-report.json` |
| Tỏa sáng, phí, bán kính, đẩy, choáng, cooldown | pulse_radius/push, stun_expires, pulse_cooldown | `test-report.json` |
| Vùng đèn ngăn đuổi | safe_lantern_stops_chase, unit safe segment | `test-report.json`, `unit-report.json` |
| Hết giờ thua | dawn_loss | `test-report.json` |
| Tạm dừng, thắng/thua, retry/về menu | test_gui.gd | `gui-report.json`, `won.png`, `lost.png` |
| Từ màn mặc định tới thắng không sửa state | bot phát input → replay CLI độc lập | `autoplay-inputs.json`, `autoplay-report.json`, `autoplay.jsonl` |
| 60 tick/giây, snapshot 0, đúng N bước | tick_zero_and_exact_steps | `test-report.json` |
| Seed, IDs, output tất định | seeded_default_generation_is_deterministic | `determinism.json` |
| Cờ random=false, spawn, ID không trùng | false_random_flags/supplied_ids, random_spawn | `test-report.json` |
| Fixture sai trả 2, stderr | malformed_fixtures, bad_cli | `test-report.json` |
| Khởi động không có cache dự án | Sao nguồn sang thư mục sạch, chạy CLI thắng và mở main scene headless | `clean-check.json` |

## Chạy lại

```sh
python3 tools/manage.py test
python3 tools/manage.py gui-test
```

Windows: dùng `python`. Trên Linux không có màn hình, GUI test có thể chạy bằng
`xvfb-run -a python3 tools/manage.py gui-test`; headless không cần Xvfb.

`test` tự chạy unit, tạo input autoplay từ seed 2026, replay qua CLI và kiểm tra
điểm/thời điểm kết thúc khớp nhau. `test-report.json` ghi số lượng test và hash
source thực tại lần chạy. Thay đổi source cần chạy lại bằng chứng.

Ảnh thắng dựng scenario công khai `tests/scenarios/deposit_win.json`; ảnh thua
dựng 1 máu và Bóng Mực ở gốc. Đây là scenario kiểm chứng, không mô tả như ảnh
chơi thắng tự nhiên. Lượt chơi màn mặc định có bằng chứng input/output riêng.

## Chưa kiểm chứng / chưa bàn giao

- Test ẩn của giảng viên; macOS/Linux trên máy thật (CI mới được cấu hình).
- Hiệu năng theo ticket sau: chưa có ngưỡng để đo/đánh giá đạt.
- Review của người/agent độc lập; video `.mp4`; tag/push và Release.
- Phases 2–4 chưa có ticket. Không sử dụng report Phase 1 để thay thế chúng.
