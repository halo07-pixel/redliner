# Tài nguyên ngoài (assets)

| Asset | Nguồn | Giấy phép | Dùng cho |
|---|---|---|---|
| GodoDude Mannequin (`assets/characters/godo/GodoDude.gltf`) | https://github.com/WuotanStudios/GodoDudeMannequin | MIT (WuotanStudios), `assets/characters/godo/LICENSE.txt` | Thân người que của bot (đã rig, 67 xương) |
| Quaternius – Medieval Weapons Pack (`Sword`, `Axe_Double`, `Dagger` FBX) | https://quaternius.com (bản sao trong repo `beep2bleep/FreeAssetsByKenneyNLandQuaternius`) | CC0 1.0, `assets/weapons/quaternius/LICENSE.txt` | Kiếm (kiếm sĩ), rìu đôi (tinh anh) |
| HoneyBadger (`assets/weapons/honeybadger/HoneyBadger.fbx`) | https://github.com/Datiel124/StickmanRev2 | CC0 1.0 (LICENSE của repo) | Súng trường của xạ thủ |
| Quaternius – Universal Animation Library [Standard] (`assets/animations/ual/UAL1_Standard.glb`, bản không root motion) | https://quaternius.com/packs/universalanimationlibrary.html (người dùng cung cấp file) | CC0 1.0, `assets/animations/ual/LICENSE.txt` | Clip chạy/đi/đứng/núp nền cho bot glTF (M32), qua `scripts/clip_lib.gd` |
| Kiếm low poly (`assets/weapons/lowpoly/sword.glb`, dựng bằng `tools/blender/make_sword.py`) | Tự dựng trong Blender (M42) | Của dự án | Kiếm của viewmodel + kiếm sĩ (thay Quaternius `Sword.fbx`; tắt bằng `Global.LOWPOLY["enabled"]`) |
| Súng low poly (`assets/weapons/lowpoly/{pistol,shotgun,launcher,sniper}.glb`, dựng bằng `tools/blender/make_guns.py`) | Tự dựng trong Blender (M43) | Của dự án | 4 súng của viewmodel; bot xạ thủ cầm sniper, pháo thủ cầm launcher (thay HoneyBadger; tắt bằng `Global.LOWPOLY["enabled"]`) |
| Thân bot + Titan low poly (`assets/characters/lowpoly/{swordsman,gunner,elite,rusher,bomber,titan}.glb`, dựng bằng `tools/blender/make_bots.py`) | Tự dựng trong Blender (M44) | Của dự án | Thân 5 loại bot + Titan: khối rời gắn vào 15 khớp proxy (`scripts/mannequin_lowpoly.gd`); thay người que GodoDude khi bật `Global.LOWPOLY["enabled"]` |
| Module bản đồ Vô Tận low poly (`assets/map/lowpoly/{building_block,building_fins,building_slab,pillar,stage,cover}.glb`, `tools/blender/make_map.py`) | Tự dựng trong Blender (M45) | Của dự án | Vỏ hiển thị cho hộp va chạm toà nhà/cột/bệ/bức che của `Maps.endless`; mesh nằm trong khối đơn vị, co giãn theo hộp (`scripts/endless_modules.gd`) |
| Vật nhặt low poly (`assets/items/lowpoly/{health,ammo,stamina}.glb`, `tools/blender/make_items.py`) | Tự dựng trong Blender (M46) | Của dự án | 118-234 tam giác; `it_glow` tô theo màu loại trong `Global.PICKUPS`, `it_body` tối (`scripts/pickup.gd`) |
| Clip hoạt ảnh bot low poly (`assets/animations/lowpoly/clips.glb`, `tools/blender/make_clips.py`) | Tự keyframe trong Blender (M47) | Của dự án | 9 clip: Sword_Idle, Pistol_Idle, Crouch_Idle, Walk, Jog_Fwd, Sprint (lặp) + Slash, Shoot, Stagger (một lần); gắn lên 15 Empty khớp proxy |
| Rìu đôi + dao găm low poly (`assets/weapons/lowpoly/{axe,dagger}.glb`, `tools/blender/make_melee.py`) | Tự dựng trong Blender (M44) | Của dự án | Vũ khí tinh anh / kẻ lao tới (thay Quaternius `Axe_Double.fbx`, `Dagger.fbx`) |

- Model nhân vật GodoDude không có clip hoạt ảnh; từ M32 `scripts/clip_lib.gd` lấy clip từ Universal Animation Library, chuyển sang khớp proxy của rig (bake một lần) rồi `RigAnimator` trộn lên tư thế sinh bằng code (chân/thân/đầu; tay, đòn đánh, parry, bắn vẫn do code). Chỉ dùng 7 clip (Idle, Sword_Idle, Pistol_Idle, Walk, Jog_Fwd, Sprint, Crouch_Idle); file glb còn ~36 clip chưa dùng (7.6 MB).
- (Cũ) Model nhân vật không có clip hoạt ảnh. `scripts/mannequin_gltf.gd` dùng lại `RigAnimator` (cùng bộ tư thế với hình nhân khối) và chuyển góc khớp sang xương.
- Thiếu file asset thì bot tự dùng hình nhân khối (`mannequin.gd`). Bia `dummy` và thân người chơi (chỉ thấy bóng) vẫn là hình nhân khối.
- `Dagger.fbx` được thêm sẵn nhưng chưa dùng.
- Quy ước: thêm asset mới phải ghi vào bảng này kèm nguồn và giấy phép; chỉ dùng CC0, MIT hoặc CC-BY.


## Chuẩn low poly (M42)

Mọi model tự dựng trong Blender cho hướng "lột xác" theo chuẩn này. Hằng số nằm ở `scripts/data/visual_data.gd` (`PALETTE`, `LOWPOLY`), không có tuỳ chọn trong menu.

- **Màu**: chỉ dùng màu phẳng lấy từ `PALETTE` (`steel`, `steel_dark`, `gold`, `leather`, ...). Không texture, không UV. Mỗi màu là một vật liệu riêng, tên `<model>_<màu>`; đổi màu thì đổi cả `PALETTE` lẫn script Blender.
- **Shading phẳng**: mọi mặt `smooth = False`; xuất `.glb` với `export_normals=False` (file nhỏ, Godot tự tính pháp tuyến phẳng).
- **Ngân sách tam giác** (đếm theo mesh, `LOWPOLY["budget"]`): bot ~10000-13000 (M44 nâng lên theo yêu cầu người dùng; ban đầu 800-1500); súng/kiếm ~200-600; module bản đồ / vật cảnh tối đa 3000 (người dùng chốt ở M45; hiện 80-2560). Vật cảnh lặp lại dùng `MultiMesh`; mỗi ô 50 m tối đa 40.000 tam giác (`LOWPOLY["budget"]["cell"]`, có test). Va chạm vẫn là hộp đơn giản, không dùng mesh model.
- **Đơn vị/trục**: mét, tỉ lệ 1. Trong Blender: Y là hướng "phía trước" của vật (mũi kiếm, nòng súng), X là bề dày, Z là bề rộng/cao. Xuất `export_yup=True` -> trong Godot mũi/nòng hướng -Z, đúng quy ước viewmodel. Gốc ở điểm cầm (giữa chuôi / báng).
- **Bot**: tên khớp trùng 15 khớp proxy của rig (`MannequinGltf.JOINT_NAMES`); vũ khí gắn vào `hand_r` qua `MannequinGltf.WEAPONS[kind]["lowpoly"]` (`file`, `grip` = tỉ lệ từ đuôi tới chỗ cầm, `flip` = mũi nằm ở đầu âm của trục dài).
- **Điểm gắn** (M43): cầm = gốc model; nòng súng = đầu -Z. Empty tên `muzzle` đặt ở miệng nòng (viewmodel đặt chớp lửa theo z của nó). Phần cử động khi nạp là object riêng tên `Mag` (súng lục), `Pump` (shotgun), `Cap` (launcher), `Bolt` (sniper), gốc object = trục xoay; viewmodel tìm theo tên.
- **Dựng bằng script**: `tools/blender/make_guns.py` viết hình học theo toạ độ Godot rồi đổi sang Blender; chạy trong Blender hoặc ngoài Blender bằng `pip install bpy==5.3.0` (đặt `REDLINER_GUN_OUT`), nên không cần chuyển file từ máy người dùng.
- **Dự phòng**: `LOWPOLY["enabled"] = false` hoặc thiếu file -> dùng lại khối/FBX cũ.
- **Quy trình**: script `tools/blender/*.py` dựng + xuất; `.blend` làm việc để ở `D:\nham\gugugaga\blender` trên máy tác giả, chỉ `.glb` (+ `.import`) vào repo; chạy `godot --headless --path . --import` sau khi thêm file.

### Thân bot (M44)
- Không xương/skin: thân là các **khối rời** (object Blender) cha-con theo 15 Empty đặt đúng tên khớp proxy (`hips > spine > head | shoulder_x > elbow_x > hand_x | hip_x > knee_x > ankle_x`), vị trí khớp bằng `mannequin.gd` + `Global.RIG` (vai/độ dày theo loại). Vì vậy `RigAnimator`, IK chân và hitbox chạy y nguyên; `test_m44` kiểm tra vị trí khớp theo RIG.
- Vật liệu đặt tên theo **vai trò** (`bd_cloth`, `bd_pants`, `bd_dark`, `bd_skin`, `bd_glow`); màu thật do `mannequin_lowpoly.gd` tô theo màu của loại bot khi chạy (nên không dùng `PALETTE`). Ngân sách thân: `LOWPOLY["budget"]["bot"]` (hiện 10400-11800 tam giác).
- Vũ khí cầm tay lấy từ `MannequinGltf.weapon_config(kind)` (kiếm/rìu/dao/súng low poly), đặt trong khung hình nhân khối: cận chiến dọc +Y, súng nòng -Z, điểm cầm ở gốc.
- Dự phòng: tắt `LOWPOLY["enabled"]` hoặc thiếu file -> người que GodoDude -> hình nhân khối. Bia `dummy` và thân người chơi vẫn là hình nhân khối.

### Module bản đồ (M45)
- Mỗi module nằm gọn trong khối đơn vị 1x1x1 (tâm ở gốc), `scripts/endless_modules.gd` co giãn đúng bằng kích thước hộp va chạm và ẩn hộp gốc; va chạm, navmesh, bố cục `Maps.endless` không đổi. Dốc và bệ móc giữ hộp cũ.
- Vật liệu theo vai trò `mod_wall` / `mod_trim` / `mod_glow`: thân toà nhà dùng mặt tiền của `EndlessLook` (tông theo vị trí), cửa sổ phát sáng theo màu chủ đề của tầng.
- Chạy `REDLINER_MAP_OUT=assets/map/lowpoly python3 tools/blender/make_map.py` (cần `bpy`) hoặc dán vào Blender.

### Vật nhặt, hạt, ánh sáng (M46)
- Hạt (`scripts/fx.gd`) là khối lập phương nhỏ (`FX["particle_size"]`), mỗi lần phát tối đa `FX["max_particles"]` hạt (giảm hiệu ứng thì ít hơn); nhặt vật tung hạt qua `Fx.burst`.
- Độ sáng cửa sổ module theo chủ đề tầng: `LOOK["window_energy"]` x `THEMES[..]["window_mul"]` (đêm sáng nhất). Mọi con số ở hằng số, không có menu.

### Hoạt ảnh Blender cho bot (M47)
- `make_clips.py` keyframe thật (quaternion + dịch hông) cho 15 Empty trùng tên khớp proxy; mỗi clip là một NLA track -> một animation glTF. Mở `clips_m47.blend` để sửa keyframe rồi xuất lại.
- `scripts/lowpoly_clips.gd` bake clip ra mảng quaternion + Euler (liên tục, vai > 90° không lật) và có cùng giao diện với `ClipLib`; `RigAnimator.clip_lib` chọn thư viện (thân low poly dùng clip Blender, GodoDude vẫn dùng UAL).
- Clip lặp thay lớp chân/thân/đầu (tên trùng UAL nên `_pick_clip` dùng luôn). Overlay `swing`/`shoot`/`stagger` lấy từ `Slash`/`Shoot`/`Stagger` (pha chém co giãn theo windup/active/recovery); `hurt`/`die`/`parry` vẫn do code vì phụ thuộc hướng đòn. Thiếu clip -> rơi về hoạt ảnh bằng code.
- Chưa làm: hoạt ảnh góc nhìn người chơi (nạp đạn, chém kiếm, parry của viewmodel) vẫn bằng keyframe trong code.
