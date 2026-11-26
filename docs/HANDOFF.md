# Bàn giao Redliner (gọn; cập nhật sau M41)

Godot 4.7, GDScript. FPS 3D một người chơi đấu bot, lấy cảm hứng Roblox REDLINER: kiếm + đỡ đòn (parry) + súng, lướt/dash/grapple/trèo gờ. Repo `halo07-pixel/redliner`. Lịch sử từng mốc chi tiết: `docs/HANDOFF_HISTORY.md`. Nguồn asset/giấy phép: `docs/ASSETS.md`.

## Hướng "lột xác" (người dùng chốt 2026-11-25; mỗi mốc cần đề xuất riêng + "Ok")
Tối giản game, giữ "bộ não" (chiến đấu, di chuyển, bot AI, Vô Tận, dữ liệu, test), làm lại "da": **một bản đồ (lưới Vô Tận)**, **chế độ Vô Tận + Tập luyện**, model dựng lại bằng **Blender low poly**, hoạt ảnh mượt hơn làm trong Blender. Lộ trình: **M41 Cắt giảm (xong, xem dưới)** -> M42 chuẩn low poly + kiếm (bảng màu `PALETTE`, shading phẳng, ngân sách tam giác, quy ước `.glb`: mét, tên khớp 15 khớp proxy, điểm gắn nòng/tay cầm) -> M43 4 súng + viewmodel -> M44 bot + Titan trên khung xương 15 khớp -> M45 map Vô Tận (mô-đun toà nhà, cột, cổng) -> M46 vật phẩm/hiệu ứng/ánh sáng -> M47 hoạt ảnh Blender (rút, chém, parry, nạp, choáng, ngã). Hitbox vẫn bật bằng bộ đếm theo `Global.COMBAT`; clip Blender phải khớp các hằng số windup/active/recovery.

## M41 Cắt giảm (đã làm)
- Chỉ còn 2 chế độ: `Global.MODES = ["endless", "training"]`; bỏ Sinh tồn, Thời gian, 4 bản đồ cố định (yard/alley/tower/district), wave có nghỉ (`WaveManager` chỉ còn `stream` Vô Tận + sinh lẻ cho Tập luyện), điểm Sinh tồn (`high_score`), chọn bản đồ/chọn wave khởi đầu. Savegame cũ ghi mode survival/timed hoặc khoá `map` vẫn nạp được (mode -> Vô Tận; khoá thừa bị bỏ).
- Tập luyện chạy trên `Maps.endless(TRAINING.floor)` (hạt giống cố định, không cổng, không XP/vàng/thẻ, mở đủ 4 súng + kiếm, không lỗi súng, bất tử như cũ). Khu thử bot cạnh chỗ xuất phát: `Global.TRAINING.slots` = loại bot + độ lệch (x, z): lính kiếm, xạ thủ, pháo thủ bom; bot chết thì hồi sinh đúng ô sau `respawn_time` (meta `practice_slot`/`practice_home`). Phím T gọi/xoá Titan ở `titan_offset`. Người chơi chết: hồi sinh ở chỗ xuất phát sau `player_respawn`, không có màn kết thúc (`main._respawn_in_training`).
- Menu chính 4 nút: Chơi (màn Chuẩn bị: chế độ, độ khó, súng khởi đầu, Hướng dẫn) / Cửa hàng / Cài đặt (thêm nút đồ họa + hiệu ứng) / Thoát.
- Test: khung "sân phẳng" chỉ cho test (`tools/tests/fixtures/flat_arena.gd` + `map_fixture.gd`, qua `Arena.map_override`) để test cơ chế không phụ thuộc bản đồ 300 m; game thật không dùng `map_override`. Code vật phá được/bia tập của `Arena` còn lại chỉ để các test đó dùng (bản đồ Vô Tận không có thùng/bia). `test_m41` mới.

## Quy trình làm việc (bắt buộc)
Đề xuất (chưa viết code) -> chờ "Ok" -> nhánh `feature/...` + push -> báo file đổi -> chờ "Duyệt/Gộp" -> merge `--no-ff` vào `main` -> bảo người dùng `git pull`. KHÔNG push `main`. Vật lý ở `_physics_process`; UI/âm thanh/hiệu ứng qua Signal ("call down, signal up", không `get_parent().get_parent()`); không đoán offset hitbox; không thêm bảng chỉnh/menu chỉnh mới (hằng số ở `Global`/`scripts/data`). Commit có trailer Co-Authored-By + Claude-Session.

## Chạy và kiểm thử
- Cần Godot 4.7-stable (cloud: tải `Godot_v4.7-stable_linux.x86_64.zip` từ GitHub `godotengine/godot-builds` tag `4.7-stable` vào `/opt/godot47`, symlink `godot`). Cloud không có GPU/Vulkan/âm thanh: chỉ kiểm logic bằng số và ảnh tĩnh (renderer GL dự phòng); FPS, cảm giác, âm thanh cần người chơi thử.
- Import: `godot --headless --path . --import`. Một suite: `godot --headless --path . -s tools/tests/<tên>.gd`. Toàn bộ, song song: `tools/run_tests.sh [số tiến trình] [tiền tố]` (48 suite, xem số kiểm tra ở lịch sử M41; thoát 1 nếu có lỗi). Vài test đo số khung navmesh (`test_p1`) có thể trượt khi máy bận: chạy lại riêng.
- Ảnh tĩnh: `xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s tools/screenshots/shoot_<x>.gd -- docs/screenshots/<x>`. Chỉ giữ ảnh các mốc gần đây (M19+), đã nén bảng màu 256.
- Cảnh báo "ObjectDB instances were leaked at exit" (AudioStreamWAV) khi thoát headless là vô hại.
- Pitfall test `-s`: `await process_frame` đầu `_run()`; không `preload` script dùng Global ở đầu file; đọc biến (không phải const) của Global qua `root.get_node("Global")`; navmesh đồng bộ chậm ~10-20 khung sau khi dựng; bot trong test cần `set_physics_process(false)` và máu lớn; nhiều lần bị parry gây Destabilized nên test phải `pl.instability.reset()`; so sánh đạn tản cần `seed()`.

## Dữ liệu (một nơi, chỉ chỉnh số ở đây)
`scripts/global.gd` (autoload `Global`: tầng va chạm, cài đặt, savegame, phím, tuning sống) nạp lại hằng từ `scripts/data/`; mã khác vẫn gọi `Global.TÊN`:
- `combat_data.gd`: `INSTABILITY, COMBAT, WEAPONS, WEAPON_ORDER, FLAWS, PERKS, GOLD, HEAVY_SLASH, FX, PICKUPS, BREAKABLES`.
- `bot_data.gd`: `BOTS, BOMB, DIFFICULTY*`. `player_data.gd`: `PLAYER, MOTION(_PRESETS), TITAN, BOT_MOVE` (gốc; `Global` giữ bản sao `var` chỉnh sống được qua `set_live`/`tuning.cfg`).
- `visual_data.gd`: `PALETTE, MATERIAL_PARAMS, QUALITY*, ENV, RIG, SKIN_COLOR, ANIM, VIEWMODEL`. `mode_data.gd`: `MODES, XP, UPGRADES (kho thẻ), ENDLESS, TRAINING`. `audio_data.gd`: `SOUNDS, AUDIO*, SURFACES`.
- File data không được tham chiếu `Global` (vòng phụ thuộc lúc biên dịch).
- Tuning sống: F3 (số liệu) rồi F4 (`anim_tuner.gd`, chỉnh hoạt ảnh/di chuyển/Titan). Người dùng thấy F4 rườm rà: không mở rộng.

## Kiến trúc nhanh
- Cảnh: `scenes/main.tscn` (`main.gd` nối mọi Signal, điều phối), `menu.tscn`, `player.tscn`. Người chơi: `player.gd` (di chuyển, trạng thái SLIDE/WALLRUN/GRAPPLE/LEDGE/SLAM), `player_combat.gd` (súng, kiếm, lỗi, thẻ), `viewmodel.gd` (tay/vũ khí góc nhìn thứ nhất, lò xo), `components/` (hurtbox, melee_hitbox, parry...), `instability.gd` (thanh Mất thế -> Destabilized).
- Bot: `bot.gd` (navmesh, bọc sườn, giới hạn 3 bot cận chiến, nấp, né, parry), `titan.gd`, `wave_manager.gd` (`stream` cho Vô Tận; `spawn_practice`/`spawn_titan_practice` cho Tập luyện), `rig_animator.gd` + `mannequin(_gltf).gd` (khung xương proxy + IK `rig_ik.gd`).
- Thế giới: `arena.gd` (dựng map từ `maps.gd`, navmesh, môi trường theo `Quality`), `maps.gd` (chỉ `endless(tầng)`), `breakable.gd`, `pickup.gd`, `rocket.gd` (nổ tĩnh `Rocket.explode`, trả về chuỗi nổ dây chuyền).
- Chế độ: `game_mode.gd` (Vô Tận / Tập luyện; chỉ phát Signal), `run_stats.gd`.
- UI: `hud.gd`, `ui_kit.gd`, `menu.gd`, `shop_menu.gd`, `settings_menu.gd`, `pause_menu.gd`, `level_up_ui.gd`, `game_over.gd`. Âm: `sfx.gd` (autoload, âm tổng hợp bằng code, nhạc 3 lớp).

## Chế độ Vô Tận (M34-M39)
- Tầng vô hạn trên lưới 6x6 ô 50 m (`Maps.endless(n)`, hạt giống theo tầng); chỉ tiêu 15 + 5/tầng; cổng ở góc đối diện mở khi đủ chỉ tiêu (Titan mỗi 5 tầng phải hạ). `Arena.load_floor`, `portal.gd`, `GameMode.next_floor`, `WaveManager.begin_floor` + vòng sinh 40-80 m, gỡ bot xa.
- Cấp độ kiểu Vampire Survivors: `run_progress.gd` (xp, cấp, thẻ đã lấy, kho thẻ `shared` + `sword` + `gun:<id>`), `upgrades.gd` (rút ba thẻ), `xp_orb.gd`, `level_up_ui.gd`. Thẻ cộng % dùng `kind` mult/add; thẻ đổi cơ chế có `effect` (chữ hiện thay số). `main._apply_upgrades` chép stat vào `combat.weapon_mods`/hệ số người chơi.
- Vàng và cửa hàng: vàng lưu trong savegame `[meta]` (mỗi tầng 8 + 4/tầng, +1/bot, +30/Titan; chép vào tổng khi đổi tầng/kết thúc/thoát, idempotent). Mua súng ở "Cửa hàng" (Shotgun 150, Bắn tỉa 300, Pháo 500; súng lục miễn phí), chọn súng khởi đầu ở màn Chuẩn bị; Vô Tận chỉ cầm súng khởi đầu + kiếm (`combat.locked`).
- Mỗi vũ khí một lỗi riêng, chỉ bật ở Vô Tận (`gun_flaws.gd`, `Global.FLAWS`): súng lục giật theo nhịp, shotgun giật bật người, bắn tỉa nạp ngắm 0.8 s, pháo tự chịu nổ 60%, kiếm "Phá thế đỡ" (chém trúng bot đang đỡ: khựng 1.4 s + bị đẩy lùi). Thẻ không bao giờ gỡ hẳn lỗi.
- Kho thẻ riêng: súng lục 4, shotgun 4, bắn tỉa 4, pháo 4, kiếm 4 (Cú đá đôi, Sóng xung kích, Đạn dội, Nạp bằng cú nhảy; Nạp thêm, Tia đánh dấu, Săn liên hoàn, Nạp trượt; Nhảy nổ, Chùm ba, Mìn dính, Nổ dây chuyền; Mũi nhọn xuyên giáp, Nhịp phản đòn, Lưỡi kiếm lao, Vòng chém). Thông số ở `Global.PERKS`. Thêm thẻ = một dòng trong `UPGRADES` + logic đọc `weapon_mods["<stat>"]`.
- Thêm súng mới: dữ liệu `WEAPONS` (kèm `flaw`), nhánh trong `gun_flaws.gd`, giá `GOLD.prices`, kho `gun:<id>`, mẫu súng ở viewmodel/HUD, test.

## Chưa kiểm bằng người (cần chơi thử trên máy có GPU)
FPS thật (bản đồ 300 m, 14 bot + bóng), nhịp lên cấp, giá cửa hàng, cảm giác từng lỗi và thẻ (đặc biệt giật shotgun, nạp ngắm bắn tỉa, lao kiếm, chuỗi nổ), âm thanh, tay cầm, cảm giác parry/viewmodel, cân bằng độ khó. Vòng chém/Đạn dội/Chùm ba/Nạp thêm chưa có hiệu ứng hình riêng. Bot không phản ứng với laser bắn tỉa.

## Việc có thể làm tiếp
Chơi thử rồi chỉnh số; SMG/Revolver cùng lỗi riêng; CI chạy `tools/run_tests.sh` trên GitHub; người dùng tự đóng gói Windows (không có export trong repo).
