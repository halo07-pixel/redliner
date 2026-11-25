extends RefCounted
## Âm thanh, bus, bề mặt (dữ liệu thuần).
## Chỉ là dữ liệu: `Global` nạp lại các hằng này nên mã khác vẫn dùng `Global.TÊN`. Không tham chiếu Global ở đây.

## Âm thanh (M15). Mỗi âm: vol_db gốc, pitch_var (±tỉ lệ), voices (tối đa phát cùng lúc), bus.
## Âm 3D (Sfx.play_at) giảm dần theo khoảng cách: unit_size / max_distance.
const SOUNDS: Dictionary = {
	"slash": {"vol_db": -8.0, "pitch_var": 0.12, "voices": 4, "bus": "SFX"},
	"shot": {"vol_db": -7.0, "pitch_var": 0.06, "voices": 4, "bus": "SFX"},
	"shotgun": {"vol_db": -4.0, "pitch_var": 0.05, "voices": 2, "bus": "SFX"},
	"launcher": {"vol_db": -5.0, "pitch_var": 0.05, "voices": 3, "bus": "SFX"},
	"sniper": {"vol_db": -3.0, "pitch_var": 0.03, "voices": 2, "bus": "SFX"},
	"explosion": {"vol_db": -2.0, "pitch_var": 0.08, "voices": 3, "bus": "SFX"},
	"hit": {"vol_db": -8.0, "pitch_var": 0.1, "voices": 4, "bus": "SFX"},
	"hurt": {"vol_db": -5.0, "pitch_var": 0.05, "voices": 2, "bus": "SFX"},
	"clash": {"vol_db": -4.0, "pitch_var": 0.1, "voices": 3, "bus": "SFX"},
	"parry": {"vol_db": -4.0, "pitch_var": 0.03, "voices": 2, "bus": "SFX"},
	"parry_low": {"vol_db": -5.0, "pitch_var": 0.05, "voices": 2, "bus": "SFX"},
	"parry_miss": {"vol_db": -7.0, "pitch_var": 0.05, "voices": 2, "bus": "SFX"},
	"tell": {"vol_db": -9.0, "pitch_var": 0.04, "voices": 3, "bus": "SFX"},
	"step": {"vol_db": -14.0, "pitch_var": 0.15, "voices": 2, "bus": "SFX"},
	"step_metal": {"vol_db": -12.0, "pitch_var": 0.12, "voices": 2, "bus": "SFX"},
	"step_wood": {"vol_db": -12.0, "pitch_var": 0.12, "voices": 2, "bus": "SFX"},
	"jump": {"vol_db": -12.0, "pitch_var": 0.08, "voices": 2, "bus": "SFX"},
	"ledge": {"vol_db": -9.0, "pitch_var": 0.05, "voices": 1, "bus": "SFX"},
	"dash": {"vol_db": -7.0, "pitch_var": 0.06, "voices": 2, "bus": "SFX"},
	"slide": {"vol_db": -9.0, "pitch_var": 0.05, "voices": 1, "bus": "SFX"},
	"wall": {"vol_db": -9.0, "pitch_var": 0.05, "voices": 1, "bus": "SFX"},
	"grapple": {"vol_db": -7.0, "pitch_var": 0.05, "voices": 1, "bus": "SFX"},
	"reload": {"vol_db": -8.0, "pitch_var": 0.04, "voices": 1, "bus": "SFX"},
	"switch": {"vol_db": -10.0, "pitch_var": 0.06, "voices": 1, "bus": "SFX"},
	"crate": {"vol_db": -6.0, "pitch_var": 0.1, "voices": 3, "bus": "SFX"},
	"bot_die": {"vol_db": -6.0, "pitch_var": 0.12, "voices": 3, "bus": "SFX"},
	"pickup": {"vol_db": -6.0, "pitch_var": 0.0, "voices": 2, "bus": "SFX"},
	"wave": {"vol_db": -4.0, "pitch_var": 0.0, "voices": 1, "bus": "UI"},
	"destabilized": {"vol_db": -4.0, "pitch_var": 0.0, "voices": 1, "bus": "SFX"},
	"recover": {"vol_db": -8.0, "pitch_var": 0.0, "voices": 1, "bus": "SFX"},
	"ui_click": {"vol_db": -8.0, "pitch_var": 0.03, "voices": 2, "bus": "UI"},
	"game_over": {"vol_db": -4.0, "pitch_var": 0.0, "voices": 1, "bus": "UI"},
}

const AUDIO_BUSES: Array = ["SFX", "Music", "UI"]

const AUDIO: Dictionary = {
	"voices_2d": 8, "voices_3d": 14, "unit_size": 9.0, "max_distance": 70.0,
	"music_fade": 1.2,          # giây đổi lớp nhạc theo cường độ
	"intensity_enemies": 8,     # số bot tạo cường độ tối đa
	"intensity_low_hp": 0.4,    # dưới tỉ lệ máu này nhạc dồn thêm
}

const SURFACES: Dictionary = {"platform": "metal", "grapple": "metal", "runwall": "metal", "ramp": "metal"}
