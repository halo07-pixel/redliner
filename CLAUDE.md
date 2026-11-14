# Redliner — hướng dẫn cho Claude (bàn giao dự án)

Game FPS 3D tốc độ cao kiểu Roblox REDLINER, làm bằng **Godot 4.7** (GDScript, renderer GL Compatibility). Một người chơi đấu bot (PvE). Asset là hình nhân dựng bằng khối cơ bản. Chủ dự án: Hoàng, viết tiếng Việt, chơi trên Windows, duyệt bằng tin ngắn ("ok", "gộp", "gộp và tiếp tục"). Trả lời bằng tiếng Việt.

Cập nhật lần cuối: 2026-11-14, `main` đã gộp cả 5 mốc của lộ trình ban đầu. README.md có cách chạy và xuất file.

## Quy trình bắt buộc (5 bước, không được bỏ bước)
1. **Đề xuất:** khi người dùng đưa ý tưởng, KHÔNG viết code, KHÔNG tìm asset. Chỉ mô tả bằng gạch đầu dòng (logic, thuật toán, luồng xử lý). Kết bằng đúng câu: "Bạn có duyệt phương án này để tôi bắt đầu triển khai không?" rồi dừng chờ.
2. **Phê duyệt:** chỉ khi người dùng xác nhận ("Đồng ý", "Triển khai đi", "Chốt", "ok") mới làm tiếp.
3. **Thực thi:** tạo nhánh `feature/<tên>` (hoặc `docs/...`, `fix/...`) từ `main`, viết code, chạy test, chụp ảnh nếu có kết quả hình ảnh, commit, push nhánh. KHÔNG BAO GIỜ push thẳng `main`. Báo file đã đổi rồi nói đúng câu: "Code đã được push lên nhánh [tên nhánh]. Đợi lệnh duyệt gộp nhánh."
4. **Chờ duyệt gộp:** dừng lại đến khi người dùng nhắn "Duyệt", "Merge đi", "gộp"...
5. **Gộp:** `git fetch origin main`, kiểm tra xung đột bằng `git merge-tree --write-tree origin/main <nhánh>`, `git merge --no-ff <nhánh>` vào `main`, push `main`, nhắc người dùng `git pull`.

"Gộp và tiếp tục" = gộp nhánh vừa push rồi đưa đề xuất (bước 1) cho mốc kế tiếp, chờ duyệt.

Commit theo conventional commit (feat/fix/docs/...). Commit và PR kết bằng các dòng attribution mà phiên làm việc yêu cầu (thường `Co-Authored-By: Claude ... <noreply@anthropic.com>` và `Claude-Session: <url>`).

### Chống ngụy biện (không được dùng lý do nào để bỏ quy tắc)
- Logic vật lý chỉ nằm trong `_physics_process`; UI, âm thanh, hiệu ứng nhận qua Signal hoặc hàm riêng. Không gộp chung cho "nhanh".
- Nguyên tắc Godot "call down, signal up": không dùng `get_parent().get_parent()`; node giao tiếp bằng Signal. Component nhận phụ thuộc qua `setup()`.
- Không đoán mò offset để sửa lỗi hitbox: tìm pattern chuẩn (Hitbox Component) và vạch luồng logic trước.
- Sửa một dòng nhỏ cũng không push thẳng `main`.
- Giữ code ít nhất có thể, test headless cho logic mới, số cân bằng đặt ở `Global`, không rải trong logic.

## Trạng thái các mốc (đều đã gộp vào main)
1. Khung dự án: đấu trường dựng bằng code, người chơi FPS (`CharacterBody3D`), di chuyển kiểu Quake không trần tốc độ (giữ động lượng, air-strafe), hình nhân, HUD.
2. Di chuyển nâng cao: slide (Ctrl), dash (Shift, 2 charge), wallrun (raycast hai bên), grapple (chuột phải, lực kéo tăng dần, giữ quán tính). Máy trạng thái `State {NORMAL, SLIDE, WALLRUN, GRAPPLE}`.
3. Chiến đấu: kiếm (chuột trái; windup, active, recovery), súng tia tức thì (E, băng 6, R nạp), parry (F, cửa sổ 0.18s; phản đạn đổi chủ nhân 2.5 sát thương, đòn kiếm làm choáng 1s; hụt bị phạt 0.8s), clash (hai kiếm cùng active), máu và chết. Pattern component trong `scripts/components/`.
4. Bot AI + wave + điểm: ba loại bot (lính kiếm đỏ, xạ thủ cam, tinh nhuệ tím) trong `Global.BOTS`; wave 1 toàn lính kiếm, từ wave 2 có xạ thủ, từ wave 3 có tinh nhuệ, tối đa 10 bot, nghỉ 4s; điểm 100/150/300, combo +10% (tối đa x2, cửa sổ 4s), phản đạn x2, hạ bot đang choáng x1.5.
5. Menu, HUD, hoàn thiện: menu chính + hướng dẫn, tạm dừng (Esc), màn tổng kết khi chết, điểm cao lưu `user://savegame.cfg`, Instability/Redline (số trong `Global.INSTABILITY`), HUD đầy đủ, nhạc nền + âm thanh tổng hợp bằng code, hạt tia lửa, FOV theo tốc độ, `export_presets.cfg` Windows.

## Bản đồ code (`scripts/`)
- `global.gd` (autoload): layer vật lý, `TEAM_*`, bảng số `PLAYER` / `COMBAT` / `BOTS` / `INSTABILITY`, input map tạo bằng code, hitstop, lưu điểm cao.
- `sfx.gd` (autoload): âm thanh và nhạc nền tổng hợp bằng code. Chỉ `main.gd` gọi, logic game không gọi trực tiếp.
- `player.gd` + `scenes/player.tscn`, `player_combat.gd`, `components/` (`hurtbox_component.gd`, `melee_hitbox_component.gd`, `parry_component.gd`), `bullet.gd`, `instability.gd`.
- `bot.gd`, `wave_manager.gd`, `score_manager.gd`, `enemy_dummy.gd` (bia tập, dùng trong test).
- `main.gd` (nối Signal, tạm dừng, game over), `hud.gd`, `menu.gd`, `pause_menu.gd`, `game_over.gd`, `ui_kit.gd`.
- `arena.gd`, `mannequin.gd`, `sword_view.gd`, `grapple_rope.gd`, `fx.gd`.
- `tools/tests/` (test headless), `tools/screenshots/` (chụp ảnh), `docs/screenshots/` (ảnh các mốc).

## Test và công cụ
- 5 bộ test headless, đều xanh ở `main`: `test_movement.gd`, `test_advanced_movement.gd`, `test_combat.gd`, `test_bots.gd`, `test_menu_instability.gd` trong `tools/tests/`.
  Chạy: `godot --headless --path . -s tools/tests/<tên>.gd` (đặt `timeout`, ghi ra file; script lỗi trong coroutine làm treo).
- Phiên cloud không có sẵn Godot: tải **Godot 4.7 Linux x86_64** từ godot-builds trên GitHub (`godotengine/godot-builds`, tag `4.7-stable`), giải nén, kiểm tra `--headless --version`. Chạy `--headless --import` trước khi test lần đầu hoặc sau khi thêm file.
- Chụp màn hình dưới Xvfb: `xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s tools/screenshots/<shoot*.gd> -- docs/screenshots` (các script `shoot.gd`, `shoot_combat.gd`, `shoot_bots.gd`, `shoot_m5.gd`). Script chụp đặt `main.autostart_waves = false` để tự điều khiển wave.
- Pitfall khi viết test chạy bằng `-s`:
  - Không `preload` script có dùng `Global` ở đầu file test; dùng `load()` lúc chạy.
  - Chỉ hằng số `Global.X` dùng trực tiếp được; biến và hàm của autoload phải lấy qua `root.get_node("Global")`.
  - Sau khi teleport nhân vật phải chờ 2 frame trước khi đặt `velocity` (cờ `is_on_floor` còn của frame trước).
  - Chờ `await process_frame` đầu `_run()` trước khi đụng tới autoload.
- Stop-hook "unpushed commit" thường báo nhầm vì clone nông: kiểm tra `git ls-remote origin <nhánh>` rồi `git fetch origin <nhánh>:refs/remotes/origin/<nhánh>`.

## Điểm khác phương án và giới hạn đã biết (nói thẳng với người dùng khi liên quan)
- Bot không dùng navmesh: bám theo hướng người chơi + né tường bằng raycast. Lính kiếm không leo bục cao được.
- Chết là kết thúc lượt chơi (màn tổng kết, nút Chơi lại / Về menu), không hồi sinh tự động. `Player.respawn()` vẫn còn nếu muốn bật lại.
- Instability/Redline là thiết kế riêng, không phải cơ chế gốc của REDLINER (chưa rõ).
- `export_presets.cfg` chưa kiểm chứng (cần Export Templates 4.7 trên máy người dùng).
- Chưa kiểm bằng người: cảm giác di chuyển, độ khó bot, nhạc và âm thanh, hiệu năng hạt, hitstop (`Engine.time_scale`).
- Hình nhân là placeholder; kiếm và súng cầm tay chỉ là hộp.

## Việc có thể làm tiếp (chưa chọn, mỗi việc phải đề xuất rồi chờ duyệt)
Chỉnh cân bằng sau khi người dùng chơi thử (`Global.BOTS`, `Global.COMBAT`, `Global.PLAYER`, `Global.INSTABILITY`); thêm loại bot hoặc bản đồ mới; thay hình nhân bằng mô hình đẹp hơn (asset phải rõ giấy phép, ghi `CREDITS.md`); navmesh cho bot; bản build Windows; dọn các nhánh `feature/*` đã gộp trên remote (chỉ đề nghị, không tự xoá).
