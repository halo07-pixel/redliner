# Bàn giao Redliner (cập nhật 2026-11-14)

## Trạng thái
- `main` = `374d029` (5 mốc đầu + M6.1 đã gộp). Nhánh chờ duyệt: `feature/m6-2-materials-palette` (M6.2).
- Lộ trình: xem `docs/ROADMAP.md`. Quyết định: Forward+, Instability "Destabilized" (M8), làm cả M9 và M10.

## M6.1 (nhánh này)
- `project.godot`: `forward_plus` (mobile: `mobile`). Máy cần Vulkan; nếu không chạy được thì đề xuất đổi sang Mobile/Compatibility, không tự đổi.
- `Global.ENV`: mọi tham số ánh sáng/sky/fog/tonemap/glow. `arena.gd::_build_environment` chỉ đọc từ đó (mặt trời + 4 cascade bóng, sky procedural, fog, Filmic, glow, ambient).
- Giới hạn: môi trường chụp ảnh cloud (Xvfb) không có Vulkan nên ảnh `docs/screenshots/m6_1_*` là renderer GL dự phòng, KHÔNG phải Forward+ thật; cần người chơi xem trên máy thật.

## M6.2 (nhánh này)
- `Global.PALETTE` (màu theo vai trò) và `Global.MATERIAL_PARAMS` (metallic/roughness/emission/tile) là nguồn duy nhất cho màu đấu trường.
- `scripts/materials.gd`: `make(role)` trả `StandardMaterial3D` có cache, họa tiết lưới sinh bằng code, triplanar theo thế giới. `arena.gd::_box()` nhận vai trò (chuỗi) thay vì màu; `_build_trim()` thêm vạch sáng chân tường (không va chạm, không đổ bóng).
- Test mới: `tools/tests/test_materials.gd`. Ảnh: `docs/screenshots/m6_2_*` (vẫn là renderer GL dự phòng).

## Quy trình (từ instruction Project)
Đề xuất → chờ duyệt → nhánh feature + push → chờ "Duyệt" → merge `--no-ff` vào main. Không push `main`. Commit conventional, có trailer Co-Authored-By và Claude-Session.

## Test / công cụ
- `godot --headless --path . --import` rồi `godot --headless --path . -s tools/tests/<tên>.gd` (6 bộ: test_movement, test_advanced_movement, test_combat, test_bots, test_menu_instability, test_materials; đều xanh).
- Ảnh: `xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s tools/screenshots/shoot*.gd -- <thư mục>`.
- Pitfall test `-s`: không `preload` script dùng Global ở đầu file; chờ 2 frame sau teleport; `await process_frame` đầu `_run()`.

## Việc kế tiếp
M6.3 (tùy chọn chất lượng) → M7… Mỗi việc phải đề xuất + chờ duyệt.
