extends Node3D
## Điều phối: đặt người chơi vào đấu trường, nối Signal giữa các hệ thống, quản lý con trỏ chuột.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

@onready var arena: Node3D = $Arena
@onready var hud: CanvasLayer = $HUD

var player: CharacterBody3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = arena.spawn_point
	player.speed_changed.connect(hud.set_speed)


func _input(event: InputEvent) -> void:
	# ESC nhả chuột, bấm chuột trái để bắt lại.
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
