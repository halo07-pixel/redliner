extends Node
## Quản lý các wave bot: sinh bot theo wave, đếm số còn sống, hết bot thì nghỉ rồi sang wave sau.
## Chỉ phát Signal; main.gd nối tới HUD/âm thanh/điểm.

signal wave_started(wave: int, count: int)
signal wave_cleared(wave: int)
signal enemies_left_changed(left: int)
signal bot_spawned(bot: Node3D)
signal bot_killed(bot: Node3D, info: Dictionary)

const BotScript = preload("res://scripts/bot.gd")
const MAX_BOTS_PER_WAVE: int = 10

var break_time: float = 4.0
var wave: int = 0

var _alive: int = 0
var _world: Node3D
var _spawns: Array = []
var _running: bool = false


func setup(world: Node3D, spawn_points: Array) -> void:
	_world = world
	_spawns = spawn_points


func start() -> void:
	_running = true
	wave = 0
	_next_wave()


func stop() -> void:
	_running = false


## Thành phần wave n: wave 1 toàn lính kiếm; từ wave 2 có xạ thủ; từ wave 3 có tinh nhuệ.
func composition(n: int) -> Array:
	var count: int = mini(2 + n, MAX_BOTS_PER_WAVE)
	var types: Array = []
	for i in count:
		if n >= 3 and i % 4 == 3:
			types.append("elite")
		elif n >= 2 and i % 3 == 2:
			types.append("gunner")
		else:
			types.append("swordsman")
	return types


func _next_wave() -> void:
	wave += 1
	var comp: Array = composition(wave)
	_alive = comp.size()
	wave_started.emit(wave, comp.size())
	enemies_left_changed.emit(_alive)
	for t in comp:
		_spawn(t)


func _spawn(type_name: String) -> void:
	var b: CharacterBody3D = BotScript.new()
	b.setup(type_name, wave)
	b.position = _pick_spawn()
	_world.add_child(b)
	b.died.connect(_on_bot_died)
	bot_spawned.emit(b)


## Chọn điểm sinh xa người chơi nhất trong 3 điểm ngẫu nhiên.
func _pick_spawn() -> Vector3:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var best: Vector3 = _spawns[randi() % _spawns.size()]
	if player == null:
		return best
	var best_d: float = -1.0
	for i in 3:
		var p: Vector3 = _spawns[randi() % _spawns.size()]
		var d: float = p.distance_to(player.global_position)
		if d > best_d:
			best_d = d
			best = p
	return best


func _on_bot_died(bot: Node3D, info: Dictionary) -> void:
	_alive -= 1
	bot_killed.emit(bot, info)
	enemies_left_changed.emit(_alive)
	if _alive <= 0:
		wave_cleared.emit(wave)
		await get_tree().create_timer(break_time).timeout
		if _running:
			_next_wave()
