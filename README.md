# Redliner

Game FPS 3D tốc độ cao (lấy cảm hứng từ REDLINER trên Roblox) làm bằng **Godot 4.7**.
Chế độ: một người chơi đấu với bot (PvE). Asset tạm: hình nhân 3D dựng bằng khối cơ bản.

## Chạy
Mở thư mục bằng Godot 4.7 rồi nhấn F5. Điều khiển: `WASD` di chuyển, `Space` nhảy, `Ctrl` trượt, `Shift` dash, chuột phải móc (grapple), chuột trái chém kiếm, `E` bắn súng, `1-4`/cuộn chuột đổi súng (súng lục, shotgun, pháo nổ, bắn tỉa), `Q` chém rộng, `Z` ngắm (bắn tỉa), `C` đập đất, `F` parry, `R` nạp đạn, `T` gọi/xoá Titan tập (chế độ Tập luyện), `F3` bảng FPS và `F4` bộ chỉnh thông số trực tiếp (lưu được), `Esc` tạm dừng, chuột nhìn, `Esc` nhả chuột. Chạy sát tường khi đang trên không để bám tường.

## Test headless
```
godot --headless --path . -s tools/tests/test_movement.gd
godot --headless --path . -s tools/tests/test_advanced_movement.gd
godot --headless --path . -s tools/tests/test_combat.gd
godot --headless --path . -s tools/tests/test_bots.gd
godot --headless --path . -s tools/tests/test_menu_instability.gd
godot --headless --path . -s tools/tests/test_polish.gd
```
(Có 22 bộ trong `tools/tests/`.) Đo hiệu năng script: `godot --headless --path . -s tools/bench/bench.gd -- 4`. Bàn giao và bảng số cần chỉnh: `docs/HANDOFF.md`.

Chụp màn hình (cần Xvfb): `xvfb-run -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s tools/screenshots/shoot.gd -- docs/screenshots`

## Lộ trình
1. Khung dự án + di chuyển cơ bản (xong)
2. Di chuyển nâng cao: slide, dash, wallrun, grapple (xong)
3. Chiến đấu: kiếm, súng, parry/clash (xong)
4. Bot AI + wave + điểm (xong)
5. Menu, HUD, Instability "mất thế", âm thanh, hiệu ứng (xong)
6. M6-M17: đồ họa, nhân vật, vũ khí, bản đồ, bot thông minh, âm thanh, chế độ chơi, hoàn thiện (xong, v1.0.0)

## Cơ chế Instability "mất thế"
Thanh Instability tăng khi thua clash (kiếm chạm kiếm), parry hụt hoặc bị đối phương parry; bớt khi parry thành công hoặc đánh trúng, và tự giảm dần khi không bị cộng thêm.
Đầy thì **Destabilized** 3 giây: không đánh, không parry, không bắn, stamina dash về 0. Áp dụng cho cả bot. Mọi số chỉnh trong `Global.INSTABILITY`.

## Xuất file chạy (Windows)
Đã có sẵn `export_presets.cfg` (preset "Windows Desktop", xuất ra `build/Redliner.exe`).
Cần cài **Export Templates** của Godot 4.7 (Editor > Manage Export Templates), rồi
Project > Export > Windows Desktop > Export Project. Điểm cao nhất lưu ở `user://savegame.cfg`.
