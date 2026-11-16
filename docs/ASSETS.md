# Tài nguyên ngoài (assets)

| Asset | Nguồn | Giấy phép | Dùng cho |
|---|---|---|---|
| GodoDude Mannequin (`assets/characters/godo/GodoDude.gltf`) | https://github.com/WuotanStudios/GodoDudeMannequin | MIT (WuotanStudios), `assets/characters/godo/LICENSE.txt` | Thân người que của bot (đã rig, 67 xương) |
| Quaternius – Medieval Weapons Pack (`Sword`, `Axe_Double`, `Dagger` FBX) | https://quaternius.com (bản sao trong repo `beep2bleep/FreeAssetsByKenneyNLandQuaternius`) | CC0 1.0, `assets/weapons/quaternius/LICENSE.txt` | Kiếm (kiếm sĩ), rìu đôi (tinh anh) |
| HoneyBadger (`assets/weapons/honeybadger/HoneyBadger.fbx`) | https://github.com/Datiel124/StickmanRev2 | CC0 1.0 (LICENSE của repo) | Súng trường của xạ thủ |

- Model nhân vật không có clip hoạt ảnh. `scripts/mannequin_gltf.gd` dùng lại `RigAnimator` (cùng bộ tư thế với hình nhân khối) và chuyển góc khớp sang xương.
- Thiếu file asset thì bot tự dùng hình nhân khối (`mannequin.gd`). Bia `dummy` và thân người chơi (chỉ thấy bóng) vẫn là hình nhân khối.
- `Dagger.fbx` được thêm sẵn nhưng chưa dùng.
- Quy ước: thêm asset mới phải ghi vào bảng này kèm nguồn và giấy phép; chỉ dùng CC0, MIT hoặc CC-BY.
