# Nguồn và giấy phép

- Đảo Đèn Lồng, Mây, Bóng Mực, bối cảnh: đề lab Day 12 do người dùng cung cấp.
  Quyền đối với nội dung đề bài thuộc chủ sở hữu tương ứng.
- Mã GDScript/Python, mesh nhân vật/nón lá/đèn/cây/đảo, HUD, minimap: tạo trực tiếp
  bằng code với sự hỗ trợ của OpenAI Codex trong phiên làm bài.
- Bầu trời, bề mặt rêu và quầng sáng trong bản nâng đồ họa được tạo bằng shader
  viết trong dự án với sự hỗ trợ của OpenAI Codex.
- Không dùng model, texture, nhạc, thương hiệu hoặc nhân vật từ game/phim khác.
- Nhạc đêm và hiệu ứng Phase 2 được tổng hợp bằng mã GDScript trong `src/night_audio.gd`, với sự hỗ trợ của OpenAI Codex.
- Godot Engine 4.5.1: [Godot](https://godotengine.org/), MIT;
  [license và third-party notices](https://godotengine.org/license/).
  Engine tải vào `.tools/`, không đưa binary vào git.
- Font: mặc định và fallback do Godot/hệ điều hành cung cấp; không phân phối
  thêm font ngoài. Xem notices của Godot khi đóng gói engine.
- Python: chỉ dùng thư viện chuẩn, không thêm package runtime.

Mã triển khai dùng giấy phép MIT trong `LICENSE`. Giấy phép không chuyển quyền
đối với tài liệu/nhân vật do bên ra đề cung cấp hay thành phần bên thứ ba.

Cảnh rừng, mái đình, đá phủ rêu, mẫu Mây và shader thanh dầu Phase 3 được dựng
bằng mã trong dự án với sự hỗ trợ của OpenAI Codex. Cảnh rừng lấy cảm hứng
từ không khí rừng giả tưởng của Genshin Impact và dùng hình khối tự dựng.

Phase 4 dùng các ảnh tham chiếu do người dùng gửi để định hướng thảm cỏ, cây cổ
thụ, đèn mái gỗ / mái đồng / hoa sen và trang phục xanh bạc. Tất cả mesh trong
game dựng bằng GDScript và shader với Codex. Ảnh ý tưởng 360° trong `docs/art/`
được tạo bằng OpenAI ImageGen từ các ảnh tham chiếu. Video demo là bản ghi
trực tiếp từ Godot, mã hóa bằng FFmpeg.

Các chất liệu trong `src/art/` được tạo bằng ImageGen tích hợp. Prompt cho bộ chất liệu yêu cầu bốn bề mặt nhìn trực diện gồm thảm cỏ xen cỏ ba lá, vỏ cây cổ thụ, đá xám có địa y và gỗ nâu đỏ. Prompt cho ảnh toàn cảnh yêu cầu rặng núi rừng trùng điệp trong sương dưới trời chạng vạng, chiếu cầu 360°. Ngói, diềm chạm, bông cỏ và khung đèn là hình học 3D dựng trong Godot.
