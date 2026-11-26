# Lịch sử bàn giao Redliner (M6-M39, chi tiết từng mốc; bản gọn đang dùng: docs/HANDOFF.md)

## Trạng thái
- `main` = `b1ca383` (đến M17 đã gộp; nhánh chibi M7.6 bị từ chối, không gộp). Nhánh chờ duyệt: `feature/m18-clear-animation` (hoạt ảnh/hiệu ứng rõ ràng, yêu cầu thêm sau M17).
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
- Test: `tools/tests/test_animation.gd` (9 bộ test tổng cộng đều xanh). Bench: `tools/bench/bench.gd`. Ảnh: `docs/screenshots/m7_2_cac_tu_the.png`, script `tools/screenshots/shoot_poses.gd`.
- Chưa kiểm bằng người: độ mượt khi chạy thật, tần số bước chân, biên độ; thân người chơi chỉ thấy qua bóng. Chỉnh ở `Global.ANIM`.

## M7.3 (nhánh này)
- Overlay chiến đấu trong `rig_animator.gd`: `play(name, dur, data)`, `clear_overlay()`, `overlay_pose()` (hàm thuần), `overlay_weight()` (vào 0.06s, ra 0.12s, riêng `die` giữ tư thế nằm). Overlay: `swing` (3 pha theo windup/active/recovery lấy từ Signal `swing_started`), `shoot`, `parry`, `parry_miss`, `hurt` (theo hướng đòn), `stagger`, `die`. Chỉ điều khiển tay/thân (chân giữ nhịp chạy); ưu tiên die > stagger > còn lại (ưu tiên thấp không ngắt cao). `Mannequin.play()`/`clear_overlay()`.
- Nối Signal: bot nối `melee.swing_started/staggered`, `parry.parry_started/parry_missed`, `hurtbox.hurt`, bắn trong `shoot_at`, chết trong `_on_died` (thay hiệu ứng ép dẹt bằng ngã ngửa; bot chết vẫn gọi `animate` để chạy nốt). Người chơi nối tương tự (kèm `combat.shot_fired`), `respawn` xóa overlay.
- Thời lượng/tham số trong `Global.ANIM` (`shoot_time`, `hurt_time`, `parry_time`, `parry_miss_time`, `die_time`, `overlay_in/out`). Biên độ tư thế nằm trong `overlay_pose()`.
- Test: `tools/tests/test_combat_animation.gd` (10 bộ test đều xanh). Bench: `tools/bench/bench.gd`. Ảnh: `docs/screenshots/m7_3_tu_the_chien_dau.png`, script `tools/screenshots/shoot_combat_poses.gd`.
- Chưa kiểm bằng người: độ "nặng đòn", khả năng đọc đòn của bot để parry (hoạt ảnh chém bám đúng thời lượng báo đòn 0.3s), độ mượt thật.

## M7.4 (nhánh này)
- `scripts/viewmodel.gd` (con của `Head`, thay `SwordView`/`Gun` và xóa `sword_view.gd`): kiếm (tay phải), súng (tay trái), bàn tay + cánh tay dựng bằng khối, không đổ bóng. Lớp nền `update(delta, speed, grounded, state)`: nhún theo bước chạy, lắc theo chuột (`add_look`), tư thế slide/dash/wallrun/grapple, nảy khi tiếp đất. Lớp chiến đấu: `play_swing`, `raise` (giữ tween cũ), `kick` (giật + chớp nòng), `set_reloading(on)` (hạ/lắc/nâng đúng `Global.COMBAT["gun_reload"]`), `flinch(dir)`, `reset()`.
- `player.gd`: `viewmodel` nối Signal (`swing_started`, `parry_started`, `shot_fired`, `reloading_changed`, `hurt`); `_anim_state_name()` dùng chung cho thân và viewmodel; `respawn` gọi `viewmodel.reset()`.
- Nhánh A (chỉnh lại theo phản hồi "chưa hài lòng"): súng lục dựng nhiều khối (khung, thân trượt, nòng, đầu ruồi, báng, bao cò), kiếm có chuôi, đầu chuôi, tsuba, lưỡi + sống lưỡi, bàn tay có ngón và ngón cái (màu da), tay áo xanh. Nhún/lắc/tiếp đất/giật đi qua LÒ XO (`Spring`: `spring_k/c`, `rot_spring_k/c`, `sway_impulse`, `land_impulse`, `flinch_impulse` trong `Global.VIEWMODEL`) nên có quán tính và nảy nhẹ; tư thế trạng thái cũng do lò xo làm mượt.
- Giới hạn: vẫn là khối cơ bản; cẳng tay chủ yếu ngoài khung hình nên chỉ thấy bàn tay. Cần người chơi thử để chỉnh độ cứng lò xo, kích thước, vị trí.
- Kế hoạch đã duyệt: A (nhánh này, chỉnh M7.4) → B `feature/m7-5-character-polish` (làm đẹp bằng code: hình dáng chi tiết, chu kỳ chạy tốt, thở/đổi chân/quay đầu, quán tính, chém có anticipation) → C `feature/m7-6-external-assets` (asset ngoài CC0, adapter giữ API Mannequin; mạng cloud chỉ tới npm/pip/GitHub, có thể cần người dùng đính kèm file; chốt phong cách, mặc định low-poly). Mỗi nhánh một lần duyệt gộp riêng; M8 lùi sau.
- Test: `tools/tests/test_viewmodel.gd` (11 bộ test đều xanh). Bench: `tools/bench/bench.gd`. Ảnh: `docs/screenshots/m7_4_*.png` (đứng, chém, bắn, nạp), script `tools/screenshots/shoot_viewmodel.gd`.
- Chưa kiểm bằng người: độ mượt của nhún/lắc/giật, độ "đã tay".

## M7.5 (nhánh B, làm đẹp nhân vật bằng code)
- `mannequin.gd` dựng chi tiết hơn: ngực/bụng/đai/cổ, đầu da + mắt, khớp tròn vai/khuỷu/gối, bàn tay có ngón, bốt có cổ. Khớp mới: `hand_l`, `ankle_l`, `ankle_r` (thêm vào `JOINT_NAMES`; mọi khớp cũ và API cũ giữ nguyên). Màu da `Global.SKIN_COLOR`; thân/quần/giáp theo màu loại bot.
- Chi tiết riêng theo `Global.RIG[kind]["style"]`: `ronin` (băng đầu, dây đeo chéo, tà áo, giáp vai), `ranger` (mũ trùm, kính phát sáng, dây đạn, túi đạn), `guard` (mũ giáp có mào + khe nhìn phát sáng, giáp ống chân và cẳng tay, giáp ngực, vạch sáng). Hình bóng ba loại khác nhau rõ.
- `rig_animator.gd`: mỗi khớp đi qua lò xo (`Global.ANIM.joint_k/joint_c`) nên chuyển tư thế có quán tính; chạy: hông nhún (`hip_bob`), hông xoay/vai xoay ngược (`hip_twist`, `spine_twist`), đầu bù xoay giữ hướng nhìn, bàn chân gót chạm/đẩy mũi, khuỷu gập theo nhịp; đứng yên: thở, đổi trọng tâm, thỉnh thoảng quay đầu (`idle_look`). Overlay có khóa cộng thêm (`"+tên_khớp"`): chém hạ người dồn lực (`anticip_drop`) rồi lao tới (`lunge`, qua `hips_z`) mà chân vẫn chạy; bị đánh khuỵu gối; choáng đung đưa; ngã nảy nhẹ khi chạm đất.
- Test: `test_mannequin` và `test_animation` thêm kiểm khớp/chi tiết/hình bóng/nhún hông/lò xo; `test_combat_animation` thêm kiểm hạ người và lao tới (11 bộ test đều xanh). Bench: `tools/bench/bench.gd`. Ảnh: `docs/screenshots/m7_5_*.png`.
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

## M10 (nhánh `feature/m10-weapons`: kho vũ khí)
- `Global.WEAPONS` + `WEAPON_ORDER` (súng lục, shotgun, pháo nổ, bắn tỉa) và `Global.HEAVY_SLASH`. `COMBAT.gun_*` giữ nguyên cho súng lục (test cũ dùng).
- `player_combat.gd` viết lại: `weapon`, đạn riêng mỗi súng (`ammo` là property theo súng đang cầm), `switch_to`, rút súng = `draw` giây khoá bắn, đổi súng huỷ nạp. Signal mới `weapon_changed(id, name)`, `exploded(pos, radius)`. Input xung: `want_weapon` (0..3), `want_cycle` (±1), `want_heavy`; giữ: `want_zoom`.
- Shotgun: 2 đạn, 8 viên x 12, tản 5°, giảm sát thương theo xa (min 20% ở 18 m), recoil trên không x3.
- Pháo nổ: `scripts/rocket.gd` đạn bay có trọng lực nhẹ, nổ khi chạm; `Rocket.explode()` tĩnh: sát thương giảm theo khoảng cách, đẩy lùi + choáng (`bot.apply_knockback`), người bắn bị đẩy (`player.apply_blast`, rocket-jump) và chịu 15% sát thương.
- Bắn tỉa: 80 sát thương, headshot x2 (điểm trúng cao hơn gốc hurtbox 1.5 m), xuyên 1 mục tiêu (x0.6), tường chặn; giữ Z để zoom FOV 35 (độ nhạy chuột theo FOV).
- Chém rộng: phím Q (KHÔNG phải giữ chuột trái, tránh làm trễ đòn thường/parry): `melee.try_swing(true)` báo đòn x1.7, hộp rộng x1.9, dài x1.5, sát thương x1.4, hồi x1.8.
- Phím: 1-4 hoặc cuộn chuột đổi súng, Q chém rộng, Z ngắm. Viewmodel có 4 mẫu súng (`set_weapon`), HUD hiện tên súng, SFX shotgun/launcher/explosion/sniper, vụ nổ có tia lửa + rung.
- Test: `test_weapons` (40 kiểm tra). Ảnh: `docs/screenshots/m10_*.png`, script `tools/screenshots/shoot_m10.gd` (ảnh GL dự phòng, không phải Vulkan).
- Chưa kiểm bằng người: cân bằng (sát thương/recoil/rocket-jump), cảm giác bắn tỉa zoom, mô hình súng còn thô (hộp), bot chưa né/phản ứng với pháo.

## M11 (nhánh `feature/m11-maps`: bản đồ)
- `scripts/maps.gd`: dữ liệu 3 map (yard "Sân tập" = bố cục gốc, alley "Hẻm tường" 34x90, tower "Tháp" 56x56 tường cao 18 m): half, wall_h, void_y, boxes, spawn, bot_spawns, dummies. Chỉ là dữ liệu, test không cần cảnh.
- `arena.gd` đọc dữ liệu (`_build_map`), có `half` (Vector2), `wall_h`, `void_y`, `map_id`, signal `map_loaded(id)`. Mặc định dùng `Global.selected_map`; test/ảnh đặt `arena.map_id` trước `add_child`.
- `Global`: `MAP_IDS`, `MAP_NAMES`, `selected_map` (lưu trong savegame mục `game/map`), `set_map`, `cycle_map`, signal `map_changed`. Menu có nút "Bản đồ: ..." (`UIKit.map_button`), đổi cho lần chơi sau.
- `main.gd`: rơi dưới `void_y` -> mất 30 máu và về điểm xuất phát (chỉ người chơi). Wave lấy `arena.bot_spawns` của map.
- KHÔNG có hố/vực: bot chưa có navmesh nên đi thẳng vào hố; để M14. Lối bot đi luôn là sàn phẳng.
- Test: `test_maps` (kiểm tra spawn không kẹt khối, bot đứng được ở mọi điểm sinh, chọn/lưu map, menu, rơi map). Ảnh: `docs/screenshots/m11_*.png`, `tools/screenshots/shoot_m11.gd`. Trong test `-s`, truy cập thuộc tính của Global qua `root.get_node("Global")` (viết `Global.x` cho biến không phải const sẽ lỗi biên dịch).
- Chưa kiểm bằng người: bố cục có hay/cân bằng không, bot có kẹt ở dốc/khe hẻm không, tháp có dễ leo không, tầm nhìn bắn tỉa ở hẻm.

## M12 (nhánh `feature/m12-effects`: vật thể và hiệu ứng)
- `Global.FX`, `Global.PICKUPS`, `Global.BREAKABLES` (số cân bằng); `Global.reduced_fx` + `set_reduced_fx` + signal `fx_changed` (lưu savegame `graphics/reduced_fx`), nút "Hiệu ứng: Đầy đủ/Giảm" ở menu (`UIKit.fx_button`). Giảm hiệu ứng: không vệt kiếm, không sóng parry, hạt còn 1/3 (tối thiểu 4), rung camera x0.4.
- `scripts/sword_trail.gd`: `SwordTrail.attach(melee)` (player + bot). Nghe `swing_started`, ghi cặp điểm quét ngang trong pha active, dải `ImmediateMesh` mờ dần 0.16 s; chém rộng có vệt cam, rộng hơn. Chạy ở `_process` (chỉ hình ảnh).
- `Fx.ring()` sóng parry (torus nở rồi tan, null khi giảm hiệu ứng); `Fx.sparks` theo `reduced_fx`.
- `scripts/pickup.gd` (health/ammo/stamina): `Pickup.spawn`, `pick_kind(roll)` theo trọng số, phát `collected(kind)`, hết hạn 12 s (nhấp nháy 3 s cuối). `main._on_pickup_collected` áp hiệu ứng (`hurtbox.heal`, `combat.refill`, `dash_stamina`). Bot chết rơi 25%.
- `scripts/breakable.gd`: thùng nổ (`barrel`, 20 máu, nổ bằng `Rocket.explode`, dây chuyền, gây sát thương cả người chơi + bot + thùng khác, để vệt cháy) và thùng gỗ (`crate`, 40% rơi đồ). Signal `exploded`, `broken`; arena chuyển tiếp thành `explosion` / `prop_broken`; `maps.gd` có `barrels`/`crates` mỗi map (không đè điểm sinh).
- Test: `test_effects` (43 kiểm tra). Ảnh: `docs/screenshots/m12_*.png`, `tools/screenshots/shoot_m12.gd` (GL dự phòng 6 fps nên script làm chậm thời gian để bắt vệt kiếm).
- Chưa kiểm bằng người: độ rơi đồ, độ mạnh thùng nổ (50 sát thương, bán kính 5 m, hại cả người chơi), vệt kiếm nhìn từ góc thứ nhất có rõ/chói không, vị trí thùng. Bot chưa biết né/lợi dụng thùng nổ (M14).

## M13 (nhánh `feature/m13-feel`: cảm giác điều khiển)
- `Global.PLAYER` thêm: coyote_time 0.1, jump_buffer 0.12, ledge_* (min 0.9 / max 2.3 m, reach 0.8, up 0.16 s, over 0.12 s, cooldown 0.4, max_rise_speed 4), step_stride 2.2, bob_amplitude/frequency, strafe_roll_deg, gamepad_look_speed.
- `player.gd`: `State.LEDGE`; coyote (`_coyote_t`) + jump buffer (`_jump_buf_t`, `_jump_requested()`, `_do_jump()`) dùng cho nhảy thường, coyote và slide hop. Trèo gờ `_try_ledge` (ray ngực + ray xuống tìm mặt bệ + kiểm tra chỗ đứng bằng capsule; chỉ khi giữ phím tiến và vy <= 4) rồi `_move_ledge` hai pha (kéo lên, bước qua) bằng vận tốc; huỷ qua `cancel_ledge()` khi bị đánh, dash, móc, đập đất. Signal mới `footstep(speed)` (theo quãng đường, 2.2 m/bước, chỉ khi đi bộ trên sàn) và `ledge_climbed`. `apply_look(Vector2 rad)` dùng chung chuột + cần phải tay cầm. Camera: lắc đầu (`_update_bob`), nghiêng nhẹ khi đi ngang, FOV nền từ cài đặt; tắt khi `reduced_fx`.
- `Global`: `settings` (mouse_mult, invert_y, fov, bob, pad_sens, pad_deadzone; kẹp giá trị, lưu mục `settings`), `set_setting/reset_settings`, signal `settings_changed`. Đổi phím: `REMAPPABLE`, `rebind(action, event)` (thay phím chính, giữ nút tay cầm, chặn trùng bằng `binding_conflict`), `binding_text`, `reset_bindings`, signal `bindings_changed`, lưu mục `bindings`. Tay cầm kiểu Xbox (`_setup_gamepad`): cần trái di chuyển, cần phải nhìn (action `look_*`), RT chém, LT móc, A nhảy, B trượt, X dash, Y chém rộng, RB bắn, LB parry, L3 đập đất, R3 ngắm, d-pad đổi súng/nạp, Start = ui_cancel.
- `scripts/settings_menu.gd`: màn Cài đặt (thanh trượt, đảo Y, bảng đổi phím, Mặc định, Quay lại), mở từ menu chính và menu tạm dừng (Esc trong Cài đặt quay về tạm dừng). Dùng `set_anchors_and_offsets_preset` (nếu chỉ dùng `set_anchors_preset` thì Control tạo bằng code có kích thước 0).
- Test: `test_feel` (70 kiểm tra). Trong test `-s`: `DisplayServer.keyboard_get_keycode_from_physical` không chạy headless nên dùng `InputEventKey.as_text_physical_keycode()`. Ảnh: `docs/screenshots/m13_*.png`, `tools/screenshots/shoot_m13.gd`.
- Chưa kiểm bằng người: cảm giác coyote / buffer / trèo gờ (có thể "hút" khó chịu: chỉnh ledge_* ở Global), lắc đầu, và TOÀN BỘ phần tay cầm (không có tay cầm thật; chỉ test ánh xạ InputMap, chưa thử vùng chết hay độ nhạy cần phải trong game).

## M14 (nhánh `feature/m14-smart-bots`: bot thông minh)
- `Global`: bot mới `rusher` (lao nhanh, bọc sườn) và `bomber` (pháo thủ đứng xa, ném đạn nổ vòng cung, `Global.BOMB`); độ khó Dễ/Thường/Khó (`DIFFICULTY_LEVELS`, `DIFFICULTY`, `set_difficulty`, `cycle_difficulty`, signal `difficulty_changed`), kỷ lục riêng từng mức (`progress/high_score_<mức>`), `bot_stats(type, wave, level)` là hàm thuần (máu/tốc độ/phản ứng/parry/né có trần theo wave + hệ số mức).
- `arena.gd`: navmesh nướng từ collider tĩnh (`_build_nav`, `nav_path`); map chỉ đồng bộ sau ~10 physics frame nên `bot._navigate` dùng `_steer` thẳng tới khi `map_get_iteration_id > 0`.
- `bot.gd`: đi theo đường navmesh (tính lại mỗi 0.3 s, chọn điểm đường > 0.4 m), giới hạn 3 bot cận chiến áp sát cùng lúc (`max_melee_attackers`, còn lại đứng vòng ngoài), lùi một nhịp sau khi bị parry, trừng phạt khi người chơi Destabilized (báo đòn ngắn, nhanh hơn, bắn ngay), `_throw_bomb`. `rocket.gd` hỗ trợ `hit_mask`/`skip_team` (đạn bot không hại bot).
- `wave_manager.composition`: elite > bomber (wave >= 4) > rusher (wave >= 2) > gunner > swordsman. Menu có nút "Độ khó".
- Test: `test_smart_bots` (62 kiểm tra, gồm chữ U, bệ không leo được, vòng vây, pháo thủ, lưu độ khó). 18 bộ đều xanh.
- Chưa kiểm bằng người: cân bằng độ khó / số bot, cảm giác lùi + vòng vây, sát thương bom (25, bán kính 3.2). Navmesh tĩnh (không cập nhật khi thùng/vật vỡ). Bot chưa lợi dụng thùng nổ. Rusher/bomber dùng lại mô hình cũ, chỉ khác vũ khí. Không có Vulkan trên cloud nên chưa nhìn bằng mắt.

## M15 (nhánh `feature/m15-audio`: âm thanh và nhạc)
- `Global`: `SOUNDS` (bảng âm: vol_db, pitch_var, voices tối đa, bus), `AUDIO_BUSES`, `AUDIO` (số tiếng 2D/3D, unit_size, max_distance, music_fade, ngưỡng cường độ), `SURFACES`, `step_sound(surface)`; cài đặt mới `vol_master/vol_sfx/vol_music` (kẹp 0..1, lưu mục `settings`).
- `sfx.gd` viết lại: bus Master/SFX/Music/UI (tự tạo; UI theo vol_sfx), `play(tên)` 2D, `play_at(tên, vị trí)` 3D (AudioStreamPlayer3D), pitch ngẫu nhiên, giới hạn tiếng theo âm + theo pool, `stop_all`, thống kê `plays`/`dropped`. Thêm âm: step_metal/wood, jump, ledge, reload, switch, recover, ui_click, bot_die, game_over.
- Nhạc 3 lớp calm/base/intense (cùng độ dài, loop, bắt đầu cùng lúc), `play_music("menu"|"battle")`, `set_intensity`, trượt mức lớp trong `music_fade` giây. Hàm thuần `compute_intensity(bot còn lại, tỉ lệ máu, mất thế)` và `layer_levels`.
- `main.gd` nối Signal -> âm (bot/vụ nổ/thùng/bot chết phát 3D; bước chân theo meta "surface" của collider dưới chân). Mới: `player.jumped`. Arena/breakable gắn meta "surface". Menu phát nhạc êm; mọi nút `UIKit.button` có tiếng click. Cài đặt có 3 thanh âm lượng.
- Test: `test_audio` (86 kiểm tra). 19 bộ đều xanh.
- Chưa kiểm bằng người: cloud KHÔNG có thiết bị âm thanh nên chưa nghe được gì; chỉ kiểm logic. Độ to nhỏ, độ chói, độ hay của âm tổng hợp và nhạc, tốc độ chuyển lớp nhạc, khoảng cách nghe 3D đều cần bạn nghe thử (chỉnh trong `Global.SOUNDS`/`AUDIO`). Âm làm bằng code khá đơn giản; muốn hay hơn cần file âm thanh thật.

## M16 (nhánh `feature/m16-modes`: chế độ chơi và giao diện)
- `Global`: `MODES` (survival/timed/training), `MODE_NAMES`, `MODE_DESCRIPTIONS`, `TIMED` (90 s đầu, +3 s mỗi bot, trần 150 s, mục tiêu 25 bot, thưởng thắng 10 điểm/giây còn lại), `TRAINING`, `BOT_ORDER/BOT_NAMES`; `game_mode`, `set_mode`/`cycle_mode`, signal `mode_changed`; `best_score(mode, level)` và `submit_mode_score(value, mode)` (sinh tồn vẫn dùng `high_score`/`submit_score` như cũ; thời gian lưu `progress/high_score_timed_<mức>`; tập luyện không có kỷ lục); lưu `game/mode`.
- `game_mode.gd` (mới): luật từng chế độ, chỉ phát Signal (`objective_changed`, `time_changed` giới hạn 0.1 s, `finished(won, info)`); `on_kill()`, `result_score(base, won)`. `run_stats.gd` (mới, RefCounted): bot hạ theo loại, độ chính xác súng, thời gian ván, `format_time`.
- `wave_manager.gd`: `alive_types` (bot còn lại theo loại), `spawn_practice` + signal `practice_bot_killed` (bot tập không tính vào wave).
- `main.gd`: tạo `GameMode`, `_start_mode()`, `_setup_training()` (bất tử: hồi đầy sau mỗi đòn; đạn vô hạn), `_end_run(title, won)` chung cho gục/thắng/hết giờ, `build_result()` dựng nội dung tổng kết. Điểm bot được cộng TRƯỚC `mode.on_kill()` vì phát hạ cuối có thể kết thúc ván ngay.
- `hud.gd`: `set_objective`, `set_timer` (đỏ + số lẻ dưới 10 s), `set_enemy_types`, `set_mode_layout`. `game_over.gd`: `show_result(dict)` (tiêu đề xanh khi thắng). `menu.gd`: bấm Chơi mở màn "Chuẩn bị" (chế độ / bản đồ / độ khó / mô tả / kỷ lục / Bắt đầu); hướng dẫn lấy tên phím từ `Global.binding_text` (phím chính) nên đổi phím là cập nhật.
- Test: `test_modes` (113 kiểm tra). 21 bộ đều xanh. Ảnh: `docs/screenshots/m16_*.png` (`tools/screenshots/shoot_m16.gd`).
- Chưa kiểm bằng người: CÂN BẰNG thử thách thời gian (90 s, +3 s/bot, 25 bot có thắng nổi không?) - chỉnh trong `Global.TIMED`; số/độ khó bot tập; bố cục menu ở màn hình nhỏ; độ dễ đọc của đồng hồ. Bot tập sinh lần lượt theo `TRAINING.types` (chưa có phím chọn loại bot). Tập luyện thoát bằng Esc > Về menu. Chưa có bảng xếp hạng online (không nằm trong M16).

## M18 (nhánh `feature/m18-clear-animation`: hoạt ảnh và hiệu ứng rõ ràng)
Mục tiêu: mọi hành động đọc được ngay trên màn hình. Chỉ là hiển thị; vật lý/logic không đổi. Số chỉnh: `Global.VIEWMODEL`, `Global.FX`.
- **Tư thế kiếm/súng theo trạng thái** (`viewmodel.gd` + `VIEWMODEL.sword_pose/gun_pose`): lướt (kiếm nghiêng thấp, súng nghiêng), dash (kiếm kéo ra sau), grapple, chạy tường. Chạy nhanh hạ kiếm về trước (`sprint_lean`), đứng yên thở nhẹ (`idle_sway`), đi ngang nghiêng tay (`strafe_roll`, `update(..., lateral)`). Nhún chạy tăng ~2x (`bob_amp/bob_side`). Cường độ nhân với `settings.bob` (0 = tắt hết tư thế phụ, ai say chuyển động dùng).
- **Chém**: windup kéo kiếm ra sau, active lao tới quét chéo xuống, recovery về (cả vị trí lẫn góc). Vệt kiếm dài/sáng hơn (`FX.trail_life/trail_max_points/trail_color`).
- **Đỡ kiếm (parry)**: `raise()` rút kiếm lên chắn ngang giữa màn hình (`guard_pos/guard_rot`) suốt cửa sổ parry; `parry_hit()` đẩy ra trước khi thành công, `parry_fail()` hất kiếm xuống rồi loạng choạng về. Nối từ `parry.parried` / `parry.parry_missed` trong `player.gd`.
- **Súng**: chớp nòng xoay/co giãn ngẫu nhiên + đèn nháy (`flash_light`, tắt khi giảm hiệu ứng).
- **Grapple**: `grapple_rope.gd` vẽ dây dạng dải rộng, phóng ra trong 0.12 s (lượn sóng rồi căng), có đầu móc phát sáng; tia lửa + vòng sóng ở điểm neo.
- **Vệt tốc độ** (`speed_lines.gd`, shader viền màn hình, từ 12 m/s) và **bụi** (`Fx.dust`) khi lướt/dash. Parry có thêm tia lửa trắng.
- Bot đã có tư thế parry/chém riêng từ M7.3 nên không đổi.
- Test: `test_m18` (tư thế theo trạng thái, đỡ/parry hụt, chen ngang không kẹt, chớp nòng, dây móc, vệt tốc độ, bụi, giảm hiệu ứng). Ảnh: `tools/screenshots/shoot_m18.gd`.
- Cần người chơi thử: mức "rõ" là cảm giác, hãy chỉnh `sword_pose`, `guard_*`, `bob_amp`. Tư thế đỡ là vệt chéo cắt qua giữa màn hình (có thể che tâm ngắm một chút khi đỡ). Chưa có hoạt ảnh tay riêng cho tay cầm súng khi grapple ngoài việc giơ lên.

## M19 (nhánh `feature/m19-smooth-animation`: hệ hoạt ảnh mượt hơn)
- `viewmodel.gd` viết lại, GIỮ API công khai. Mọi thứ đi qua lò xo: `Layer` (kiếm, súng) = clip keyframe đặt ĐÍCH cho lò xo vị trí + lò xo góc (mềm hơn: `rot_lag`, cổ tay trễ nhịp). Clip bắt đầu từ tư thế hiện tại, kết bằng khoá `base` (tư thế nền sống) nên chen ngang không nhảy. Cửa sổ hủy `cancel_from` + hàng đợi 1 lệnh (`pending_command`); `parry_fail`/`reset` ngắt ngay.
- Trọng số trạng thái `_w` (slide/dash/wallrun/grapple) trượt trong `VIEWMODEL.state_fade` rồi smoothstep: đổi trạng thái là cross-fade. Tư thế nằm trong `VIEWMODEL` (`sword_pose`, `gun_pose`, `body_pose`).
- Tay hai khớp IK (`solve_two_bone`, `_make_arm`): vai cố định, cổ tay bám vật cầm; test `arm_error()`.
- Giật súng là lò xo cộng thêm (`_kick_spring`), `footstep()` nhún tay mỗi bước (nối Signal `Player.footstep`).
- Camera (`player.gd`): lao nhẹ khi chém, đập khi tiếp đất theo tốc độ rơi, nghiêng khi lướt; nhịp lắc camera bám `step_stride` (điểm thấp nhất trùng tiếng bước). Hệ số Cài đặt `cam_fx` (0..1.5); hằng số `ANIM.cam_*`. LƯU Ý: nhịp lắc camera trước đây ~10 Hz, nay ~4 Hz ở 9 m/s: cảm giác khác, cần chơi thử.
- Bot (`rig_animator.gd`): overlay vào/ra smoothstep, chém ease-in + follow-through, đỡ bật nhanh, parry hụt nảy đàn hồi, trúng đòn xoay hông/đầu theo hướng.
- Gỡ lỗi: F3 rồi F4 hiện clip/pha viewmodel (`Global.anim_debug`). Test mới `test_m19` (không nhảy tư thế, hàng đợi, chen ngang, IK, không rò node, camera). `viewmodel` tự chạy trong `_process` khi chủ nhân không gọi `update()` (test/màn xem trước).
- CHƯA kiểm bằng người: độ mượt thật khi chơi, các hằng số k/zeta (`VIEWMODEL.*_k`, `ANIM.cam_*`) cần chỉnh sau khi chơi thử. Ảnh chuỗi: `docs/screenshots/m19/sheet_*.png` (`tools/screenshots/shoot_m19.gd`).

## M20 (nhánh `feature/m20-contact-animation`: IK hình nhân + hoạt ảnh tiếp xúc + bộ chỉnh)
- `scripts/rig_ik.gd` (mới): `solve`/`apply_limb` giải IK hai khớp (định lý cos, trục bản lề X chiếu vuông góc d, không suy biến khi tay duỗi thẳng ra trước); `plant_feet` (raycast `L_WORLD` dưới mỗi cổ chân, chỉ khi chân ở pha chạm đất, hạ hông theo chân thấp nhất, gần như không can thiệp trên sàn phẳng); `apply_look` (đầu/thân nhìn mục tiêu, chặn yaw 60 / pitch 30 độ, tắt khi chết/choáng/clash); `apply_support_hand` (tay trái đỡ báng cho gunner/bomber). Chạy trong `rig_animator._apply_ik` SAU FK, nên chỉ đổi góc khớp, không đụng vật lý.
- `mannequin_gltf.gd`: `_fit_proxy_lengths()` gán vị trí khớp proxy từ xương thật (đoạn dưới của tay/chân = (0, -độ dài, 0)); góc xoay proxy vẫn là thứ duy nhất vào `_apply_pose`, FK không đổi. Proxy lệch z hằng 0.05 m so với xương thật (không ảnh hưởng xoay). Cả hai mannequin có `set_look_target`, `ik_feet`, `support_grip()`. Thân người chơi (body_view) tắt `ik_feet`.
- Tiếp xúc: overlay mới `clash` (ưu tiên 2) và `parry_hit`; `stagger` có cú hất kiếm ban đầu tắt dần; `hurt` có `zone` head/torso/legs. `bot.hit_zone(hit)` đọc `hit["point"]` (đạn và hitscan đã gắn điểm trúng; đòn kiếm không có điểm = torso). Bot nối `melee.clashed` và `parry.parried`; người chơi nối `melee.clashed` -> `viewmodel.clash` + thân, `parry.parried` -> `viewmodel.parry_hit` (kiếm bật ra, clip `parry_hit`) + thân. KHÔNG đổi logic sát thương hay thời gian parry.
- Bộ chỉnh: `scripts/anim_tuner.gd` (F3 rồi F4): thanh trượt cho các khoá trong `Global.TUNABLE_VM`/`TUNABLE_ANIM`, ghi đè qua `Global.tune` (viewmodel/player/rig đọc bằng `Global.tv()`/`Global.ta()`), đường cong độ lệch kiếm, nút "Xuất" (clipboard + `user://anim_tuning.txt`, dạng `v.swing_active_k = 900`) và "Đặt lại". Mở thì thả chuột; `main.gd` không bắt lại chuột khi `anim_debug` bật.
- Test: `test_m20` (IK chính xác trên cả hai mannequin, bậc thang/hố, sàn phẳng không đổi hoạt ảnh chạy, nhìn mục tiêu, tay đỡ báng, overlay tiếp xúc, nối Signal bot/người chơi, bộ chỉnh). Chụp: `tools/screenshots/shoot_m20.gd`, ảnh ở `docs/screenshots/m20/`.
- CHƯA làm/kiểm: IK chân không nghiêng bàn chân theo mặt dốc (chỉ nâng/hạ); tay đỡ báng của model glTF có tay ngắn nên đôi khi không với tới hết (kéo giãn được chặn); hoạt ảnh clash/trúng đầu chỉ kiểm bằng số và ảnh tĩnh; cảm giác thật, các hằng số `look_*`, `support_hand`, `clash_impulse` cần chơi thử. Clip animation từ asset ngoài vẫn là hạng mục riêng (chưa làm).

## M21 (nhánh `feature/m21-big-map`: map lớn "Khu phố")
- Map thứ 4 `district` (id trong `Maps.IDS`, `Global.MAP_IDS/MAP_NAMES`): 134x134 m (~18.000 m2, gấp 5 lần Sân tập). Cỡ chỉnh ở `Maps.DISTRICT_HALF`; bố cục sinh bằng code với hạt giống cố định `DISTRICT_SEED` (cùng kết quả mỗi lần).
- Gồm: quảng trường + cột bệ móc ở giữa, tháp 3 tầng (TB), hẻm tường (ĐB), đồi dốc (TN), cánh đồng chỗ nấp (ĐN), ~15 toà nhà nối bằng phố rộng, 28 điểm sinh bot, thùng/hòm.
- Khoá map mới: `spawn_band` (bot sinh cách người chơi 35..60 m, `wave_manager._pick_in_band`; map cũ giữ cách "xa nhất"), `compass` (HUD `set_compass` hiện mũi tên + khoảng cách kẻ địch gần nhất, cập nhật từ `main._update_compass`), `nav_cell`.
- Navmesh bake đồng bộ ~80 ms trên cloud (đo `arena.nav_bake_ms`); sương mù map lớn nhạt hơn (x0.6).
- Test: `tools/tests/test_m21.gd`; ảnh `tools/screenshots/shoot_m21.gd`. Chưa kiểm FPS thật / cảm giác (cloud không có GPU): xem F3.
- Việc sau: m22 cảm giác grapple, m23 di chuyển bot, m24 Titan.

## M22 (nhánh `feature/m22-grapple-feel`: cảm giác grapple)
- `player.gd`: `_find_grapple_point()` (tia chính + hỗ trợ ngắm: 8 tia x 2 vòng trong nón `grapple_assist_deg`, bỏ mặt sàn), `_update_grapple_target` (10 lần/giây, Signal `grapple_target_changed` -> `hud.set_grapple_ready` chấm vàng), dây căng kiểu con lắc (`grapple_swing`, `_grapple_len` chỉ ngắn lại, bỏ vận tốc hướng ra khi dây căng), nhả lúc căng cộng `grapple_release_snap`.
- Lực kéo theo smoothstep; tới gần điểm móc (`grapple_stop_dist`) ngừng kéo nhưng vẫn bám nếu còn giữ chuột; `grapple_max_time` 6 s; tầm 90 m.
- `grapple_rope.gd`: `set_tension` (dây dày hơn khi kéo mạnh).
- Thông số grapple nằm trong `Global.PLAYER` (sửa trong code; bộ chỉnh F4 chỉ chỉnh hoạt ảnh). Test: `tools/tests/test_m22.gd`; `test_advanced_movement` đổi kỳ vọng "tới gần thì vẫn bám".

## M23 (nhánh `feature/m23-bot-movement`: di chuyển bot)
- `Global.BOT_MOVE`: `accel/decel` (vận tốc ngang bot tăng/giảm dần, `_smooth_velocity`; né vẫn bật tức thì), `turn_rate` (xoay thân có tốc độ), `lookahead` (nhắm điểm ngoặt xa hơn nếu thấy thẳng, `_clear_walk`), `vault_*` (nhảy leo khối tĩnh <= 3 m khi người chơi ở cao hơn hoặc kẹt, `_try_vault`; bệ cao hơn thì bot không lên được), `cover_*` (xạ thủ/pháo thủ nấp sau mỗi lần bắn, `_find_cover`), `far_*` (bot xa > 60 m tính đường mỗi 1 s), `unstick_time` (kẹt 2 lần trong 3 s -> lách ngang).
- Điểm bọc sườn của rusher được snap vào navmesh.
- Test: `tools/tests/test_m23.gd` (có bài chạy bot trên Khu phố); đổi kỳ vọng ở `test_bots` (tới chậm hơn do gia tốc), `test_smart_bots` (bệ 5 m thay 3 m; đảo chiều lùi cần ~16 khung).
- Test tháp 2 nấc trong test_m23 phụ thuộc ngẫu nhiên (hướng lách) nên đôi khi chậm; nếu đỏ, chạy lại.

## M24 (nhánh `feature/m24-titans`: Titan)
- `scripts/titan.gd` (CharacterBody3D, group "bots", cùng giao diện signal với bot: `died(bot, info)`, `sound`, `exploded`, thêm `health_changed`, `stepped`, `stomp_landed`, `weak_point_hit`). Hình nhân khối `mannequin.gd` kind `titan` phóng 6x (chưa có asset Titan riêng).
- Ba vùng nhận sát thương (Hurtbox máu vô hạn, máu thật trừ ở `_on_zone_hit`): thân `body_mult 0.1`, gáy `nape_mult 6`, gối `knee_mult 0.5`; sát thương thô vào gối >= `knee_threshold` -> quỵ `kneel_time` giây (gáy hạ thấp).
- Hai đòn có báo trước: giậm (vòng đỏ dưới đất, tránh bằng cách chạy ra / nhảy cao) và quét (dải đỏ trước mặt); đều đi qua `target.hurtbox.take_hit` kind `melee` nên parry được -> Titan choáng `parry_stagger` giây.
- Navmesh riêng cho Titan: `arena._build_titan_nav` (map điều hướng riêng `titan_nav_map`, bán kính `agent_radius` 2 m); bot thường không đổi.
- Grapple móc được thân Titan (Area trên tầng `Global.L_TITAN`), điểm móc bám theo thân (`player._grapple_node`, `rope.set_target`); Titan chết thì thả móc.
- Wave: chỉ map có `"titans": true` (Khu phố): wave 5, 10, ... thêm Titan (`wave_manager.titans_enabled`, `Global.TITAN`: `first_wave`, `every`, `max_alive`). HUD: thanh máu Titan (`hud.set_boss`), chữ GÁY!/GỐI!, rung màn hình theo khoảng cách (main `_hook_titan`).
- Thông số: `Global.TITAN` và `Global.BOTS["titan"]`. Test: `tools/tests/test_m24.gd`; ảnh `tools/screenshots/shoot_m24.gd`.
- Chưa kiểm cân bằng / cảm giác khổng lồ trong chơi thật (cloud không có GPU).

## M25 (nhánh `feature/m25-live-tuning`: chỉnh lúc chơi)
- `Global.PLAYER`, `BOT_MOVE`, `TITAN` đổi từ `const` sang `var` để sửa được lúc chạy. API: `set_live(nhóm, khoá, giá trị)` (nhóm `p`/`b`/`t`; chỉ khoá trong `TUNABLE_LIVE`), `live_changed()`, `reset_live()`, `save_live()` / `load_live()` (file `user://tuning.cfg`, chỉ lưu phần khác mặc định; nạp tự động khi mở game), `apply_titan_preset("easy"|"normal"|"hard")`.
- Bộ chỉnh `anim_tuner.gd` (F3 -> F4) có thêm mục Grapple / Di chuyển bot / Titan, nút Lưu và ba nút Titan dễ/thường/khó; "Xuất" in cả các giá trị mới (khoá `p.`, `b.`, `t.`) để dán vào `global.gd`.
- Titan: thêm `health_mult`, `windup_mult` trong `Global.TITAN` (độ khó).
- F3 (`perf_overlay.gd`) thêm dòng: số bot, khoảng cách tới Titan, thời gian bake navmesh, số giá trị tuning đang đổi.
- Lưu ý: nếu có file `user://tuning.cfg`, game dùng giá trị trong đó thay mặc định (F3 báo "tuning N giá trị đổi"). Xoá bằng nút Đặt lại rồi Lưu.
- Test: `tools/tests/test_m25.gd`.

## M26 (nhánh `feature/m26-unified-motion`: chuyển động mượt, đồng nhất)
- `scripts/motion.gd`: `damp()` (lò xo tắt dần tới hạn, vận tốc liên tục) và `pops()` (đếm "cú giật" trong chuỗi mẫu, dùng để đo độ mượt).
- `Global.MOTION` + preset `smooth` (mặc định) / `fast` (`apply_motion_preset`, nút trong F4): gia tốc người chơi `ground_accel` 70 (fast 100; lưu ý cân bằng với ma sát: cần > walk_speed * friction), bot 55, thời gian đáp ứng camera (roll/FOV/độ cao đầu qua `Motion.damp` thay lerp mũ), `accel_lean` (thân nghiêng theo gia tốc ở `rig_animator.update`, dùng chung cho người chơi, bot, Titan), `grapple_redirect_time` 0.15 s (nhả móc xoay vận tốc dần, `_step_redirect`), `grapple_tilt_deg` (camera nghiêng về điểm móc).
- Titan: nhịp bước khớp chu kỳ hoạt ảnh (`anim_speed_mult`, một bước = nửa chu kỳ).
- Test: `tools/tests/test_m26.gd` (đo thời gian đạt 90% tốc độ, thời gian dừng, độ giật camera, nhả móc, nghiêng theo gia tốc). Đã cập nhật `test_feel` (FOV đuổi bằng lò xo), `test_m9_movement` và `test_m22` (nhả móc xoay dần trong ~0.15 s).
- Số đo (cloud): smooth đạt 90% tốc độ sau ~0.28 s, dừng sau ~0.30 s; fast ~0.18 s. Cảm giác thật cần bạn thử bằng F4 -> nút Chuyển động mượt/nhanh.

## M27 (nhánh `feature/m27-titan-access`: Titan dễ thử)
- Titan chỉ có ở map Khu phố (`"titans": true`): Sinh tồn và Thời gian từ wave 5; Tập luyện: phím T (`spawn_titan`, đổi phím được) gọi / xoá một Titan (`main._toggle_practice_titan`, `wave_manager.spawn_titan_practice` / `clear_titans`). Map nhỏ: T chỉ hiện chữ báo.
- `Global.start_wave` (1/5/10/15, `cycle_start_wave`, nút `UIKit.start_wave_button` trong màn Chuẩn bị, ẩn ở Tập luyện): `wave_manager.first_wave`. Chơi từ wave > 1 thì `submit_mode_score` không ghi kỷ lục.
- Menu: mô tả Khu phố ghi "có Titan từ wave 5"; mô tả Tập luyện nhắc phím T.
- Test: `tools/tests/test_m27.gd`.

## M28 (nhánh `feature/m28-parry-feel`: cảm giác parry)
- KHÔNG đổi số parry/phạt (`COMBAT.parry_window` 0.18, `parry_miss_cooldown` 0.8, phản đạn x2.5/x1.3): chỉ thêm phản hồi, nghe Signal `parried`/`parry_missed`/`swing_started`.
- Hằng số mới `Global.ANIM["pf_*"]` (đều có trong F4): `pf_hitstop` 0.08 (đỡ kiếm), `pf_hitstop_bullet` 0.05, `pf_hitstop_scale`, `pf_clash_hitstop`, `pf_reduced_hitstop` (x0.5 khi giảm hiệu ứng), `pf_cam_kick`, `pf_fov_punch`, `pf_spark_cone`, `pf_flash_energy`, `pf_tell_lean/time/range`, `pf_miss_stumble`. `Global.parry_hitstop_time(kind)`.
- `main._on_parried`: tia lửa phun NGƯỢC hướng đòn (`Fx.sparks(..., direction, spread)`), `player.parry_react(incoming)` (camera giật pitch/roll theo phía đòn + FOV nảy, lò xo `Motion.damp`, nhân `cam_fx`, tắt khi reduced_fx), hitstop theo loại đòn, thêm tiếng `parry_low`. `_incoming_dir(hit)`: kiếm = từ kẻ tấn công, đạn = ngược vận tốc đã bị phản.
- Viewmodel: chớp đèn xanh trên lưỡi kiếm khi bật (`_blade_flash`).
- Âm mới: `parry_low`, `parry_miss` (parry hụt), `tell` (bot bắt đầu gồng).
- Bot báo đòn (chỉ hình ảnh/âm thanh, không đổi windup): `rig_animator` swing windup ngả người `pf_tell_lean` trong `pf_tell_time` đầu; `bot._on_swing_tell` phát `tell` và chớp vũ khí (`mannequin.flash_weapon`) đúng lúc cửa sổ parry mở (windup - parry_window), chỉ khi bot gần hơn `pf_tell_range`. Parry hụt của bot loạng choạng x`pf_miss_stumble`.
- Chưa kiểm bằng người: độ "đã tay", mức hitstop/giật camera, độ rõ của chớp báo đòn. Chỉnh trong F4 (nhóm hoạt ảnh `a.pf_*`). Chưa làm ảnh chuỗi (cloud chỉ chụp tĩnh, không có GPU).

## M29 (nhánh `feature/m29-viewmodel-weapons`: tay + vũ khí góc nhìn thứ nhất)
- Chỉ hình ảnh; không đổi sát thương/nhịp nạp/tầm bắn. API công khai của `viewmodel.gd` giữ nguyên; thêm `ledge()` (nối `ledge_climbed`) và tham số cuối `fall_speed` của `update()` (player truyền `_fall_peak`).
- Nạp riêng từng súng: `Viewmodel.reload_steps(id)` (pistol 3 bước, shotgun 5: mở/2 viên/đóng/kéo ống trượt, launcher 4, sniper 4); `_reload_keys` chia đều `WEAPONS[id]["reload"]` nên tổng thời gian không đổi. Bộ phận chuyển động theo tiến độ nạp (`_anim_parts`, `_update_parts`): băng pistol, ống trượt shotgun, nắp miệng launcher, khoá nòng sniper.
- Rút súng: `VIEWMODEL.weapon_draw[id]` (tư thế bắt đầu + "over"), tổng = `WEAPONS[id]["draw"]`. Giật: `VIEWMODEL.weapon_kick[id]` (back/pitch/time; sniper và launcher hồi chậm hơn).
- Tay: `_hand()` trả về các ngón; `_update_fingers` (ngón trỏ tay súng duỗi rồi bóp cò khi bắn, các ngón siết theo độ giật; tay kiếm siết khi chém/đỡ), biên độ `grip_curl_deg`.
- Môi trường: tiếp đất nảy mạnh theo vận tốc rơi (`land_fall_gain`), leo gờ nhấc vũ khí (`ledge_impulse`). Ba số này cùng `grip_curl_deg` có trong F4 (nhóm viewmodel).
- Model súng: thêm khối chi tiết (rãnh trượt, ray, đầu ruồi, tay cầm trước...) bằng khối code, KHÔNG tải asset mới.
- Chưa kiểm bằng người: độ mượt, độ đẹp, cảm giác từng bước nạp. Chỉnh trong F4.

## M30 (nhánh `feature/m30-bot-motion`: chuyển động bot theo hướng và tình huống)
- Chỉ hình ảnh; không đổi vận tốc/nav/AI. Hằng số `Global.ANIM["bm_*"]` (có trong F4).
- `rig_animator.set_motion(dir_local, turn_deg_per_s)` (qua `mannequin`/`mannequin_gltf`): hướng đi cục bộ (x phải, y tiến) + tốc độ quay người. Mặc định = đi thẳng nên người chơi/Titan không đổi.
- Dáng chạy: lùi bước ngắn + ngả ra sau + bước chân đổi chiều; đi ngang hông xoay về hướng đi, vai giữ hướng nhìn, chân bắt chéo; quay người thì thân dẫn trước (hông trễ nhờ lò xo khớp).
- Trạng thái mới `cover` (ngồi thấp, nhô lên khi bắn) và `vault`; `bot._animate_body` truyền tên trạng thái từ `_cover_pt/_cover_t` và `_vault_push_t` (không dùng get_parent).
- `hurt` ĐÃ có hướng đòn + vùng trúng từ trước (M20); M30 thêm cho `die`: trước -> ngửa, sau -> sấp, bên -> nghiêng, trúng đầu hất cổ, trúng chân sụp gối (dữ liệu `{direction, zone}` từ `_last_hit`).
- Chưa kiểm bằng người: độ tự nhiên của dáng chạy ngang/lùi, chiều bắt chéo chân (quy ước trục khớp chưa nhìn thấy trên GPU). Chỉnh ở F4.

## M31 (nhánh `feature/m31-stability-pass`: kiểm tra tổng thể)
- `test_m31` (smoke): mọi chế độ x mọi bản đồ vào/chạy/ra (không node thừa, không mồ côi, không rò nav map), vào lại Khu phố 4 lần ổn định, chạy tới wave 6 có Titan (không kẹt), 900 khung chồng tính năng (reduced_fx, cam_fx, đổi súng, nạp, parry, leo gờ, dịch chuyển) không lỗi. In số đo logic headless (physics TB ~6-7 ms, bake nav Khu phố ~70 ms; KHÔNG phải FPS thật).
- Sửa: bot gltf đầu tiên làm giật ~100 ms (nạp model + vũ khí lần đầu). `MannequinGltf.warm_up()` nạp nền khi vào trận (`main._ready`); sinh bot đầu giờ ~2 ms.
- `test_m23` tháp hai nấc thử tối đa 3 lần (hết chớp nháy), bỏ dòng DBG. README thêm phím T, F3/F4.
- Cảnh báo "N ObjectDB instances leaked at exit" khi thoát là AudioStream của Sfx lúc tắt (có từ trước, vô hại, không phải rò trong trận).
- Chưa kiểm bằng người: FPS thật, độ mượt (F3), cân bằng.

## M32 (nhánh `feature/m32-clip-animations`: clip chuyển động cho bot gltf)
- Asset: `assets/animations/ual/UAL1_Standard.glb` (Universal Animation Library [Standard], CC0; xem `docs/ASSETS.md`). Dùng 7 clip: Idle/Sword_Idle/Pistol_Idle, Walk, Jog_Fwd, Sprint, Crouch_Idle.
- `scripts/clip_lib.gd` (static): nạp glb một lần, bake clip 30 fps thành quaternion local của 15 khớp proxy + `hips_y`; `sample(clip, t)`. Có `FLIP` (rig nhìn -Z, model +Z) và `STRAIGHTEN`.
- `RigAnimator._blend_clip` chạy ngay sau `target_pose()`: chân/hông/thân/đầu theo clip (trọng số `ac_*`), tay giữ do code (`ac_arm`=0). Chọn clip theo tốc độ/loại vũ khí/núp; lùi/đi ngang giảm trọng số. Overlay chiến đấu (swing/parry/shoot/hurt/die) vẫn do code, thời gian không đổi.
- Chỉ rig gltf (bot). Rig khối (Titan/dummy/player) không có clip. Thiếu asset thì tự về toàn code. Tắt: `ANIM["ac_enabled"]=0`; chỉnh nóng ở F4.
- Chưa đo: tốc độ clip so với tốc độ bot (`ac_walk_speed/jog_speed/sprint_speed` là ước lượng, có thể trượt chân) — cần user xem trong game.
- Test: `tools/tests/test_m32.gd`; ảnh: `docs/screenshots/m32/`.

## M33 (nhánh `feature/m33-grapple-speed-cap`: chống tăng tốc vô hạn khi spam grapple)
- Nguyên nhân: `grapple_max_speed` chỉ kẹp thành phần hướng về điểm móc; mỗi lần nhả móc cộng `grapple_release_boost`/`grapple_release_snap` và cooldown chỉ 0.5s nên spam cộng dồn (đo: 12 lần nhả liên tiếp lên ~108 m/s).
- `Player._apply_speed_cap` (trước `move_and_slide`): tốc độ ngang > `grapple_soft_cap` (38) bị hãm hàm mũ (`grapple_cap_drag`), không chặn cứng. `_release_redirect` nhân boost/snap với `room = 1 - v/cap`.
- Cooldown chuỗi: `_grapple_chain` (+1 mỗi lần kết thúc móc, giảm `grapple_chain_recover`/s); quá `grapple_chain_free` lần thì + `grapple_chain_cd` mỗi lần, tối đa `grapple_chain_cd_max`.
- FOV nở theo tốc độ tối đa `fov_speed_max` = 11 (trước 18).
- Không thêm vào F4 theo yêu cầu; chỉnh bằng các hằng số `grapple_*` trong `Global.PLAYER`. Các con số chưa được chơi thử thật.
- Test: `tools/tests/test_m33.gd`.

## Sửa lỗi bot (đã gộp, nhánh `fix/bots-review`)
Tìm bằng mô phỏng wave thật trên 3 map (người chơi bất tử, dịch chuyển; theo dõi vị trí/vận tốc từng bot), không đoán mò:
- **Bot sinh trùng chỗ bị đẩy văng** (lên cao hàng trăm mét, hoặc ra ngoài tường): wave lớn có nhiều bot hơn điểm sinh nên 2 bot trùng đúng một vị trí, engine đẩy chúng ra. `wave_manager.gd`: `_free_spot` xếp bot ra các vòng quanh điểm sinh (cách nhau `SPAWN_GAP` 1.3 m, tránh tường/người chơi bằng shape query). Lưới an toàn `_physics_process`: bot rơi dưới `void_y` hoặc ra ngoài biên thì đưa về điểm sinh (signal `bot_relocated`), vì trước đây bot rơi map thì wave không bao giờ kết thúc.
- **Bot kẹt trước bậc thấp** (chỗ nối dốc với bệ trên map Tháp; mép dốc): CharacterBody3D không tự leo bậc. `bot.gd` `_try_step_up()` (STEP_HEIGHT 0.75, khớp việc navmesh coi mép tới ~0.7 m là đi được); chỉ leo qua mép tĩnh dựng đứng, có kiểm tra trần, không leo lên đầu bot khác hay tường cao.
- **Bot húc vào thùng thấp rồi đứng yên**: ray né tường chỉ ở độ cao 0.5 m nên không thấy thùng cao ~0.5 m. `_steer` quét ở 0.2/0.55/1.0 m, và giữ nhất quán bên đã chọn để lách (`_steer_hold`) vì trước đó nó lắc qua lắc lại ở mép vật cản. Thêm `_track_blocked`: muốn đi mà không nhúc nhích >0.4 s thì ép đi theo navmesh 1.5 s.
- `main.gd` `_on_player_hurt`: kiểm tra `is_instance_valid` trước `is Node3D` (nguồn đạn đã bị giải phóng gây SCRIPT ERROR).
- Test: `test_bot_fixes` (sinh bot, ngoài biên, leo bậc, thùng thấp, kẹt, nguồn đã giải phóng). 20 bộ đều xanh.
- Còn lại / cần người chơi thử: bot xạ thủ và pháo thủ đứng yên ở tầm giữ khoảng cách là chủ ý, không phải lỗi. Bot hơi "nhảy" qua mép khi leo bậc (không có hoạt ảnh riêng). Bot chưa tránh thùng nổ. Mô phỏng không thay được chơi thật: chưa kiểm cảm giác bot bám đuổi, vây, né.

## M17 (nhánh `feature/m17-polish`: hoàn thiện)
- **Cầm kiếm**: góc nhìn thứ nhất giờ cầm lưỡi kiếm thẳng lên (`_sword_rest` pitch 72°, `sword_pos` hạ thấp để thấy cả lưỡi). Vì Euler YXZ bị kẹp pitch ±90°, nên windup là pitch 88° + xoay yaw/roll, chém là quét xuống chéo, parry là ngả lưỡi 40°. Tay áo tính ngược từ `Basis.from_euler(rest).inverse()` để vẫn nối đúng vai. Bot (góc nhìn thứ ba) đã cầm lưỡi hướng lên nên không đổi.
- **Phiên bản**: `Global.VERSION` ("1.0.0"), hiện ở menu chính cùng gợi ý phím F3.
- **Bảng FPS**: `scripts/perf_overlay.gd`, phím F3 (mặc định tắt): FPS, ms/khung, số node.
- **Save hỏng**: `Global._num/_flag` — giá trị sai kiểu, âm, NaN, ngoài khoảng về mặc định thay vì lỗi; file không phải ConfigFile thì bỏ qua.
- **Công cụ đo**: `godot --headless --path . -s tools/bench/bench.gd -- [wave=4] [map,map]` (headless chỉ đo chi phí script, KHÔNG đo GPU). Kết quả wave 1-3, mức Khó, 6 bot: process trung bình ~2 ms, physics ~3-4 ms; đỉnh >20 ms chỉ ở vài khung đầu (nạp map, bake navmesh, tổng hợp âm thanh) chứ không ở lúc đánh nhau; sau khi thoát ván không thừa node. Vì không có điểm nóng trong lúc chơi nên KHÔNG tối ưu thêm (không đoán mò); bỏ qua pooling hiệu ứng. Việc cần máy thật: đo FPS GPU 3 mức đồ họa (Thấp/Vừa/Cao).
- **Sửa lỗi tìm được khi soak**: `rocket.gd` truyền người bắn đã bị giải phóng vào `Rocket.explode` gây SCRIPT ERROR; giờ truyền null nếu không còn hợp lệ.
- Test: `test_polish` (save hỏng, VERSION, F3, vào/thoát ván 4 lần, 5 wave: số node tĩnh giữ nguyên 380). `test_viewmodel` cập nhật cho tư thế mới. 22 bộ test.
- Soak: 5 wave mức Khó trên 3 map không còn lỗi script/bot kẹt sau các bản sửa. Chưa soak 3 map × 3 mức × 3 chế độ đủ dài (mất nhiều giờ); cần người chơi thử thật.

### Bảng số cần chỉnh sau khi chơi thử (tất cả trong `scripts/global.gd`)
| Cảm giác | Nơi chỉnh |
| --- | --- |
| Bot quá yếu / mạnh | `DIFFICULTY.levels` (health, speed, reaction, parry, dodge), `BOTS[loại]` (health, speed, windup, attack_cd, shoot_interval) |
| Wave quá dễ / dày | `DIFFICULTY` (cỡ wave, tăng theo wave), `TIMED` (start_time, kill_bonus, target_kills) |
| Kiếm đánh nặng / nhẹ | `COMBAT` (sword_damage, sword_windup/active/recovery, sword_reach, parry_window) |
| Di chuyển nặng / trôi | `PLAYER` (ground_accel, ground_friction, air_accel, gravity, jump_velocity, coyote_time) |
| Instability quá nhanh / chậm | `INSTABILITY` |
| Cầm kiếm / súng trong tay | `VIEWMODEL` (sword_pos...), `viewmodel.gd` (`_sword_rest`, tư thế chém) |
| Âm lượng, nhạc | `AUDIO`, `SOUNDS`, mục Cài đặt |
| Mức đồ họa | `QUALITY` |

## M34 (nhánh `feature/m34-endless-map`: chế độ Vô Tận, bản đồ lớn + vòng lặp tầng)
Mốc 1/6 của chế độ "Vô Tận" (M34 bản đồ + tầng, M35 XP/chọn nâng cấp, M36 khung súng + lỗi riêng, M37 vàng + cửa hàng, M38 nâng cấp từng súng, M39 nâng cấp kiếm).
- **Chế độ** `endless` (`Global.MODES`, menu: bỏ chọn bản đồ/wave khi chọn Vô Tận). Mọi con số ở `Global.ENDLESS` (ô 50 m, lưới 6x6 = 300x300 m, chỉ tiêu 15 + 5/tầng, bot tối đa 6 + 1/tầng tới 14, vòng sinh 40-80 m, gỡ bot xa > 130 m, Titan mỗi 5 tầng, hồi 30% máu khi sang tầng).
- **Bản đồ** `Maps.endless(tầng)`: mỗi ô một mẫu ngẫu nhiên (1 toà, 2 toà, cụm cột, trống), hạt giống theo tầng; toà nhà lùi >= 8 m trong ô nên phố rộng >= 16 m, mọi ô thông nhau. Xuất phát một góc, cổng ở góc đối diện (ô trống). Chỉ toà nhà, cột, bệ móc; không bia/thùng.
- **Arena**: `map_id "endless"`, `floor_n`, `exit_point`, `load_floor(n)` xoá node bản đồ cũ (theo dõi qua `_add_map_node`) + navmesh Titan rồi dựng lại; nav bake đồng bộ (~110-130 ms đo headless, cell 0.5 m).
- **`portal.gd`**: Area3D cổng; khoá đỏ mờ, mở xanh + cột sáng 80 m; chỉ phát `entered`.
- **`game_mode.gd`**: `floor_n`, `floor_kills`, `quota`, `portal_open`, `boss_pending`, signal `floor_changed`/`portal_opened`; `on_kill(type_name)` (Titan không tính vào chỉ tiêu nhưng phải hạ mới mở cổng); `next_floor()`.
- **`wave_manager.gd`**: `stream = true` -> không wave; `begin_floor(n, có_titan)`, sinh dần tới `stream_cap` ở vòng quanh người chơi (dùng `spawn_band` sẵn có), `_prune_far` gỡ bot xa (không tính hạ, không điểm).
- **main.gd**: nối Signal; `_on_floor_changed` dựng tầng mới, `player.teleport(...)` (giữ máu/đạn/đồ), xoá vật nhặt cũ. Vào cổng xử lý `CONNECT_DEFERRED` (không đổi vật lý trong callback va chạm).
- Test: `test_m34` (hình học, luật tầng, navmesh có đường tới cổng 4 tầng, vòng sinh/gỡ bot, tích hợp main). `test_modes`, `test_m31` cập nhật cho chế độ thứ 4. Ảnh tĩnh `docs/screenshots/m34/`.
- **Chưa kiểm bằng người**: FPS thật trên bản đồ 300x300 (khuất tầm nhìn, 14 bot + shadow), cảm giác nhịp độ tầng, chỉ tiêu/cap bot, độ tương thích tốc độ chạy 300 m (cổng xa ~350 m đường chéo), navmesh đồng bộ chậm ~10 khung hình ngay sau khi dựng tầng (bot đi thẳng trong lúc đó). Nav bake đồng bộ có thể gây khựng ~0.1-0.2 s khi qua tầng trên máy yếu.
- Pitfall: `await process_frame` đầu `_run()` ở script `-s`, nếu không `global_position` lên node mới thêm bị bỏ qua.

## M35 (nhánh `feature/m35-xp-levelup`: XP, lên cấp, chọn nâng cấp — mốc 2/6 của Vô Tận)
- **XP**: bot chết rơi `xp_orb.gd` (3 XP, Titan 40; `Global.XP.orb`), bay về người chơi trong tầm hút `player.pickup_magnet` (mặc định 3 m), hết hạn 45 s; chỉ phát `collected`. Cấp n->n+1 cần `10 + 6n` XP (`Global.XP`).
- **`run_progress.gd`** (logic thuần + Signal `xp_changed/leveled_up/upgrade_chosen`): `add_xp` (nhân hệ số Học nhanh), nhiều cấp liền nhau xếp hàng `pending`, `choose(id)`, `skip()`, `pools` (hiện `["shared"]`; M38/M39 thêm `gun:<id>`/`sword`). XP/cấp/nâng cấp mất khi hết lượt.
- **`upgrades.gd`**: `available/draw/stat` trên `Global.UPGRADES` (kho dùng chung 10 thẻ: sát thương súng, tốc độ bắn, băng đạn, nạp, máu tối đa, tự hồi, chạy, nam châm, học nhanh, stamina). `kind` "mult" -> 1+Σ, "add" -> Σ. Thêm thẻ = thêm một dòng dữ liệu.
- **`level_up_ui.gd`**: 3 thẻ + Bỏ qua (hồi 25% máu, `Global.XP.skip_heal`), phím 1/2/3/4, chạy khi pause (ALWAYS), chỉ phát `card_chosen/skipped`.
- **main.gd**: `_next_level_choice` (pause + hiện thẻ; hết thẻ thì tự Bỏ qua, không kẹt pause), `_apply_upgrades` áp hệ số lên `player.combat` (`damage_mult/fire_rate_mult/mag_mult/reload_mult`, áp ở `_hit` và tên lửa), `player.speed_mult/stamina_regen_mult/pickup_magnet`, `hurtbox.max_health`; tự hồi máu trong `_physics_process`.
- HUD: thanh XP + cấp ở giữa dưới; la bàn (map lớn) chuyển xuống giữa dưới vì đè dòng wave/tầng ở giữa trên (lỗi bố cục có sẵn trên Khu phố).
- Test: `test_m35` (48 kiểm tra). Ảnh `docs/screenshots/m35/`.
- **Chưa kiểm bằng người**: nhịp lên cấp (tầng 1 ~3 cấp), pause khi lên cấp có gây khó chịu giữa trận không, độ mạnh từng thẻ. Thẻ sát thương chỉ tăng súng (kiếm có kho riêng ở M39). Tăng băng đạn chỉ đổi mức đầy khi nạp lại.

## M36 (nhánh `feature/m36-gun-flaws`: khung lỗi riêng của súng + súng lục — mốc 3/6 của Vô Tận)
- **Khung lỗi**: mỗi súng trong `Global.WEAPONS` có `"flaw": id`; số liệu + tên + gợi ý ở `Global.FLAWS`. `gun_flaws.gd` (RefCounted, logic thuần): `enabled` (chỉ bật ở Vô Tận, main đặt), `mods` (hệ số nâng cấp), `tick`, `aim(weapon, dir)`, `on_shot`, `spread`. `player_combat.gd` giữ `flaws`, `weapon_mods` (`"<id>_damage_mult"`, `"<id>_pierce"`), phát `flaw_changed(spread_deg, max_deg)`; HUD nghe Signal (`set_spread`: vòng nở khớp góc thật theo FOV + dòng chữ tên lỗi). Ngoài Vô Tận không có lỗi, bắn như cũ.
- **Lỗi súng lục "Giật theo nhịp"** (`rhythm_recoil`): phát đầu chuẩn tuyệt đối; mỗi phát +0.6° (tối đa 6°), hồi 8°/s; hướng bắn lệch ngẫu nhiên trong hình nón bán kính = độ lệch hiện tại. Nâng cấp chỉ nhân hệ số, không gỡ lỗi (test: dù 3 bậc Nhịp ổn định, spam vẫn lên 6°).
- **Kho `gun:pistol`** (4 thẻ): Nhịp ổn định (-20% lệch/phát, 3 bậc), Hồi tay (+30% hồi, 3), Đạn xuyên (+1 mục tiêu, còn 70%, 2 bậc), Nòng nặng (+20% sát thương, 3). `RunProgress.set_weapon_pool(id)` đổi kho theo súng đang cầm (main nối `weapon_changed`); súng chưa có kho chỉ rút từ kho chung. Thẻ đã lấy vẫn áp khi đổi súng nhưng chỉ có tác dụng khi cầm đúng súng đó. Hiệu ứng thẻ âm hiện "-40%".
- Thêm súng khác ở M37/M38: thêm `flaw` + nhánh trong `gun_flaws.gd` + kho `gun:<id>` + khoá `weapon_mods` tương ứng.
- Test: `test_m36` (40 kiểm tra, gồm đạn xuyên/sát thương thật qua 2 bia). Ảnh `docs/screenshots/m36/`. Pitfall test: đặt `player.use_input = false` thì mới tự điền `want_shoot`.
- **Chưa kiểm bằng người**: cảm giác độ lệch (0.6°/phát, tối đa 6°, hồi 8°/s), vòng nở có đủ rõ khi bắn thật; cân bằng thẻ súng lục.

## M37 (nhánh `feature/m37-gold-shop`: vàng, cửa hàng, súng khởi đầu, 3 lỗi súng — mốc 4/6 của Vô Tận)
- **Vàng** (lưu lâu dài trong savegame mục `[meta]`: `gold`, `owned_guns`, `start_gun`): mỗi tầng `8 + 4*tầng`, +1/bot, +30/Titan (`Global.GOLD`). `main.gd` giữ `run_gold`; ghi vào `Global` khi đổi tầng, hết lượt và thoát (`_flush_gold` idempotent, không cộng trùng). Savegame hỏng (vàng âm, id lạ, súng khởi đầu chưa sở hữu) được làm sạch khi đọc.
- **Cửa hàng**: nút "Cửa hàng" ở menu chính -> `shop_menu.gd` (Shotgun 150, Bắn tỉa 300, Pháo 500; súng lục miễn phí). Chỉ gọi `Global.buy_gun`. Màn Chuẩn bị có nút "Súng khởi đầu" (chỉ hiện ở Vô Tận) xoay vòng qua súng đã sở hữu.
- **Vô Tận chỉ cầm súng khởi đầu + kiếm**: `combat.locked = true` chặn đổi súng.
- **3 lỗi mới** (`Global.FLAWS`, logic ở `gun_flaws.gd`, chỉ bật ở Vô Tận): Shotgun "Giật bật người" (đẩy 6 m/s ngược hướng ngắm, x1.6 trên không, ngắm xuống thì bật lên; phát `self_impulse`, Player cộng vào velocity); Bắn tỉa "Nạp ngắm" (giữ 0.8 s mới nổ, thả sớm huỷ, đi 50% khi nạp, mỗi lần giữ một phát; `charge_changed` -> `laser_beam.gd` vẽ tia đỏ); Pháo "Tự chịu nổ" (tự sát thương 60% thay vì 15%).
- Thêm súng: dữ liệu `flaw` + nhánh trong `gun_flaws.gd` + (M38) kho `gun:<id>`.
- Test: `test_m37` (59 kiểm tra); `test_m36` sửa vì shotgun giờ có lỗi. Ảnh `docs/screenshots/m37/`. Menu chính thu gọn khoảng cách vì thêm nút thứ 7.
- **Chưa kiểm bằng người**: giá súng, cảm giác giật shotgun/nạp bắn tỉa, laser nhìn thấy trên GPU thật. Bot không phản ứng với laser. Kho thẻ riêng của shotgun/bắn tỉa/pháo + SMG/revolver để M38.

## M38 (nhánh `feature/m38-gun-pools`: kho thẻ riêng shotgun / bắn tỉa / pháo — mốc 5/6 của Vô Tận)
- 12 thẻ đổi cách chơi (không chỉ cộng %), dữ liệu ở `Global.UPGRADES["gun:<id>"]`, thông số ở `Global.PERKS`. Thẻ cờ có `"effect"` (chữ hiện thay "+x%", `level_up_ui.effect_text`). `main._apply_upgrades` chép mọi stat của kho `gun:*` (trừ pistol) vào `combat.weapon_mods`; combat đọc bằng `_wmod("<khoá không tiền tố>")`. Lỗi gốc không bao giờ bị gỡ.
- **Shotgun**: Cú đá đôi (+25%/bậc sát thương khi đang bay, 3 bậc), Sóng xung kích (hất lùi bot trong nón 4 m phía trước, `_shockwave`), Đạn dội (mảnh trúng tường nảy 1 lần, 60%), Nạp bằng cú nhảy (+1 viên / 2 s bay, `_tick_perks`).
- **Bắn tỉa**: Nạp thêm (giữ đủ nạp + 0.6 s = siêu đạn x2, xuyên hết; thả sau khi đủ nạp = phát thường), Tia đánh dấu (laser quét bot lúc nạp -> `hurtbox.damage_taken_mult = 1.4` trong 5 s, mọi nguồn sát thương), Săn liên hoàn (hạ gục bằng bắn tỉa -> 3 s không cần nạp), Nạp trượt (khi `state == SLIDE`: không chậm, nạp -15%/bậc).
- **Pháo**: Nhảy nổ (xung hất bản thân x1.8, `self_push_mult`), Chùm ba (3 tên lửa 45% sát thương / 70% bán kính, tỏa 7 độ), Mìn dính (`sticky`: bám vào bot rồi nổ sau 1 s, `rocket.gd` `_stuck/_fuse/_detonate`), Nổ dây chuyền (bot chết vì nổ -> nổ thêm 50% sát thương / 50% bán kính, tối đa 3 lần, không hại người bắn; `Rocket.explode` giờ trả về danh sách vụ nổ thêm và `_detonate` phát `exploded` cho từng vụ).
- `hurtbox_component.gd`: thêm `damage_taken_mult`. `player_combat.gd`: `_charge_need()` (gộp Săn liên hoàn + Nạp trượt), `_handle_shoot` hỗ trợ Nạp thêm. Lỗi sửa dọc đường: thả chuột trong cửa sổ Săn liên hoàn trước đây để `_charge_lock` kẹt (phải nhấp thả thêm một lần mới nạp được).
- Test: `test_m38` (68 kiểm tra, đo bằng số thật: tỉ lệ sát thương, xung, số tên lửa, độ trễ mìn, chuỗi nổ, giới hạn độ sâu). Cập nhật `test_m36`, `test_m37` (shotgun giờ có kho). Ảnh `docs/screenshots/m38/` (màn chọn thẻ). Pitfall test: dùng `seed()` trước phát shotgun khi so sánh sát thương; bot test cần `set_physics_process(false)` và máu lớn nếu không muốn bị bắn chết.
- **Chưa kiểm bằng người**: cảm giác từng thẻ trên GPU thật; cân bằng số (Cú đá đôi, siêu đạn, mìn dính, chuỗi nổ); Đạn dội và Chùm ba không có hiệu ứng hình riêng (dùng tia/vụ nổ có sẵn); Nạp thêm không có chỉ báo trực quan riêng (vạch nạp vẫn tính theo thời gian nạp thường). SMG/Revolver vẫn chưa làm.

## M39 (nhánh `feature/m39-sword-upgrades`: lỗi kiếm + kho thẻ kiếm — mốc cuối 6/6 của Vô Tận)
- **Lỗi kiếm "Phá thế đỡ"** (`Global.FLAWS["guard_rebound"]`, chỉ bật ở Vô Tận, chỉ người chơi): chém trúng bot đang trong cửa sổ parry -> khựng thêm 0.4 s (tổng 1.4 s thay vì 1.0 s) và bị đẩy lùi 6 m/s (`melee.rebounded` -> `combat.self_impulse` + `sword_rebounded` -> main: tiếng clash + chữ "DỘI!"). Lưu ý: bị parry vẫn cộng thanh Mất thế như cũ nên dễ Destabilized.
- **Kho `sword`** (có sẵn ngay đầu lượt, không phụ thuộc súng; `RunProgress.pools = ["shared","sword","gun:<id>"]`): Mũi nhọn xuyên giáp (bot đang đỡ vẫn nhận +50%/bậc, 2 bậc; lỗi dội vẫn xảy ra), Nhịp phản đòn (`pl.parry.parried` -> `melee.riposte_t` 2 s, cú kế +80% và không bị dội), Lưỡi kiếm lao (giữ chém: lao tới bot gần nhất 1.6-6 m phía trước trong nón `lunge_cone`, hồi 3 s, xong hở 0.3 s; xung = (khoảng cách - 1.6) * ma sát mặt đất vì ma sát hãm theo hàm mũ), Vòng chém (cú thứ 3 liên tiếp, combo reset sau 1.5 s: quét cầu 2.5 m quanh người, 60% sát thương, hất bot ra 8 m/s).
- Thành phần: `melee_hitbox_component.gd` thêm `guard_rebound`, `pierce_guard`, `riposte_t/mult`, `whirl_next`, signal `rebounded`; mặc định tắt nên bot không đổi. `player_combat.gd`: `_tick_sword` (chép hệ số mỗi frame), `_try_lunge`, đếm combo qua `swing_started`. Thông số ở `Global.PERKS` (nhóm "Kiếm"). HUD: nhãn lỗi 2 dòng (lỗi súng + "KIẾM: ...").
- Test: `test_m39` (51 kiểm tra, gồm lao thật đo quãng đường và vòng chém trúng 3 bot quanh người). Pitfall: nhiều lần bị parry làm Destabilized, test phải `pl.instability.reset()`. Cập nhật `test_m36/m37` (pool giờ có "sword", 18 thẻ khi cầm súng lục). Ảnh `docs/screenshots/m39/`.
- **Chưa kiểm bằng người**: cảm giác lao (quãng đường phụ thuộc ma sát/ thực tế có tường chắn), cân bằng số; Vòng chém không có hiệu ứng hình riêng (dùng chém thường); lỗi kiếm với Titan chưa thử riêng. Kế hoạch Vô Tận M34-M39 đã đủ; việc còn lại: chơi thử cân bằng, SMG/Revolver nếu muốn.

## M41 (nhánh `feature/m41-cat-giam`: cắt giảm, bước đầu hướng "lột xác")
- Bỏ: 4 bản đồ cố định (yard/alley/tower/district), chế độ Sinh tồn + Thời gian, wave có nghỉ (`_next_wave`, `break_time`, `wave_started/cleared`, `titans_enabled`, `first_wave`), điểm Sinh tồn (`high_score`, `_scores`, `submit_score`), chọn bản đồ/wave khởi đầu (`selected_map`, `cycle_map`, `start_wave`, `map_changed`, nút trên menu), đồng hồ HUD (`set_timer`), cờ `won` ở màn kết thúc. Xoá ảnh/shoot của M11, M16, M21, M24.
- Tập luyện chuyển sang `Maps.endless(TRAINING.floor)`; khu thử bot theo `Global.TRAINING.slots`, hồi sinh bot đúng ô, phím T Titan, người chơi chết thì hồi sinh (không game over). Menu 4 nút.
- Test: `test_m41` mới; viết lại gọn `test_modes`, `test_maps`; sửa `m21/m23/m24/m27/m31/polish/bots/bot_fixes/smart_bots/...`; khung sân phẳng chỉ cho test (`tools/tests/fixtures/`, `Arena.map_override`).
- Số kiểm tra: **47 suite / 1736 -> 48 suite / ~1606** (giảm do bỏ phần test của map/chế độ đã xoá). Chạy 2 tiến trình thì `test_p1` ("navmesh sẵn sàng sau N khung") đôi khi trượt vì máy bận; chạy riêng thì đạt.
- Chưa kiểm bằng người: cảm giác khu thử bot (khoảng cách các ô 14-24 m, bot đuổi theo người chơi ngay), nút đồ họa/hiệu ứng mới ở Cài đặt, ảnh chụp (các `shoot_*` còn lại chỉ sửa chỗ gọi `waves.start()`, chưa chạy lại).

## Quy trình (từ instruction Project)
Đề xuất → chờ duyệt → nhánh feature + push → chờ "Duyệt" → merge `--no-ff` vào main. Không push `main`. Commit conventional, có trailer Co-Authored-By và Claude-Session.

## Test / công cụ
- `godot --headless --path . --import` rồi `godot --headless --path . -s tools/tests/<tên>.gd` (38 bộ, thêm test_m21..test_m33: test_m18, test_polish, test_modes, test_bot_fixes, test_audio, test_smart_bots, test_feel, test_effects, test_maps, test_weapons, test_m9_movement, test_mannequin_gltf, test_movement, test_advanced_movement, test_combat, test_bots, test_menu_instability, test_materials, test_quality, test_mannequin, test_animation, test_combat_animation, test_viewmodel; đều xanh). Bench: `tools/bench/bench.gd`.
- Ảnh: `xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s tools/screenshots/shoot*.gd -- <thư mục>`.
- Pitfall test `-s`: không `preload` script dùng Global ở đầu file; chờ 2 frame sau teleport; `await process_frame` đầu `_run()`.

## Việc kế tiếp
Hết lộ trình M6-M17. Người dùng tự đóng gói Windows (không làm export trong dự án này). Việc mới: chơi thử rồi chỉnh theo bảng số ở trên; mỗi việc phải đề xuất + chờ duyệt.
