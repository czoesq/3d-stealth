extends StaticBody3D
class_name Door

@export var door_width: float = 1.2
@export var door_height: float = 2.2
@export var door_thickness: float = 0.08
@export var open_angle: float = 90.0
@export var swing_speed: float = 3.0
@export var q_hold_duration: float = 1.0
@export var fragment_count: int = 8
@export var interaction_range: float = 3.0
@export var door_color: Color = Color(0.5, 0.3, 0.1)

var _is_open: bool = false
var _is_breaking: bool = false
var _mesh_instance: MeshInstance3D
var _collision_shape: CollisionShape3D
var _indicator: Node3D
var _tween: Tween


func _ready() -> void:
	add_to_group("interactable")
	for child in get_children().duplicate():
		if child.name.begins_with("Editor"):
			remove_child(child)
			child.queue_free()
	_build_door()
	_build_indicator()
	print("Door._ready() complete. _indicator=", _indicator, " group=", is_in_group("interactable"))


func _build_door() -> void:
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = BoxMesh.new()
	_mesh_instance.mesh.size = Vector3(door_width, door_height, door_thickness)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = door_color
	_mesh_instance.mesh.material = mat
	_mesh_instance.position = Vector3(door_width * 0.5, door_height * 0.5, 0.0)
	add_child(_mesh_instance)

	_collision_shape = CollisionShape3D.new()
	_collision_shape.shape = BoxShape3D.new()
	_collision_shape.shape.size = Vector3(door_width, door_height, door_thickness)
	_collision_shape.position = Vector3(door_width * 0.5, door_height * 0.5, 0.0)
	add_child(_collision_shape)


func _build_indicator() -> void:
	var Indicator := preload("res://Scripts/Interactables/InteractableIndicator.gd")
	_indicator = Indicator.new()
	_indicator.name = "InteractableIndicator"
	add_child(_indicator)
	_indicator.set_active(false)


func get_e_label() -> String:
	return "Close" if _is_open else "Open"

func get_q_label() -> String:
	return "Break" if not _is_open and not _is_breaking else ""

func get_q_hold_time() -> float:
	return q_hold_duration

func update_hold_progress(pct: float) -> void:
	if _indicator:
		_indicator.update_hold_progress(pct)

func show_prompt(v: bool) -> void:
	print("Door.show_prompt(", v, ") _is_open=", _is_open, " _is_breaking=", _is_breaking)
	if _indicator:
		_indicator.set_active(v and not _is_breaking)


func on_e_interact(_player: Node3D) -> void:
	print("Door.on_e_interact() called")
	if _is_breaking:
		print("  breaking, skipping")
		return
	if _is_open:
		_swing_close()
	else:
		_swing_open()


func on_q_start(_player: Node3D) -> void:
	pass

func on_q_cancel() -> void:
	if _indicator:
		_indicator.set_active(not _is_breaking)

func on_q_hold(delta: float, _player: Node3D) -> float:
	return delta / q_hold_duration

func on_q_complete(_player: Node3D) -> void:
	if _is_open or _is_breaking:
		return
	_break_apart()


func _swing_open() -> void:
	_is_open = true
	if _indicator:
		_indicator.set_e_text(get_e_label())
		_indicator.set_q_text(get_q_label())

	_tween = create_tween().set_parallel(false)
	var target_rotation := deg_to_rad(open_angle)
	var duration := open_angle / (swing_speed * 90.0)
	_tween.tween_property(self, "rotation:y", target_rotation, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(_after_swing)


func _after_swing() -> void:
	pass


func _swing_close() -> void:
	_is_open = false
	if _indicator:
		_indicator.set_e_text(get_e_label())
		_indicator.set_q_text(get_q_label())
	show_prompt(true)

	_tween = create_tween().set_parallel(false)
	var duration := open_angle / (swing_speed * 90.0)
	_tween.tween_property(self, "rotation:y", 0.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


func _break_apart() -> void:
	_is_breaking = true
	show_prompt(false)

	var origin := global_position + basis.x * (door_width * 0.5) + basis.y * (door_height * 0.5)
	var pieces: Array[RigidBody3D] = []

	for i in fragment_count:
		var piece := RigidBody3D.new()
		piece.collision_layer = 2
		piece.collision_mask = 1
		var w := door_width * randf_range(0.2, 0.4)
		var h := door_height * randf_range(0.2, 0.4)
		var t := door_thickness * 0.8

		var mi := MeshInstance3D.new()
		mi.mesh = BoxMesh.new()
		mi.mesh.size = Vector3(w, h, t)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = door_color
		mi.mesh.material = mat
		piece.add_child(mi)

		var cs := CollisionShape3D.new()
		cs.shape = BoxShape3D.new()
		cs.shape.size = Vector3(w, h, t)
		piece.add_child(cs)

		get_parent().add_child(piece)

		var offset := Vector3(
			randf_range(-door_width * 0.4, door_width * 0.4),
			randf_range(-door_height * 0.4, door_height * 0.4),
			randf_range(-door_thickness, door_thickness)
		)
		piece.global_position = origin + basis.x * offset.x + basis.y * offset.y + basis.z * offset.z
		piece.rotation = rotation + Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
		pieces.append(piece)

	for p in pieces:
		var force := Vector3(
			randf_range(-5.0, 5.0),
			randf_range(2.0, 6.0),
			randf_range(-5.0, 5.0)
		)
		p.apply_central_impulse(force)
		p.apply_torque_impulse(Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)))

	queue_free()
