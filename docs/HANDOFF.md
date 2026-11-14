# Bàn giao Redliner (cập nhật 2026-11-14)

## Trạng thái
- `main` = `71fbfc1` (5 mốc ban đầu xong). Nhánh chờ duyệt: `feature/m6-1-environment-forward-plus` (M6.1).
- Lộ trình: xem `docs/ROADMAP.md`. Quyết định: Forward+, Instability "Destabilized" (M8), làm cả M9 và M10.

## M6.1 (nhánh này)
- `project.godot`: `forward_plus` (mobile: `mobile`). Máy cần Vulkan; nếu không chạy được thì đề xuất đổi sang Mobile/Compatibility, không tự đổi.
- `Global.ENV`: mọi tham số ánh sáng/sky/fog/tonemap/glow. `arena.gd::_build_environment` chỉ đọc từ đó (mặt trời + 4 cascade bóng, sky procedural, fog, Filmic, glow, ambient).
- Giới hạn: môi trường chụp ảnh cloud (Xvfb) không có Vulkan nên ảnh `docs/screenshots/m6_1_*` là renderer GL dự phòng, KHÔNG phải Forward+ thật; cần người chơi xem trên máy thật.

## Quy trình (từ instruction Project)
Đề xuất → chờ duyệt → nhánh feature + push → chờ "Duyệt" → merge `--no-ff` vào main. Không push `main`. Commit conventional, có trailer Co-Authored-By và Claude-Session.

## Test / công cụ
- `godot --headless --path . --import` rồi `godot --headless --path . -s tools/tests/<tên>.gd` (5 bộ: test_movement, test_advanced_movement, test_combat, test_bots, test_menu_instability; đều xanh).
- Ảnh: `xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s tools/screenshots/shoot*.gd -- <thư mục>`.
- Pitfall test `-s`: không `preload` script dùng Global ở đầu file; chờ 2 frame sau teleport; `await process_frame` đầu `_run()`.

## Việc kế tiếp
M6.2 (vật liệu/bảng màu) → M6.3 (tùy chọn chất lượng) → M7… Mỗi việc phải đề xuất + chờ duyệt.
