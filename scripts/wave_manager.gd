extends Node
## Quản lý các wave bot: sinh bot theo wave, đếm số còn sống, hết bot thì nghỉ rồi sang wave sau.
## Chỉ phát Signal; main.gd nối tới HUD/âm thanh/điểm.

signal wave_started(wave: int, count: int)
signal wave_cleared(wave: int)
signal enemies_left_changed(left: int)
signal bot_spawned(bot: Node3D)
signal bot_killed(bot: Node3D, info: Dictionary)
signal practice_bot_killed(bot: Node3D, info: Dictionary)
signal bot_relocated(bot: Node3D) # bot rơi/văng khỏi map, được đưa về điểm sinh

const BotScript = preload("res://scripts/bot.gd")
const TitanScript = preload("res://scripts/titan.gd")
const MAX_BOTS_PER_WAVE: int = 10

var break_time: float = 4.0
var wave: int = 0
var alive_types: Dictionary = {}   # loại bot -> số còn sống (HUD hiện cơ cấu bot còn lại)

var _alive: int = 0
var _world: Node3D
var _spawns: Array = []
var _running: bool = false
var _used_spots: Array = []   # chỗ đã dùng ở wave hiện tại (tránh 2 bot đè lên nhau)

const SPAWN_GAP: float = 1.3


## band = (min, max) m quanh người chơi cho map lớn; Vector2.ZERO = cách cũ (điểm xa nhất).
var _band: Vector2 = Vector2.ZERO
## Map có Titan (Khu phố): wave 5, 10, ... có thêm Titan. Mặc định tắt để composition() thuần cho map thường.
var titans_enabled: bool = false
## Bắt đầu từ wave này (>1: chơi thử, main đặt từ Global.start_wave).
var first_wave: int = 1


## Vô Tận: bot sinh liên tục (không wave). `wave` = tầng (độ khó), `stream_cap` bot sống cùng lúc; bot quá xa bị gỡ.
var stream: bool = false
var stream_cap: int = 6
var stream_boss: bool = false   # tầng có Titan: sinh 1 con ngay khi bắt đầu tầng
var _stream_t: float = 0.0
var _prune_t: float = 0.0


func setup(world: Node3D, spawn_points: Array, band: Vector2 = Vector2.ZERO) -> void:
	_world = world
	_spawns = spawn_points
	_band = band


func start() -> void:
	_running = true
	if stream:
		begin_floor(maxi(first_wave, 1), false)
		return
	wave = maxi(first_wave, 1) - 1
	_next_wave()


## Vô Tận: bắt đầu tầng n. Gỡ bot cũ (không tính hạ), đặt số bot tối đa theo tầng, sinh Titan nếu tầng có Titan.
func begin_floor(n: int, with_boss: bool) -> void:
	for b in get_tree().get_nodes_in_group("bots"):
		if is_instance_valid(b):
			b.queue_free()
	_alive = 0
	alive_types.clear()
	_used_spots.clear()
	wave = n
	var E: Dictionary = Global.ENDLESS
	stream_cap = mini(int(E["cap_base"]) + int(E["cap_per_floor"]) * (n - 1), int(E["cap_max"]))
	_stream_t = 0.0
	_prune_t = 0.0
	if with_boss:
		_alive += 1
		_spawn("titan")
	enemies_left_changed.emit(_alive)


## Loại bot tầng n: lấy ngẫu nhiên từ thành phần wave tương ứng (không có Titan: Titan sinh riêng).
func stream_type(n: int) -> String:
	var comp: Array = composition(n).filter(func(t): return t != "titan")
	return comp[randi() % comp.size()]


func _stream_tick(delta: float) -> void:
	var E: Dictionary = Global.ENDLESS
	_stream_t -= delta
	if _stream_t <= 0.0 and _count_normal() < stream_cap:
		_stream_t = float(E["spawn_interval"])
		_used_spots.clear()   # chỉ cần tránh đè bot đang sống (do _spot_ok kiểm), không nhớ vị trí cũ
		_alive += 1
		_spawn(stream_type(wave))
		enemies_left_changed.emit(_alive)
	_prune_t -= delta
	if _prune_t <= 0.0:
		_prune_t = float(E["prune_interval"])
		_prune_far(float(E["despawn_dist"]))


func _count_normal() -> int:
	var c: int = 0
	for k in alive_types:
		if k != "titan":
			c += int(alive_types[k])
	return c


## Gỡ bot thường ở xa người chơi hơn `dist` m (không tính hạ, không điểm). Titan không bị gỡ.
func _prune_far(dist: float) -> int:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return 0
	var n: int = 0
	for b in get_tree().get_nodes_in_group("bots"):
		if b.dead or "is_titan" in b or b.is_queued_for_deletion():
			continue
		if (b as Node3D).global_position.distance_to(player.global_position) > dist:
			var tn: String = String(b.type_name)
			alive_types[tn] = maxi(int(alive_types.get(tn, 0)) - 1, 0)
			_alive -= 1
			b.queue_free()
			n += 1
	if n > 0:
		enemies_left_changed.emit(_alive)
	return n


func stop() -> void:
	_running = false


## Thành phần wave n: wave 1 toàn lính kiếm; từ wave 2 có xạ thủ và lao nhanh; từ wave 3 có tinh nhuệ; từ wave 4 có pháo thủ.
func composition(n: int) -> Array:
	var count: int = mini(2 + n, MAX_BOTS_PER_WAVE)
	var types: Array = []
	for i in count:
		if n >= 3 and i % 4 == 3:
			types.append("elite")
		elif n >= 4 and i % 5 == 4:
			types.append("bomber")
		elif n >= 2 and i % 5 == 1:
			types.append("rusher")
		elif n >= 2 and i % 3 == 2:
			types.append("gunner")
		else:
			types.append("swordsman")
	if titans_enabled:
		var T: Dictionary = Global.TITAN
		var first: int = int(T["first_wave"])
		if n >= first and (n - first) % int(T["every"]) == 0:
			var k: int = mini(1 + (n - first) / (int(T["every"]) * 2), int(T["max_alive"]))
			for i in k:
				types.append("titan")
	return types


func _next_wave() -> void:
	wave += 1
	_used_spots.clear()
	var comp: Array = composition(wave)
	_alive = comp.size()
	alive_types.clear()
	wave_started.emit(wave, comp.size())
	enemies_left_changed.emit(_alive)
	for t in comp:
		_spawn(t)
	enemies_left_changed.emit(_alive) # báo lại sau khi sinh xong để HUD thấy cơ cấu bot theo loại


## Tạo Titan (navmesh Titan, chỗ sinh đủ rộng) và thêm vào thế giới; chưa nối Signal chết.
func _create_titan(at_wave: int) -> CharacterBody3D:
	var b: CharacterBody3D = TitanScript.new()
	b.setup("titan", at_wave)
	var nm: Variant = _world.get("titan_nav_map")
	if nm is RID and (nm as RID).is_valid():
		b.nav_map = nm
	var sp: Vector3 = _pick_spawn()
	if b.nav_map.is_valid():
		sp = NavigationServer3D.map_get_closest_point(b.nav_map, sp) # chỗ đủ rộng cho thân hình Titan
	b.position = sp
	_world.add_child(b)
	bot_spawned.emit(b)
	return b


## Tập luyện: gọi một Titan (chỉ map có Titan). Không tính vào wave, không làm bot tập sinh lại. Trả về null nếu map không có.
func spawn_titan_practice() -> Node3D:
	if not titans_enabled or _spawns.is_empty():
		return null
	return _create_titan(int(Global.TRAINING["bot_wave"]))


## Tập luyện: xoá mọi Titan đang có. Trả về số Titan đã xoá.
func clear_titans() -> int:
	var n: int = 0
	for b in get_tree().get_nodes_in_group("bots"):
		if "is_titan" in b:
			b.queue_free()
			n += 1
	return n


func _spawn(type_name: String) -> void:
	if type_name == "titan":
		var t: CharacterBody3D = _create_titan(wave)
		t.died.connect(_on_bot_died)
		alive_types[type_name] = int(alive_types.get(type_name, 0)) + 1
		return
	var b: CharacterBody3D = BotScript.new()
	b.setup(type_name, wave)
	b.position = _free_spot(_pick_spawn())
	_used_spots.append(b.position)
	_world.add_child(b)
	b.died.connect(_on_bot_died)
	alive_types[type_name] = int(alive_types.get(type_name, 0)) + 1
	bot_spawned.emit(b)


## Tập luyện: sinh một bot lẻ ở chỉ số wave `at_wave`, không tính vào wave và không kết thúc wave.
func spawn_practice(type_name: String, at_wave: int = 1) -> Node3D:
	var b: CharacterBody3D = BotScript.new()
	b.setup(type_name, at_wave)
	_used_spots.clear()
	b.position = _free_spot(_pick_spawn())
	_world.add_child(b)
	b.died.connect(func(bot, info): practice_bot_killed.emit(bot, info))
	bot_spawned.emit(b)
	return b


## Chọn điểm sinh xa người chơi nhất trong 3 điểm ngẫu nhiên.
func _pick_spawn() -> Vector3:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var best: Vector3 = _spawns[randi() % _spawns.size()]
	if player == null:
		return best
	if _band != Vector2.ZERO:
		return _pick_in_band(player.global_position)
	var best_d: float = -1.0
	for i in 3:
		var p: Vector3 = _spawns[randi() % _spawns.size()]
		var d: float = p.distance_to(player.global_position)
		if d > best_d:
			best_d = d
			best = p
	return best


## Map lớn: chọn ngẫu nhiên điểm cách người chơi trong [min, max]; không có thì lấy điểm gần mức giữa vòng nhất.
func _pick_in_band(from: Vector3) -> Vector3:
	var ok: Array = []
	for p in _spawns:
		var d: float = (p as Vector3).distance_to(from)
		if d >= _band.x and d <= _band.y:
			ok.append(p)
	if not ok.is_empty():
		return ok[randi() % ok.size()]
	var mid: float = (_band.x + _band.y) * 0.5
	var best: Vector3 = _spawns[0]
	var best_e: float = INF
	for p in _spawns:
		var e: float = absf((p as Vector3).distance_to(from) - mid)
		if e < best_e:
			best_e = e
			best = p
	return best


## Tìm chỗ trống gần điểm sinh (xoắn ra từng vòng): không đè bot khác, không trong tường/người chơi.
## Hai bot sinh trùng chỗ bị engine đẩy văng (lên cao / ra ngoài biên) nên phải tách ra.
func _free_spot(base: Vector3) -> Vector3:
	for ring in 6:
		var n: int = 1 if ring == 0 else 6 * ring
		for k in n:
			var off := Vector3.ZERO
			if ring > 0:
				off = Vector3(cos(TAU * k / n), 0.0, sin(TAU * k / n)) * SPAWN_GAP * ring
			if _spot_ok(base + off):
				return base + off
	return base


func _spot_ok(c: Vector3) -> bool:
	for u in _used_spots:
		if Vector2(c.x - u.x, c.z - u.z).length() < SPAWN_GAP:
			return false
	var half: Variant = _world.get("half")
	if half is Vector2 and (absf(c.x) > half.x - 1.0 or absf(c.z) > half.y - 1.0):
		return false
	var shape := CapsuleShape3D.new()
	shape.radius = 0.45
	shape.height = 1.8
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, c + Vector3(0.0, 0.95, 0.0))
	q.collision_mask = Global.L_WORLD | Global.L_PLAYER | Global.L_ENEMY
	return _world.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## Lưới an toàn: bot rơi khỏi map / văng ra ngoài biên thì đưa về một điểm sinh (không để wave kẹt).
func _physics_process(delta: float) -> void:
	if _world == null or _spawns.is_empty():
		return
	if stream and _running:
		_stream_tick(delta)
	var void_y: Variant = _world.get("void_y")
	var half: Variant = _world.get("half")
	for b in get_tree().get_nodes_in_group("bots"):
		if b.dead:
			continue
		var p: Vector3 = b.global_position
		var lost: bool = void_y is float and p.y < void_y
		if half is Vector2 and (absf(p.x) > half.x + 1.5 or absf(p.z) > half.y + 1.5):
			lost = true
		if lost:
			_used_spots.clear()
			b.global_position = _free_spot(_pick_spawn())
			b.velocity = Vector3.ZERO
			bot_relocated.emit(b)


func _on_bot_died(bot: Node3D, info: Dictionary) -> void:
	var tn: String = String(bot.type_name)
	alive_types[tn] = maxi(int(alive_types.get(tn, 0)) - 1, 0)
	_alive -= 1
	bot_killed.emit(bot, info)
	enemies_left_changed.emit(_alive)
	if stream:
		return   # Vô Tận: không có wave; hạ bot chỉ tính vào chỉ tiêu tầng
	if _alive <= 0:
		wave_cleared.emit(wave)
		await get_tree().create_timer(break_time).timeout
		if _running:
			_next_wave()
