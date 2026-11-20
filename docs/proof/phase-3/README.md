# Bằng chứng Phase 3

- [Test Contract](test-report.json), [test đơn vị](unit-report.json) và [test giao diện](gui-report.json).
- [Hai Bóng Mực hút dầu](drain.jsonl), [điểm và kết quả bình minh](win.jsonl).
- [Rừng Đảo Bến](gameplay.png), [đèn yếu và đèn tắt](fuel.png), [bảng màu dễ phân biệt](accessible.png), [Khám phá rừng](exploration.png).
- [Hiệu năng headless](headless-performance.json) và [kết quả tất định](determinism.json).

Tái lập bằng `python tools/verify.py` và `python tools/manage.py gui-test` trên Windows. Các ảnh kiểm chứng lượng dầu và chuyển Đêm dùng fixture công khai từ test GUI. Xem [ADR và tiêu chí](../../notes/phase-3.md).
