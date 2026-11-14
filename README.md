# Redliner

Game FPS 3D tốc độ cao (lấy cảm hứng từ REDLINER trên Roblox) làm bằng **Godot 4.7**.
Chế độ: một người chơi đấu với bot (PvE). Asset tạm: hình nhân 3D dựng bằng khối cơ bản.

## Chạy
Mở thư mục bằng Godot 4.7 rồi nhấn F5. Điều khiển: `WASD` di chuyển, `Space` nhảy, `Ctrl` trượt, `Shift` dash, chuột phải móc (grapple), chuột trái chém kiếm, `E` bắn súng, `F` parry, `R` nạp đạn, chuột nhìn, `Esc` nhả chuột. Chạy sát tường khi đang trên không để bám tường.

## Test headless
```
godot --headless --path . -s tools/tests/test_movement.gd
godot --headless --path . -s tools/tests/test_advanced_movement.gd
godot --headless --path . -s tools/tests/test_combat.gd
godot --headless --path . -s tools/tests/test_bots.gd
```

Chụp màn hình (cần Xvfb): `xvfb-run -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s tools/screenshots/shoot.gd -- docs/screenshots`

## Lộ trình
1. Khung dự án + di chuyển cơ bản (xong)
2. Di chuyển nâng cao: slide, dash, wallrun, grapple (xong)
3. Chiến đấu: kiếm, súng, parry/clash (xong)
4. Bot AI + wave + điểm (hiện tại)
5. HUD + hoàn thiện
