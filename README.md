# Redliner

Game FPS 3D tốc độ cao (lấy cảm hứng từ REDLINER trên Roblox) làm bằng **Godot 4.7**.
Chế độ: một người chơi đấu với bot (PvE). Asset tạm: hình nhân 3D dựng bằng khối cơ bản.

## Chạy
Mở thư mục bằng Godot 4.7 rồi nhấn F5. Điều khiển: `WASD` di chuyển, `Space` nhảy, chuột nhìn, `Esc` nhả chuột.

## Test headless
```
godot --headless --path . -s tools/tests/test_movement.gd
```

## Lộ trình
1. Khung dự án + di chuyển cơ bản (hiện tại)
2. Di chuyển nâng cao (slide, dash, wallrun, grapple)
3. Chiến đấu (kiếm, súng, parry/clash)
4. Bot AI + wave + điểm
5. HUD + hoàn thiện
