extends Node3D

@export var follow_speed: float = 6.0
@export var dead_zone: float = 2.5

@onready var player: Node3D = get_node("../Player")

func _physics_process(delta: float) -> void:
	if not player:
		return

	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()

	if dist < 0.01:
		return

	var speed := follow_speed if dist > dead_zone else follow_speed * 0.4
	var step := minf(speed * delta, dist)
	global_position += to_player.normalized() * step
