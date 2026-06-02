extends Node3D

var knockout_panel: Node3D
var lethal_panel: Node3D
var indicator_visible: bool = false
var _ko_label: Label3D
var _knockout_mat: StandardMaterial3D
var _lethal_mat: StandardMaterial3D
var _ko_bg_mesh: MeshInstance3D
var _lethal_bg_mesh: MeshInstance3D
var _ko_fill_mesh: MeshInstance3D
var _ko_fill_mat: StandardMaterial3D
var _ko_default_color: Color
var _lethal_default_color: Color
var _flash_tween: Tween


func _ready() -> void:
	_setup_panels()
	hide()
	set_as_top_level(true)


func _setup_panels() -> void:
	_lethal_mat = StandardMaterial3D.new()
	_lethal_mat.albedo_color = Color(0.9, 0.15, 0.1, 0.85)
	_lethal_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lethal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_lethal_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_lethal_default_color = _lethal_mat.albedo_color

	lethal_panel = Node3D.new()
	lethal_panel.name = "LethalPanel"
	lethal_panel.position = Vector3(-0.8, 0, 0)
	add_child(lethal_panel)

	_lethal_bg_mesh = MeshInstance3D.new()
	var lethal_quad := QuadMesh.new()
	lethal_quad.size = Vector2(0.9, 0.9)
	_lethal_bg_mesh.mesh = lethal_quad
	_lethal_bg_mesh.material_override = _lethal_mat
	lethal_panel.add_child(_lethal_bg_mesh)

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
	_knockout_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_knockout_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ko_default_color = _knockout_mat.albedo_color

	knockout_panel = Node3D.new()
	knockout_panel.name = "KnockoutPanel"
	knockout_panel.position = Vector3(0.8, 0, 0)
	add_child(knockout_panel)

	_ko_bg_mesh = MeshInstance3D.new()
	var ko_quad := QuadMesh.new()
	ko_quad.size = Vector2(0.9, 0.9)
	_ko_bg_mesh.mesh = ko_quad
	_ko_bg_mesh.material_override = _knockout_mat
	knockout_panel.add_child(_ko_bg_mesh)

	_ko_fill_mat = StandardMaterial3D.new()
	_ko_fill_mat.albedo_color = Color(0.9, 0.8, 0.1, 0.85)
	_ko_fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ko_fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ko_fill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_ko_fill_mesh = MeshInstance3D.new()
	var fill_quad := QuadMesh.new()
	fill_quad.size = Vector2(0.9, 0.9)
	_ko_fill_mesh.mesh = fill_quad
	_ko_fill_mesh.material_override = _ko_fill_mat
	_ko_fill_mesh.visible = false
	knockout_panel.add_child(_ko_fill_mesh)

	_ko_label = Label3D.new()
	_ko_label.text = "E"
	_ko_label.font_size = 60
	_ko_label.outline_modulate = Color(0, 0, 0, 1)
	_ko_label.outline_size = 4
	_ko_label.modulate = Color(1, 1, 1, 1)
	_ko_label.position = Vector3(0, 0, 0.01)
	knockout_panel.add_child(_ko_label)

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
		var target_basis := Basis.looking_at(-look_dir, up)
		transform.basis = target_basis


func set_mode(mode: String) -> void:
	match mode:
		"takedown":
			lethal_panel.visible = true
			_ko_default_color = Color(0.9, 0.8, 0.1, 0.85)
			_knockout_mat.albedo_color = _ko_default_color
			_ko_label.text = "E"
			knockout_panel.position.x = 0.8
		"drag":
			lethal_panel.visible = false
			_ko_default_color = Color(0.9, 0.8, 0.1, 0.85)
			_knockout_mat.albedo_color = _ko_default_color
			_ko_label.text = "E"
			knockout_panel.position.x = 0.0
		"drop":
			lethal_panel.visible = false
			_ko_default_color = Color(0.2, 0.9, 0.3, 0.85)
			_knockout_mat.albedo_color = _ko_default_color
			_ko_label.text = "DROP"
			knockout_panel.position.x = 0.0


func show_indicators(state: bool) -> void:
	indicator_visible = state
	visible = state
	if _flash_tween:
		_flash_tween.kill()
		_flash_tween = null
	if not state:
		update_hold_progress(0.0)


func update_hold_progress(pct: float) -> void:
	pct = clampf(pct, 0.0, 1.0)
	if pct > 0.0:
		_ko_fill_mesh.visible = true
		_ko_fill_mesh.scale.y = pct
		_ko_fill_mesh.position.y = -0.45 * (1.0 - pct)
		_knockout_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.7)
	else:
		_ko_fill_mesh.visible = false
		_knockout_mat.albedo_color = _ko_default_color


func flash_indicators(panel: String) -> void:
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	var mat: StandardMaterial3D
	var default_color: Color
	match panel:
		"lethal":
			mat = _lethal_mat
			default_color = _lethal_default_color
		"knockout":
			mat = _knockout_mat
			default_color = _ko_default_color
		_:
			return
	_flash_tween.tween_property(mat, "albedo_color", Color.WHITE, 0.1)
	_flash_tween.tween_property(mat, "albedo_color", default_color, 0.4)
