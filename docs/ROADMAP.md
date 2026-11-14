# Lộ trình Redliner (M6 → M17)

Thứ tự: M6 → M7 → M8 → M9 → M10 → M11 → M12 → M13 → M14 → M15 → M16 → M17.
Quy trình: đề xuất → duyệt → nhánh `feature/mX-Y-ten` → push → chơi thử → "Duyệt" → gộp vào `main`. Không push thẳng `main`.

Đã chốt: Renderer Forward+; Instability đổi sang "mất thế / Destabilized" (M8); làm cả M9 (di chuyển nâng cao) và M10 (4 súng); mốc đầu là M6.

## Giai đoạn 1: Nền hình ảnh
- **M6 Ánh sáng và vật liệu:** 6.1 môi trường (mặt trời + bóng, sky, fog, tonemap, glow) · 6.2 bộ vật liệu và bảng màu · 6.3 tùy chọn chất lượng Thấp/Vừa/Cao.
- **M7 Nhân vật và hoạt ảnh:** 7.1 mô hình bằng code · 7.2 hoạt ảnh thân · 7.3 hoạt ảnh chiến đấu · 7.4 tay góc nhìn thứ nhất.

## Giai đoạn 2: Cơ chế lõi
- **M8 Instability "mất thế":** thanh tăng khi thua clash/parry hụt/bị parry; vượt 100% → Destabilized vài giây (không tấn công/parry, stamina dash về 0), áp dụng cả bot; clash nâng cấp; HUD + hiệu ứng.
- **M9 Di chuyển nâng cao:** slide boost/slide hop, stamina dash, grapple redirect, ground slam, recoil movement.
- **M10 Kho vũ khí:** hệ thống đổi súng; súng lục, pháo nổ, shotgun nòng đôi, bắn tỉa; chém rộng; hiệu ứng súng.

## Giai đoạn 3: Thế giới
- **M11 Bản đồ:** bộ khối dựng map, địa hình di chuyển, 3 đấu trường, trang trí, chọn map.
- **M12 Vật thể và hiệu ứng:** vệt kiếm, tia lửa, sóng parry, vật nhặt, thùng bể; công tắc giảm hiệu ứng.

## Giai đoạn 4: Cảm giác và đối thủ
- **M13 Cảm giác điều khiển:** camera, coyote time, trèo gờ, âm bước chân, cài đặt phím/tay cầm.
- **M14 Bot thông minh:** navmesh, loại bot mới, bot dùng Instability, đường cong độ khó.

## Giai đoạn 5: Hoàn thiện
- **M15 Âm thanh và nhạc**, **M16 Giao diện và chế độ chơi**, **M17 Tối ưu và đóng gói** (Windows export cần Export Templates 4.7).

## Quy tắc chung
Vật lý trong `_physics_process`; UI/âm thanh/hiệu ứng nghe Signal ("call down, signal up"); số cân bằng ở `Global`; asset dựng bằng code; chỉ học nguyên tắc cơ chế REDLINER, tên/hình dáng tự đặt.
Cảm giác di chuyển, độ khó, âm thanh cần người chơi thử.
