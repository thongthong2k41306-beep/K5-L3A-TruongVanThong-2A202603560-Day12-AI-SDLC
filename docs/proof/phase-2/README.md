# Bằng chứng Phase 2

- [Tiêu chí và phần còn thiếu trong ticket](../../notes/phase-2.md)
- [Báo cáo test contract](test-report.json) và [kiểm tra đơn vị](unit-report.json)
- [Đo headless 21.600 tick](headless-performance.json) và [báo cáo GUI 1280×720](gui-report.json)
- [Đêm 1](gameplay.png), [Đêm 2](night-2.png), [Đêm 3](night-3.png) và [Bình Minh](dawn.png)
- [JSONL thắng một Đêm](win.jsonl), [đo tính tất định](determinism.json) và [replay màn mặc định](autoplay-report.json)

Chạy `python tools/verify.py` và `python tools/manage.py gui-test`. Các ảnh kết quả của chuỗi Đêm dùng fixture để kiểm tra chuyển màn. Số liệu hiệu năng đo trên máy Windows trong điều kiện nêu trong báo cáo.
