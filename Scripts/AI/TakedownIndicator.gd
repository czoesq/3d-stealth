extends Node3D

var knockout_panel: Node3D
var lethal_panel: Node3D
var progress_bar: MeshInstance3D
var indicator_visible: bool = false
var _ko_label: Label3D
var _knockout_mat: StandardMaterial3D
var _lethal_mat: StandardMaterial3D


func _ready() -> void:
	_setup_panels()
	hide()
	set_as_top_level(true)


func _setup_panels() -> void:
	_lethal_mat = StandardMaterial3D.new()
	_lethal_mat.albedo_color = Color(0.9, 0.15, 0.1, 0.85)
	_lethal_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lethal_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_lethal_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	lethal_panel = Node3D.new()
	lethal_panel.name = "LethalPanel"
	lethal_panel.position = Vector3(-0.8, 0, 0)
	add_child(lethal_panel)

	var lethal_bg := MeshInstance3D.new()
	var lethal_quad := QuadMesh.new()
	lethal_quad.size = Vector2(0.9, 0.9)
	lethal_bg.mesh = lethal_quad
	lethal_bg.material_override = _lethal_mat
	lethal_panel.add_child(lethal_bg)

	var lethal_label := Label3D.new()
	lethal_label.text = "Q"
	lethal_label.font_size = 60
	lethal_label.outline_modulate = Color(0, 0, 0, 1)
	lethal_label.outline_size = 4
	lethal_label.modulate = Color(1, 1, 1, 1)
	lethal_label.position = Vector3(0, 0, 0.01)
	lethal_panel.add_child(lethal_label)

	_knockout_mat = StandardMaterial3D.new()
	_knockout_mat.albedo_color = Color(0.9, 0.8, 0.1, 0.85)
	_knockout_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_knockout_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_knockout_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	knockout_panel = Node3D.new()
	knockout_panel.name = "KnockoutPanel"
	knockout_panel.position = Vector3(0.8, 0, 0)
	add_child(knockout_panel)

	var ko_bg := MeshInstance3D.new()
	var ko_quad := QuadMesh.new()
	ko_quad.size = Vector2(0.9, 0.9)
	ko_bg.mesh = ko_quad
	ko_bg.material_override = _knockout_mat
	knockout_panel.add_child(ko_bg)

	_ko_label = Label3D.new()
	_ko_label.text = "E"
	_ko_label.font_size = 60
	_ko_label.outline_modulate = Color(0, 0, 0, 1)
	_ko_label.outline_size = 4
	_ko_label.modulate = Color(1, 1, 1, 1)
	_ko_label.position = Vector3(0, 0, 0.01)
	knockout_panel.add_child(_ko_label)

	var progress_mat := StandardMaterial3D.new()
	progress_mat.albedo_color = Color(0.3, 0.9, 0.3, 0.9)
	progress_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	progress_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

	progress_bar = MeshInstance3D.new()
	var progress_quad := QuadMesh.new()
	progress_quad.size = Vector2(0.0, 0.12)
	progress_bar.mesh = progress_quad
	progress_bar.material_override = progress_mat
	progress_bar.position = Vector3(0, -0.55, 0.01)
	knockout_panel.add_child(progress_bar)

	visible = false


func _process(_delta: float) -> void:
	var parent := get_parent() as Node3D
	if parent:
		global_position = parent.global_position + Vector3(0, 3.0, 0)
	if not indicator_visible:
		return
	var cam := get_viewport().get_camera_3d()
	if cam:
		var look_dir := (cam.global_position - global_position).normalized()
		var up := Vector3.UP
		if abs(look_dir.dot(up)) > 0.99:
			up = Vector3.FORWARD
		var target_basis := Basis.looking_at(look_dir, up)
		transform.basis = target_basis


func set_mode(mode: String) -> void:
	match mode:
		"takedown":
			lethal_panel.visible = true
			_knockout_mat.albedo_color = Color(0.9, 0.8, 0.1, 0.85)
			_ko_label.text = "E"
			knockout_panel.position.x = 0.8
		"drag":
			lethal_panel.visible = false
			_knockout_mat.albedo_color = Color(0.9, 0.8, 0.1, 0.85)
			_ko_label.text = "E"
			knockout_panel.position.x = 0.0
		"drop":
			lethal_panel.visible = false
			_knockout_mat.albedo_color = Color(0.2, 0.9, 0.3, 0.85)
			_ko_label.text = "DROP"
			knockout_panel.position.x = 0.0


func show_indicators(state: bool) -> void:
	indicator_visible = state
	visible = state
	if not state:
		update_hold_progress(0.0)


func update_hold_progress(pct: float) -> void:
	pct = clampf(pct, 0.0, 1.0)
	if progress_bar and progress_bar.mesh is QuadMesh:
		var qm := progress_bar.mesh as QuadMesh
		qm.size = Vector2(0.75 * pct, 0.12)
