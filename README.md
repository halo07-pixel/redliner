# Redliner

Game FPS 3D tốc độ cao (lấy cảm hứng từ REDLINER trên Roblox) làm bằng **Godot 4.7**.
Chế độ: một người chơi đấu với bot (PvE). Asset tạm: hình nhân 3D dựng bằng khối cơ bản.

## Chạy
Mở thư mục bằng Godot 4.7 rồi nhấn F5. Điều khiển: `WASD` di chuyển, `Space` nhảy, `Ctrl` trượt, `Shift` dash, chuột phải móc (grapple), chuột trái chém kiếm, `E` bắn súng, `F` parry, `R` nạp đạn, `Esc` tạm dừng, chuột nhìn, `Esc` nhả chuột. Chạy sát tường khi đang trên không để bám tường.

## Test headless
```
godot --headless --path . -s tools/tests/test_movement.gd
godot --headless --path . -s tools/tests/test_advanced_movement.gd
godot --headless --path . -s tools/tests/test_combat.gd
godot --headless --path . -s tools/tests/test_bots.gd
godot --headless --path . -s tools/tests/test_menu_instability.gd
```

Chụp màn hình (cần Xvfb): `xvfb-run -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s tools/screenshots/shoot.gd -- docs/screenshots`

## Lộ trình
1. Khung dự án + di chuyển cơ bản (xong)
2. Di chuyển nâng cao: slide, dash, wallrun, grapple (xong)
3. Chiến đấu: kiếm, súng, parry/clash (xong)
4. Bot AI + wave + điểm (xong)
5. Menu, HUD, Instability/Redline, âm thanh, hiệu ứng (hiện tại)

## Cơ chế Instability / Redline
Thanh Instability đầy dần khi chạy nhanh (> 14 m/s), đánh kiếm trúng và parry thành công; mất bớt khi bị đánh.
Đầy thì vào **Redline** 6 giây: sát thương x1.5, dash hồi nhanh gấp đôi. Mọi số chỉnh trong `Global.INSTABILITY`.

## Xuất file chạy (Windows)
Đã có sẵn `export_presets.cfg` (preset "Windows Desktop", xuất ra `build/Redliner.exe`).
Cần cài **Export Templates** của Godot 4.7 (Editor > Manage Export Templates), rồi
Project > Export > Windows Desktop > Export Project. Điểm cao nhất lưu ở `user://savegame.cfg`.
