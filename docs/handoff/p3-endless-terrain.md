# P3 — Địa hình Vô Tận + sửa navmesh lẫn collider tầng cũ (nhánh `feature/p3-endless-terrain`)

## Địa hình (chỉ map Vô Tận)
- Mỗi tầng 3 "sân khấu" đặt vào ô trống: bệ 16×16×2 m (vai trò `platform`), 2 dốc xanh (14°, vai trò `ramp`) hai phía, 2 bức che cao 1,4 m. Hằng số ở `Maps.TERRAIN` (maps.gd), không đụng `global.gd`.
- Sinh bằng bộ số ngẫu nhiên RIÊNG (hạt giống lệch 101) và dựng sau toà nhà/cột nên bố cục cũ, chỗ xuất phát, cổng không đổi. Không đặt ở ô xuất phát/cổng. Mọi khối lùi >= 8 m trong ô nên phố vẫn thông.
- `endless_look.gd`: viền sáng quanh mặt trên bệ/bức che. Test M34 cập nhật tập vai trò.
- Bỏ khỏi đề xuất ban đầu: hào cạn (cần khoét sàn, rủi ro navmesh) — chưa làm.

## Lỗi thật tìm thấy và sửa (có từ M34)
`Arena.load_floor` dùng `queue_free` rồi nướng navmesh ngay, nên collider TẦNG CŨ còn trong cây bị nướng vào navmesh tầng mới (tầng 6: 1898 đa giác thay vì 1131; xuất phát và cổng bị tách rời, `nav_path` cụt 335 m). Sửa: `remove_child` ngay trước khi `queue_free`. Bake nhanh hơn (~85 ms thay vì ~130 ms). `nav_ready()` giờ yêu cầu cả vùng đã được máy chủ nhận (iteration > 0) và đường thật sự tới cổng (đường thông riêng không đủ vì dữ liệu cũ có thể tình cờ tới góc cổng mới).

## Số đo / kiểm tra
test_p3: dữ liệu 12 tầng, raycast độ cao dốc đúng tuyến tính, navmesh có trên mặt bệ, đường tới cổng tầng 1-8, navmesh sau load_floor khớp dựng mới. Sẵn sàng sau 2-15 khung.
Chưa kiểm bằng người: cảm giác chạy/nhảy lên dốc, bot leo bệ trong trận thật.
