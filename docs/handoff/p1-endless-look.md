# P1 — Diện mạo bản đồ Vô Tận (nhánh `feature/p1-endless-look`)

Chỉ hình ảnh + sửa cửa sổ đường đi cũ khi đổi tầng. Không đổi bố cục (`Maps.endless` giữ nguyên), không thêm menu/F4.

## File
- `scripts/endless_look.gd` (MỚI): 5 tông mặt tiền (bản sao vật liệu "wall"), 7 lớp MultiMesh (viền nóc, dải theo tầng lầu, vòng đỉnh cột, 3 ăng-ten mốc, vạch đứt phố, khung xuất phát xanh lam, khung cổng ra xanh lá). Mọi số ở `LOOK`.
- `scripts/arena.gd`: gọi `EndlessLook` chỉ khi map `endless`; `_box` trả body; `load_floor` tắt vùng nav cũ ngay; `nav_ready()` (Vô Tận: đường spawn→cổng phải thật sự tới cổng) và `nav_path` trả rỗng khi chưa sẵn sàng.
- `scripts/portal.gd`: khoá = vòng + cột đỏ mờ; mở = cột to/cao hơn, đèn, nhịp thở (tắt khi `reduced_fx`). API không đổi.
- `tools/tests/test_p1.gd`, `tools/screenshots/shoot_p1.gd`, `docs/screenshots/p1/`.

## Số đo
- Navmesh mới được máy chủ gộp sau 0–17 khung (M34 ghi ~10; đo thực tầng 3 là 17). Trong lúc chờ, bot dùng đường thẳng.
- Trang trí: 7 draw call, ~650 thể hiện (tầng 2).

## Chưa kiểm bởi người
Không có GPU thật: cảm giác ánh sáng/độ rõ cần mắt người. Chỉnh bằng `LOOK` ở `endless_look.gd` / `portal.gd`.
## Tránh xung đột
Chat M35–M39 nên tránh `maps.gd`, `arena.gd`, `materials.gd`, `portal.gd`.
