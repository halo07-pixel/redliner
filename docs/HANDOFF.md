# Bàn giao Redliner (cập nhật 2026-11-16)

## Trạng thái
- `main` = `4befabf` (đến M8 đã gộp; nhánh chibi M7.6 bị từ chối, không gộp). Nhánh chờ duyệt: `feature/m9-advanced-movement` (M9 di chuyển nâng cao).
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
- Nhánh A (chỉnh lại theo phản hồi "chưa hài lòng"): súng lục dựng nhiều khối (khung, thân trượt, nòng, đầu ruồi, báng, bao cò), kiếm có chuôi, đầu chuôi, tsuba, lưỡi + sống lưỡi, bàn tay có ngón và ngón cái (màu da), tay áo xanh. Nhún/lắc/tiếp đất/giật đi qua LÒ XO (`Spring`: `spring_k/c`, `rot_spring_k/c`, `sway_impulse`, `land_impulse`, `flinch_impulse` trong `Global.VIEWMODEL`) nên có quán tính và nảy nhẹ; tư thế trạng thái cũng do lò xo làm mượt.
- Giới hạn: vẫn là khối cơ bản; cẳng tay chủ yếu ngoài khung hình nên chỉ thấy bàn tay. Cần người chơi thử để chỉnh độ cứng lò xo, kích thước, vị trí.
- Kế hoạch đã duyệt: A (nhánh này, chỉnh M7.4) → B `feature/m7-5-character-polish` (làm đẹp bằng code: hình dáng chi tiết, chu kỳ chạy tốt, thở/đổi chân/quay đầu, quán tính, chém có anticipation) → C `feature/m7-6-external-assets` (asset ngoài CC0, adapter giữ API Mannequin; mạng cloud chỉ tới npm/pip/GitHub, có thể cần người dùng đính kèm file; chốt phong cách, mặc định low-poly). Mỗi nhánh một lần duyệt gộp riêng; M8 lùi sau.
- Test: `tools/tests/test_viewmodel.gd` (11 bộ test đều xanh). Ảnh: `docs/screenshots/m7_4_*.png` (đứng, chém, bắn, nạp), script `tools/screenshots/shoot_viewmodel.gd`.
- Chưa kiểm bằng người: độ mượt của nhún/lắc/giật, độ "đã tay".

## M7.5 (nhánh B, làm đẹp nhân vật bằng code)
- `mannequin.gd` dựng chi tiết hơn: ngực/bụng/đai/cổ, đầu da + mắt, khớp tròn vai/khuỷu/gối, bàn tay có ngón, bốt có cổ. Khớp mới: `hand_l`, `ankle_l`, `ankle_r` (thêm vào `JOINT_NAMES`; mọi khớp cũ và API cũ giữ nguyên). Màu da `Global.SKIN_COLOR`; thân/quần/giáp theo màu loại bot.
- Chi tiết riêng theo `Global.RIG[kind]["style"]`: `ronin` (băng đầu, dây đeo chéo, tà áo, giáp vai), `ranger` (mũ trùm, kính phát sáng, dây đạn, túi đạn), `guard` (mũ giáp có mào + khe nhìn phát sáng, giáp ống chân và cẳng tay, giáp ngực, vạch sáng). Hình bóng ba loại khác nhau rõ.
- `rig_animator.gd`: mỗi khớp đi qua lò xo (`Global.ANIM.joint_k/joint_c`) nên chuyển tư thế có quán tính; chạy: hông nhún (`hip_bob`), hông xoay/vai xoay ngược (`hip_twist`, `spine_twist`), đầu bù xoay giữ hướng nhìn, bàn chân gót chạm/đẩy mũi, khuỷu gập theo nhịp; đứng yên: thở, đổi trọng tâm, thỉnh thoảng quay đầu (`idle_look`). Overlay có khóa cộng thêm (`"+tên_khớp"`): chém hạ người dồn lực (`anticip_drop`) rồi lao tới (`lunge`, qua `hips_z`) mà chân vẫn chạy; bị đánh khuỵu gối; choáng đung đưa; ngã nảy nhẹ khi chạm đất.
- Test: `test_mannequin` và `test_animation` thêm kiểm khớp/chi tiết/hình bóng/nhún hông/lò xo; `test_combat_animation` thêm kiểm hạ người và lao tới (11 bộ test đều xanh). Ảnh: `docs/screenshots/m7_5_*.png`.
- Chưa kiểm bằng người: độ mượt thật, độ tự nhiên của chu kỳ chạy. Vẫn là khối cơ bản (nhánh C sẽ thay bằng asset ngoài). Chỉnh ở `Global.ANIM`, `Global.RIG`, `overlay_pose()`.

## M7.7 (nhánh `feature/m7-7-stickman-weapons`: người que + vũ khí thật)
- Nhánh chibi KayKit (M7.6) bị user từ chối, KHÔNG gộp; nhánh `feature/m7-6-external-assets` chỉ để tham khảo. Nhân vật user chọn: GodoDude (MIT); vũ khí: Quaternius (kiếm, rìu đôi, CC0), HoneyBadger (CC0). Nguồn/giấy phép: `docs/ASSETS.md`.
- `scripts/mannequin_gltf.gd`: cùng API với `mannequin.gd` (`animate/play/clear_overlay/flash/fade_out/set_render_layers/get_joint/kind/color/weapon/animator`). Cây khớp "proxy" (Node3D vô hình, cùng tên với hình nhân khối) do `RigAnimator` điều khiển như cũ; mỗi frame `_apply_pose()` chuyển góc proxy sang xương model bằng delta toàn cục (độc lập hướng trục xương Rigify), bù: model quay 180° quanh Y, kéo tay/chân thẳng xuống (model dạng chữ A), hông hạ qua vị trí xương gốc. Bảng ánh xạ: `JOINT_TREE`, `STRAIGHTEN`.
- Vũ khí: `WEAPONS` (file, độ dài, điểm cầm, `hold_deg` xoay quanh trục X bàn tay: cận chiến lưỡi chếch lên -56°, súng nòng dọc cẳng tay -90°). Gắn qua BoneAttachment3D ở `hand.R`.
- Sửa lỗi cũ lộ ra khi đổi nhân vật: tư thế xạ thủ giơ súng RA SAU (vai -70°); nay là +70° (rig_animator, mannequin, test_animation).
- `bot.gd` chọn adapter nếu `has_asset(type_name)`, thiếu thì dùng `mannequin.gd`. 12 bộ test xanh (thêm `test_mannequin_gltf`). Ảnh: `docs/screenshots/m7_7_*.png`; script: `tools/screenshots/shoot_stickman.gd`.
- Chưa kiểm bằng người: độ mượt khi chơi thật, vũ khí xuyên cơ thể ở vài tư thế (chém/đỡ), màu tô theo loại bot (nhân với texture gốc), clip chém/bắn là tư thế code chứ không phải mocap. Cloud không có Vulkan nên ảnh là bản GL fallback.
- Môi trường cloud có thể mất binary Godot: tải `Godot_v4.7-stable_linux.x86_64.zip` từ GitHub release `godotengine/godot-builds` tag `4.7-stable` vào `/opt/godot47`, symlink `godot`.

## M8 (nhánh `feature/m8-destabilized`: Instability "mất thế")
- Thay hẳn Redline cũ. `scripts/instability.gd` (Node dùng chung người chơi + bot): `add/lose/clash_penalty/tick/reset`, signal `changed`, `destabilized_changed`. Số cân bằng: `Global.INSTABILITY` (clash_loss 30 nhân 0.6–1.4 theo thanh, parried_loss 40, parry_miss_loss 25, parry_relief 20, hit_relief 8, decay_delay 1.5s, decay 8/s, destabilized_time 3s, immunity_time 1.5s).
- Nguồn cộng: `melee.clashed` (thua clash), `melee.got_parried` (signal mới), `parry.parry_missed`. Nguồn bớt: parry thành công, đòn kiếm trúng.
- Destabilized: `melee.stagger(3s)` (khóa kiếm, bắn, parry qua `is_staggered`), `parry.locked`, người chơi `dash_charges = 0` và ngừng hồi dash; bot chững lại + nháy. `melee.stagger` nay lấy max(thời gian cũ, mới).
- HUD: thanh vàng→cam→đỏ, nhãn "MẤT THẾ x.xs" + viền tím + SFX `destabilized`; bỏ SFX/vignette Redline, bỏ `damage_mult`.
- Test: `test_menu_instability` viết lại (logic thuần, trong game, bot). Ảnh: `docs/screenshots/m8_*.png`, script `tools/screenshots/shoot_destabilized.gd`.
- Chưa kiểm bằng người: cân bằng số (mất thế có quá dễ/khó), cảm giác 3s bị khóa; bot chưa tận dụng cơ hội (M14).

## M9 (nhánh `feature/m9-advanced-movement`: di chuyển nâng cao)
- Slide boost có cooldown (`slide_boost_cooldown` 1s, chống spam) + slide hop (nhảy khi đang trượt: +2.5 m/s, không cộng nếu đã > 26 m/s).
- Stamina dash: `dash_stamina` 0..100, mỗi dash tốn 50, hồi 50/s sau độ trễ 0.25s; `dash_charges` là property suy ra (gán được, giữ tương thích test cũ). Signal mới `stamina_changed` -> HUD thanh 10 ô; Destabilized đưa stamina về 0 và ngừng hồi.
- Grapple redirect: nhả móc chủ động xoay vận tốc về hướng nhìn (`grapple_redirect_blend` 0.7, giữ độ lớn, +3 m/s dọc hướng nhìn). Hết dây/chạm đích không redirect.
- Ground slam: phím C trên không cách đất >= 2 m; state `SLAM` lao xuống 42 m/s, chạm đất gây 25 sát thương + choáng 1s bot trong 5 m, người chơi nảy lên (tối đa 11 m/s), cooldown 1s; signal `slammed` -> SFX/tia lửa ở `main.gd`.
- Recoil: bắn khi trên không đẩy ngược hướng nòng 6 m/s (không cộng nếu đã > 30 m/s). Bắn xuống để bay lên.
- Số cân bằng ở `Global.PLAYER`. Test: `test_m9_movement`. Ảnh: `docs/screenshots/m9_*.png`, script `tools/screenshots/shoot_m9.gd`. Menu hướng dẫn có dòng C và nhả móc.
- Chưa kiểm bằng người: cảm giác (độ mạnh slide hop/slam/recoil, có "vỡ" cân bằng không, ví dụ chuỗi slide hop + dash + recoil vượt tốc độ), phím C có tiện không.

## Quy trình (từ instruction Project)
Đề xuất → chờ duyệt → nhánh feature + push → chờ "Duyệt" → merge `--no-ff` vào main. Không push `main`. Commit conventional, có trailer Co-Authored-By và Claude-Session.

## Test / công cụ
- `godot --headless --path . --import` rồi `godot --headless --path . -s tools/tests/<tên>.gd` (13 bộ: test_m9_movement, test_mannequin_gltf, test_movement, test_advanced_movement, test_combat, test_bots, test_menu_instability, test_materials, test_quality, test_mannequin, test_animation, test_combat_animation, test_viewmodel; đều xanh).
- Ảnh: `xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s tools/screenshots/shoot*.gd -- <thư mục>`.
- Pitfall test `-s`: không `preload` script dùng Global ở đầu file; chờ 2 frame sau teleport; `await process_frame` đầu `_run()`.

## Việc kế tiếp
M10 (kho vũ khí, 4 súng) → M11… Mỗi việc phải đề xuất + chờ duyệt.
