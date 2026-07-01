extends StaticBody3D
class_name Ladder

@export var ladder_height: float = 3.0
@export var ladder_width: float = 1.0
@export var rung_spacing: float = 0.4
@export var rail_thickness: float = 0.08
@export var rung_thickness: float = 0.06
@export var interaction_range: float = 2.0

var _climbing_player: Node3D = null
var _indicator: Node3D
var _ladder_area: Area3D
var _detaching: bool = false


func _ready() -> void:
	add_to_group("ladder")
	add_to_group("interactable")
	_generate()


func get_ladder_height() -> float:
	return ladder_height


func get_ladder_width() -> float:
	return ladder_width


func get_world_base_y() -> float:
	return global_position.y - ladder_height * 0.5 * scale.y


func get_world_top_y() -> float:
	return global_position.y + ladder_height * 0.5 * scale.y


func on_e_interact(player_node: Node3D) -> void:
	if _climbing_player:
		_detach_player()
	else:
		_attach_player(player_node)


func _attach_player(player_node: Node3D) -> void:
	_climbing_player = player_node
	if "on_ladder" in player_node:
		player_node.on_ladder = true
	if "_attach_to_ladder" in player_node:
		player_node._attach_to_ladder(self)
	if _indicator and _indicator.has_method("set_e_text"):
		_indicator.set_e_text("Release")


func _detach_player() -> void:
	if _detaching or not _climbing_player:
		return
	_detaching = true
	if "_detach_from_ladder" in _climbing_player:
		_climbing_player._detach_from_ladder()
	if "on_ladder" in _climbing_player:
		_climbing_player.on_ladder = false
	_climbing_player = null
	if _indicator and _indicator.has_method("set_e_text"):
		_indicator.set_e_text("Climb")
	_detaching = false


func get_e_label() -> String:
	return "Release" if _climbing_player else "Climb"


func get_q_label() -> String:
	return ""


func show_prompt(v: bool) -> void:
	if _indicator and _indicator.has_method("set_active"):
		_indicator.set_active(v)


func show_takedown_indicators(v: bool) -> void:
	pass


func set_indicator_mode(mode: String) -> void:
	pass


func update_hold_progress(pct: float) -> void:
	pass


func _generate() -> void:
	for child in get_children():
		if child.name.begins_with("Rung") or child.name.begins_with("Rail") or child.name.begins_with("ClimbArea") or child.name.begins_with("Editor") or child.name.begins_with("Prompt") or child.name.begins_with("InteractableIndicator"):
			remove_child(child)
			child.queue_free()

	collision_layer = 1 | 2

	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = Color(0.4, 0.4, 0.42)

	var half_h := ladder_height * 0.5

	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(rail_thickness, ladder_height, rail_thickness)
	rail_mesh.material = rail_mat

	for side in [-1, 1]:
		var x: float = side * (ladder_width * 0.5 - rail_thickness * 0.5)
		var rail := MeshInstance3D.new()
		rail.name = "Rail" + ("L" if side < 0 else "R")
		rail.mesh = rail_mesh
		rail.position = Vector3(x, 0, 0)
		add_child(rail)

		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = Vector3(rail_thickness, ladder_height, rail_thickness)
		shape.position = Vector3(x, 0, 0)
		add_child(shape)

	var num_rungs := maxi(1, floori(ladder_height / rung_spacing))
	if num_rungs > 0:
		var rung_mat := StandardMaterial3D.new()
		rung_mat.albedo_color = Color(0.35, 0.35, 0.38)

		var rung_mesh := BoxMesh.new()
		rung_mesh.size = Vector3(ladder_width, rung_thickness, rung_thickness)
		rung_mesh.material = rung_mat

		var total_rung_height := (num_rungs - 1) * rung_spacing
		var start_y := -total_rung_height * 0.5
		for i in num_rungs:
			var y := start_y + i * rung_spacing
			var rung := MeshInstance3D.new()
			rung.name = "Rung" + str(i)
			rung.mesh = rung_mesh
			rung.position = Vector3(0, y, 0)
			add_child(rung)

			var shape := CollisionShape3D.new()
			shape.shape = BoxShape3D.new()
			shape.shape.size = Vector3(ladder_width, rung_thickness, rung_thickness)
			shape.position = Vector3(0, y, 0)
			add_child(shape)

	_ladder_area = Area3D.new()
	_ladder_area.name = "ClimbArea"
	var area_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ladder_width + 0.3, ladder_height, 0.3)
	area_shape.shape = box
	area_shape.position = Vector3(0, 0, 0)
	_ladder_area.add_child(area_shape)
	_ladder_area.collision_layer = 0
	_ladder_area.collision_mask = 1
	add_child(_ladder_area)

	var IndicatorClass = preload("res://Scripts/Interactables/InteractableIndicator.gd")
	_indicator = IndicatorClass.new()
	_indicator.name = "InteractableIndicator"
	add_child(_indicator)
	if _indicator.has_method("set_e_text"):
		_indicator.set_e_text("Climb")
	if _indicator.has_method("set_q_text"):
		_indicator.set_q_text("")
