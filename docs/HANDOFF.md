# Bàn giao Redliner (cập nhật 2026-11-14)

## Trạng thái
- `main` = `e7ca7f3` (5 mốc đầu + M6 + M7.1–M7.3 đã gộp). Nhánh chờ duyệt: `feature/m7-4-viewmodel` (M7.4, kết thúc M7).
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

## M7.2 (nhánh này)
- `scripts/rig_animator.gd` (RefCounted): `pick_state()`, `target_pose()` (hàm thuần theo trạng thái/pha/tốc độ), `update()` pha trộn mượt về tư thế đích. Trạng thái: `idle, run, air, slide, dash, wallrun, grapple`. Không có logic game.
- `Mannequin.animate(delta, speed, grounded, vel_y, state_name, side)` giao cho animator; `set_render_layers(mask)`. Hằng số trong `Global.ANIM` (nhịp chạy, biên độ, `blend`, hạ hông khi trượt).
- Bot: `bot.gd` gọi `mannequin.animate` sau `move_and_slide`. Chưa có hoạt ảnh chém/bắn/choáng/chết (M7.3).
- Người chơi: `player.gd` thêm `body_view` (hình nhân kind swordsman) ở render layer `BODY_LAYER`=2; camera cull_mask loại layer này nên không thấy thân mình nhưng vẫn có bóng. `_animate_body()` đẩy trạng thái xuống (slide/wallrun/grapple/dash qua `_dash_anim_t`). Quy ước `side`: +1 tường bên phải (= `_wall_side`).
- Quy ước góc khớp: +x = vung về phía trước (-Z); +z của vai phải = dang ra ngoài.
- Test: `tools/tests/test_animation.gd` (9 bộ test tổng cộng đều xanh). Ảnh: `docs/screenshots/m7_2_cac_tu_the.png`, script `tools/screenshots/shoot_poses.gd`.
- Chưa kiểm bằng người: độ mượt khi chạy thật, tần số bước chân, biên độ; thân người chơi chỉ thấy qua bóng. Chỉnh ở `Global.ANIM`.

## M7.3 (nhánh này)
- Overlay chiến đấu trong `rig_animator.gd`: `play(name, dur, data)`, `clear_overlay()`, `overlay_pose()` (hàm thuần), `overlay_weight()` (vào 0.06s, ra 0.12s, riêng `die` giữ tư thế nằm). Overlay: `swing` (3 pha theo windup/active/recovery lấy từ Signal `swing_started`), `shoot`, `parry`, `parry_miss`, `hurt` (theo hướng đòn), `stagger`, `die`. Chỉ điều khiển tay/thân (chân giữ nhịp chạy); ưu tiên die > stagger > còn lại (ưu tiên thấp không ngắt cao). `Mannequin.play()`/`clear_overlay()`.
- Nối Signal: bot nối `melee.swing_started/staggered`, `parry.parry_started/parry_missed`, `hurtbox.hurt`, bắn trong `shoot_at`, chết trong `_on_died` (thay hiệu ứng ép dẹt bằng ngã ngửa; bot chết vẫn gọi `animate` để chạy nốt). Người chơi nối tương tự (kèm `combat.shot_fired`), `respawn` xóa overlay.
- Thời lượng/tham số trong `Global.ANIM` (`shoot_time`, `hurt_time`, `parry_time`, `parry_miss_time`, `die_time`, `overlay_in/out`). Biên độ tư thế nằm trong `overlay_pose()`.
- Test: `tools/tests/test_combat_animation.gd` (10 bộ test đều xanh). Ảnh: `docs/screenshots/m7_3_tu_the_chien_dau.png`, script `tools/screenshots/shoot_combat_poses.gd`.
- Chưa kiểm bằng người: độ "nặng đòn", khả năng đọc đòn của bot để parry (hoạt ảnh chém bám đúng thời lượng báo đòn 0.3s), độ mượt thật.

## M7.4 (nhánh này)
- `scripts/viewmodel.gd` (con của `Head`, thay `SwordView`/`Gun` và xóa `sword_view.gd`): kiếm (tay phải), súng (tay trái), bàn tay + cánh tay dựng bằng khối, không đổ bóng. Lớp nền `update(delta, speed, grounded, state)`: nhún theo bước chạy, lắc theo chuột (`add_look`), tư thế slide/dash/wallrun/grapple, nảy khi tiếp đất. Lớp chiến đấu: `play_swing`, `raise` (giữ tween cũ), `kick` (giật + chớp nòng), `set_reloading(on)` (hạ/lắc/nâng đúng `Global.COMBAT["gun_reload"]`), `flinch(dir)`, `reset()`.
- `player.gd`: `viewmodel` nối Signal (`swing_started`, `parry_started`, `shot_fired`, `reloading_changed`, `hurt`); `_anim_state_name()` dùng chung cho thân và viewmodel; `respawn` gọi `viewmodel.reset()`.
- Mọi hệ số ở `Global.VIEWMODEL`. Cánh tay chủ yếu nằm ngoài màn hình, chỉ thấy bàn tay; súng nhìn từ bên cạnh khá to (giữ kích thước hộp cũ), có thể chỉnh sau khi chơi thử.
- Test: `tools/tests/test_viewmodel.gd` (11 bộ test đều xanh). Ảnh: `docs/screenshots/m7_4_*.png` (đứng, chém, bắn, nạp), script `tools/screenshots/shoot_viewmodel.gd`.
- Chưa kiểm bằng người: độ mượt của nhún/lắc/giật, độ "đã tay".

## Quy trình (từ instruction Project)
Đề xuất → chờ duyệt → nhánh feature + push → chờ "Duyệt" → merge `--no-ff` vào main. Không push `main`. Commit conventional, có trailer Co-Authored-By và Claude-Session.

## Test / công cụ
- `godot --headless --path . --import` rồi `godot --headless --path . -s tools/tests/<tên>.gd` (11 bộ: test_movement, test_advanced_movement, test_combat, test_bots, test_menu_instability, test_materials, test_quality, test_mannequin, test_animation, test_combat_animation, test_viewmodel; đều xanh).
- Ảnh: `xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s tools/screenshots/shoot*.gd -- <thư mục>`.
- Pitfall test `-s`: không `preload` script dùng Global ở đầu file; chờ 2 frame sau teleport; `await process_frame` đầu `_run()`.

## Việc kế tiếp
M8 (Instability "Destabilized")… Mỗi việc phải đề xuất + chờ duyệt.
