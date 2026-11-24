# P2 — Chủ đề môi trường theo tầng Vô Tận (nhánh `feature/p2-floor-themes`)

6 chủ đề (ngày, bình minh, hoàng hôn, đêm, mưa bụi, sương tím), lặp vòng theo tầng (`EndlessLook.theme_index`). Chỉ đổi trời / nắng / sương / ánh sáng nền / màu viền sáng; không đổi bố cục, va chạm, navmesh.
- `scripts/endless_look.gd`: bảng `THEMES`, `MIN_SUN`/`MIN_AMBIENT` (sàn độ sáng, đêm vẫn thấy bot), `THEME_BLEND_SEC`; `theme_env`, `blend_env`; `dress(m, theme)` nhận màu viền theo chủ đề.
- `scripts/arena.gd`: `_apply_theme(smooth)` (Tween; tức thì khi `reduced_fx`), gọi sau khi dựng map Vô Tận và sau `load_floor`. Giữ hệ số sương 0.6 của Vô Tận. Map khác không bị đổi.
- Không đụng `global.gd`, `main.gd`, `hud.gd`, `player*.gd`. Test `test_p2` (15 kiểm tra), ảnh `docs/screenshots/p2/` (tầng 1-6).
- Chưa kiểm bằng người: màu/độ sương trên GPU thật; hoàng hôn khá tối ở mặt đất; chỉnh số ở `THEMES`.
