extends StaticBody3D
class_name Chest

@export var items: Array[String] = []
@export var chest_color: Color = Color(0.6, 0.35, 0.12)
@export var lid_color: Color = Color(0.55, 0.3, 0.1)
@export var interaction_range: float = 2.5

var _is_open: bool = false
var _lid_mesh: MeshInstance3D
var _lid_pivot: Node3D
var _indicator: Node3D
var _tween: Tween


func _ready() -> void:
	add_to_group("interactable")
	for child in get_children().duplicate():
		if child.name.begins_with("Editor"):
			remove_child(child)
			child.queue_free()
	_build_chest()
	_build_indicator()


func _build_chest() -> void:
	var body := MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(1.2, 0.6, 1.2)
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = chest_color
	body.mesh.material = body_mat
	body.position = Vector3(0, 0.3, 0)
	add_child(body)

	var body_collision := CollisionShape3D.new()
	body_collision.shape = BoxShape3D.new()
	body_collision.shape.size = Vector3(1.2, 0.6, 1.2)
	body_collision.position = Vector3(0, 0.3, 0)
	add_child(body_collision)

	_lid_pivot = Node3D.new()
	_lid_pivot.position = Vector3(0, 0.6, -0.6)
	add_child(_lid_pivot)

	_lid_mesh = MeshInstance3D.new()
	_lid_mesh.mesh = BoxMesh.new()
	_lid_mesh.mesh.size = Vector3(1.22, 0.08, 1.22)
	var lid_mat := StandardMaterial3D.new()
	lid_mat.albedo_color = lid_color
	_lid_mesh.mesh.material = lid_mat
	_lid_mesh.position = Vector3(0, 0.04, 0.6)
	_lid_pivot.add_child(_lid_mesh)

	var lid_highlight := MeshInstance3D.new()
	lid_highlight.mesh = BoxMesh.new()
	lid_highlight.mesh.size = Vector3(1.1, 0.01, 0.15)
	var hl_mat := StandardMaterial3D.new()
	hl_mat.albedo_color = Color(0.8, 0.6, 0.2)
	lid_highlight.mesh.material = hl_mat
	lid_highlight.position = Vector3(0, 0.045, 0.4)
	_lid_pivot.add_child(lid_highlight)

	var lock_mesh := MeshInstance3D.new()
	lock_mesh.mesh = BoxMesh.new()
	lock_mesh.mesh.size = Vector3(0.12, 0.1, 0.12)
	var lock_mat := StandardMaterial3D.new()
	lock_mat.albedo_color = Color(0.9, 0.7, 0.1)
	lock_mesh.mesh.material = lock_mat
	lock_mesh.position = Vector3(0, 0.05, 0.55)
	_lid_pivot.add_child(lock_mesh)


func _build_indicator() -> void:
	var Indicator := preload("res://Scripts/Interactables/InteractableIndicator.gd")
	_indicator = Indicator.new()
	_indicator.name = "InteractableIndicator"
	add_child(_indicator)
	_indicator.set_active(false)


func get_e_label() -> String:
	return "Open" if not _is_open else ""

func get_q_label() -> String:
	return ""

func show_prompt(v: bool) -> void:
	if _indicator:
		_indicator.set_active(v and not _is_open)


func on_e_interact(player_node: Node3D) -> void:
	if _is_open:
		return
	_is_open = true
	_animate_open()

	for item_name in items:
		if player_node.has_method("add_item"):
			player_node.add_item(item_name)

	if _indicator:
		_indicator.set_e_text("")
		_indicator.set_active(false)


func _animate_open() -> void:
	_tween = create_tween().set_parallel(false)
	_tween.tween_property(_lid_pivot, "rotation:x", deg_to_rad(-110.0), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
