# Tài nguyên ngoài (assets)

| Asset | Nguồn | Giấy phép | Dùng cho |
|---|---|---|---|
| KayKit – Adventurers 1.0 (`Knight`, `Barbarian`, `Rogue_Hooded`) | https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0 | CC0 1.0 (tác giả Kay Lousberg) | Bot: kiếm sĩ = Knight, tinh anh = Barbarian, xạ thủ = Rogue_Hooded |

- Giấy phép gốc: `assets/characters/kaykit/LICENSE.txt` (CC0: dùng/sửa/phát hành thoải mái, không bắt buộc ghi nguồn; vẫn ghi ở đây).
- Mỗi model ~3.6 MB; 76 clip hoạt ảnh dựng sẵn. Chỉ lấy 3 nhân vật cần dùng (không lấy Mage…).
- Mã dùng asset: `scripts/mannequin_gltf.gd` (cùng API với `mannequin.gd`). Thiếu file asset → bot tự dùng hình nhân khối (`mannequin.gd`).
- Người chơi vẫn dùng hình nhân khối vì thân chỉ hiện qua bóng đổ (camera ẩn layer 2).
- Quy ước: thêm asset mới phải ghi vào bảng trên kèm nguồn và giấy phép; chỉ dùng CC0/CC-BY.
