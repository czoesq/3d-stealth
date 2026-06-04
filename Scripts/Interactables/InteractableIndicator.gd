extends Node3D

var _visible: bool = false
var _e_panel: Node3D
var _q_panel: Node3D
var _e_label: Label3D
var _q_label: Label3D
var _e_bg_mat: StandardMaterial3D
var _q_bg_mat: StandardMaterial3D
var _q_fill_mesh: MeshInstance3D
var _q_fill_mat: StandardMaterial3D


func _ready() -> void:
	_setup_panels()
	hide()
	set_as_top_level(true)


func _setup_panels() -> void:
	_q_bg_mat = StandardMaterial3D.new()
	_q_bg_mat.albedo_color = Color(0.9, 0.15, 0.1, 0.85)
	_q_bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_q_bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_q_bg_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_q_panel = Node3D.new()
	_q_panel.name = "QPanel"
	_q_panel.position = Vector3(-0.85, 0, 0)
	add_child(_q_panel)

	var q_quad := QuadMesh.new()
	q_quad.size = Vector2(1.0, 0.55)
	var q_bg := MeshInstance3D.new()
	q_bg.mesh = q_quad
	q_bg.material_override = _q_bg_mat
	_q_panel.add_child(q_bg)

	_q_label = Label3D.new()
	_q_label.text = "Break"
	_q_label.font_size = 36
	_q_label.outline_modulate = Color(0, 0, 0, 1)
	_q_label.outline_size = 4
	_q_label.modulate = Color(1, 1, 1, 1)
	_q_label.position = Vector3(0, 0, 0.01)
	_q_panel.add_child(_q_label)

	_q_fill_mat = StandardMaterial3D.new()
	_q_fill_mat.albedo_color = Color(0.9, 0.15, 0.1, 0.85)
	_q_fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_q_fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_q_fill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_q_fill_mesh = MeshInstance3D.new()
	var fill_quad := QuadMesh.new()
	fill_quad.size = Vector2(1.0, 0.55)
	_q_fill_mesh.mesh = fill_quad
	_q_fill_mesh.material_override = _q_fill_mat
	_q_fill_mesh.visible = false
	_q_panel.add_child(_q_fill_mesh)

	_e_bg_mat = StandardMaterial3D.new()
	_e_bg_mat.albedo_color = Color(0.9, 0.8, 0.1, 0.85)
	_e_bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_e_bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_e_bg_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_e_panel = Node3D.new()
	_e_panel.name = "EPanel"
	_e_panel.position = Vector3(0.85, 0, 0)
	add_child(_e_panel)

	var e_quad := QuadMesh.new()
	e_quad.size = Vector2(1.0, 0.55)
	var e_bg := MeshInstance3D.new()
	e_bg.mesh = e_quad
	e_bg.material_override = _e_bg_mat
	_e_panel.add_child(e_bg)

	_e_label = Label3D.new()
	_e_label.text = "Open"
	_e_label.font_size = 36
	_e_label.outline_modulate = Color(0, 0, 0, 1)
	_e_label.outline_size = 4
	_e_label.modulate = Color(1, 1, 1, 1)
	_e_label.position = Vector3(0, 0, 0.01)
	_e_panel.add_child(_e_label)

	visible = false


func _process(_delta: float) -> void:
	var parent := get_parent() as Node3D
	if parent:
		global_position = parent.global_position + Vector3(0, 3.0, 0)
	if not _visible:
		return
	var cam := get_viewport().get_camera_3d()
	if cam:
		var look_dir := (cam.global_position - global_position).normalized()
		var up := Vector3.UP
		if abs(look_dir.dot(up)) > 0.99:
			up = Vector3.FORWARD
		transform.basis = Basis.looking_at(-look_dir, up)


func set_active(v: bool) -> void:
	_visible = v
	visible = v


func set_e_text(text: String) -> void:
	_e_label.text = text


func set_q_text(text: String) -> void:
	_q_label.text = text
	_q_panel.visible = text.length() > 0


func update_hold_progress(pct: float) -> void:
	pct = clampf(pct, 0.0, 1.0)
	if pct > 0.0:
		_q_fill_mesh.visible = true
		_q_fill_mesh.scale.y = pct
		_q_fill_mesh.position.y = -0.275 * (1.0 - pct)
		_q_bg_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.7)
	else:
		_q_fill_mesh.visible = false
		_q_bg_mat.albedo_color = Color(0.9, 0.15, 0.1, 0.85)
