# Bàn giao Redliner (cập nhật 2026-11-14)

## Trạng thái
- `main` = `6897057` (5 mốc đầu + M6.1, M6.2, M6.3 đã gộp; M6 xong). Nhánh chờ duyệt: `feature/m7-1-character-models` (M7.1).
- Lộ trình: xem `docs/ROADMAP.md`. Quyết định: Forward+, Instability "Destabilized" (M8), làm cả M9 và M10.

## M6.1 (nhánh này)
- `project.godot`: `forward_plus` (mobile: `mobile`). Máy cần Vulkan; nếu không chạy được thì đề xuất đổi sang Mobile/Compatibility, không tự đổi.
- `Global.ENV`: mọi tham số ánh sáng/sky/fog/tonemap/glow. `arena.gd::_build_environment` chỉ đọc từ đó (mặt trời + 4 cascade bóng, sky procedural, fog, Filmic, glow, ambient).
- Giới hạn: môi trường chụp ảnh cloud (Xvfb) không có Vulkan nên ảnh `docs/screenshots/m6_1_*` là renderer GL dự phòng, KHÔNG phải Forward+ thật; cần người chơi xem trên máy thật.

## M6.2 (nhánh này)
- `Global.PALETTE` (màu theo vai trò) và `Global.MATERIAL_PARAMS` (metallic/roughness/emission/tile) là nguồn duy nhất cho màu đấu trường.
- `scripts/materials.gd`: `make(role)` trả `StandardMaterial3D` có cache, họa tiết lưới sinh bằng code, triplanar theo thế giới. `arena.gd::_box()` nhận vai trò (chuỗi) thay vì màu; `_build_trim()` thêm vạch sáng chân tường (không va chạm, không đổ bóng).
- Test mới: `tools/tests/test_materials.gd`. Ảnh: `docs/screenshots/m6_2_*` (vẫn là renderer GL dự phòng).

## M6.3 (nhánh này)
- `Global.QUALITY` (3 mức Thấp/Vừa/Cao: bóng, cascade, tầm bóng, SSAO, glow, fog, MSAA, scaling_3d), `QUALITY_NAMES`, `quality`, signal `quality_changed`, `set_quality()`/`cycle_quality()`. Lưu ở `user://savegame.cfg` mục `[graphics]`; `_write_save()` ghi chung với điểm cao (trước đây `submit_score` ghi đè cả file).
- `scripts/quality.gd`: `apply(level, env, sun, viewport)`. `arena.gd` nghe Signal và áp dụng (đổi mức trong lúc chơi có hiệu lực ngay).
- UI: `UIKit.quality_button()` nằm ở menu chính và menu tạm dừng.
- Test: `tools/tests/test_quality.gd`. Ảnh: `docs/screenshots/m6_3_chat_luong_*.png` (GL dự phòng, SSAO/MSAA không thể hiện trong ảnh cloud). FPS thật cần đo trên máy có Vulkan.

## M7.1 (nhánh này)
- `scripts/mannequin.gd` viết lại thành khung xương: cây Node3D, pivot ở khớp. Khớp: `hips, spine, head, shoulder_l/r, elbow_l/r, hip_l/r, knee_l/r, hand_r` (`JOINT_NAMES`, `get_joint(name)`, `reset_pose()`); vũ khí là node `weapon` dưới `hand_r`. API cũ giữ nguyên: `color`, `flash()`, `fade_out()`; thêm `kind`.
- `Global.RIG`: hình dáng theo loại (`dummy/swordsman/gunner/elite`: rộng vai, dày thân, giáp, vũ khí, vạch sáng). `bot.gd` chỉ thêm `mannequin.kind = type_name`.
- Chưa có chuyển động: M7.2 làm hoạt ảnh bằng cách xoay các khớp này (chân khớp tốc độ, nhảy, trượt...). Chiều cao ~1.8m khớp capsule va chạm.
- Test: `tools/tests/test_mannequin.gd`. Ảnh: `docs/screenshots/m7_1_nhan_vat_*.png`, script `tools/screenshots/shoot_characters.gd`. Chưa kiểm bằng mắt người: có nhận ra từ xa không, súng của xạ thủ hơi nhỏ.

## Quy trình (từ instruction Project)
Đề xuất → chờ duyệt → nhánh feature + push → chờ "Duyệt" → merge `--no-ff` vào main. Không push `main`. Commit conventional, có trailer Co-Authored-By và Claude-Session.

## Test / công cụ
- `godot --headless --path . --import` rồi `godot --headless --path . -s tools/tests/<tên>.gd` (8 bộ: test_movement, test_advanced_movement, test_combat, test_bots, test_menu_instability, test_materials, test_quality, test_mannequin; đều xanh).
- Ảnh: `xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s tools/screenshots/shoot*.gd -- <thư mục>`.
- Pitfall test `-s`: không `preload` script dùng Global ở đầu file; chờ 2 frame sau teleport; `await process_frame` đầu `_run()`.

## Việc kế tiếp
M7.2 (hoạt ảnh thân) → M7.3 (hoạt ảnh chiến đấu) → M7.4 (tay góc nhìn thứ nhất) → M8… Mỗi việc phải đề xuất + chờ duyệt.
