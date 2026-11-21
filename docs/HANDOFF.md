# Bàn giao Redliner (cập nhật 2026-11-20)

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

## Quy trình (từ instruction Project)
Đề xuất → chờ duyệt → nhánh feature + push → chờ "Duyệt" → merge `--no-ff` vào main. Không push `main`. Commit conventional, có trailer Co-Authored-By và Claude-Session.

## Test / công cụ
- `godot --headless --path . --import` rồi `godot --headless --path . -s tools/tests/<tên>.gd` (26 bộ, thêm test_m21: test_m18, test_polish, test_modes, test_bot_fixes, test_audio, test_smart_bots, test_feel, test_effects, test_maps, test_weapons, test_m9_movement, test_mannequin_gltf, test_movement, test_advanced_movement, test_combat, test_bots, test_menu_instability, test_materials, test_quality, test_mannequin, test_animation, test_combat_animation, test_viewmodel; đều xanh). Bench: `tools/bench/bench.gd`.
- Ảnh: `xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s tools/screenshots/shoot*.gd -- <thư mục>`.
- Pitfall test `-s`: không `preload` script dùng Global ở đầu file; chờ 2 frame sau teleport; `await process_frame` đầu `_run()`.

## Việc kế tiếp
Hết lộ trình M6-M17. Người dùng tự đóng gói Windows (không làm export trong dự án này). Việc mới: chơi thử rồi chỉnh theo bảng số ở trên; mỗi việc phải đề xuất + chờ duyệt.
