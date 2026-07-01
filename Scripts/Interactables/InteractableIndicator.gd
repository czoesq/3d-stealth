extends Node3D

var _visible: bool = false
var _world_pos: Vector3
var _e_panel: Node3D
var _q_panel: Node3D
var _e_label: Label3D
var _q_label: Label3D
var _e_label_2d: Label
var _q_label_2d: Label
var _e_bg_mat: ShaderMaterial
var _q_bg_mat: ShaderMaterial
var _q_fill_mesh: MeshInstance3D
var _q_fill_mat: ShaderMaterial
var _canvas: CanvasLayer

const _on_top_shader := preload("res://Shaders/unshaded_on_top.gdshader")


func _ready() -> void:
	_setup_panels()
	hide()
	set_as_top_level(true)
	call_deferred("_setup_canvas")


func _exit_tree() -> void:
	if _canvas and is_instance_valid(_canvas) and _canvas.get_parent():
		_canvas.queue_free()


func _setup_canvas() -> void:
	_canvas = CanvasLayer.new()
	_canvas.name = "InteractOverlay_" + str(get_instance_id())
	_canvas.layer = 1
	var root := get_tree().current_scene
	if root:
		root.add_child(_canvas)
	else:
		get_parent().add_child(_canvas)

	_e_label_2d = Label.new()
	_e_label_2d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_e_label_2d.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_e_label_2d.add_theme_font_size_override("font_size", 28)
	_e_label_2d.add_theme_color_override("font_outline_color", Color.BLACK)
	_e_label_2d.add_theme_constant_override("outline_size", 4)
	_e_label_2d.modulate = Color(0.9, 0.8, 0.1, 0.85)
	_e_label_2d.visible = false
	_canvas.add_child(_e_label_2d)

	_q_label_2d = Label.new()
	_q_label_2d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_q_label_2d.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_q_label_2d.add_theme_font_size_override("font_size", 28)
	_q_label_2d.add_theme_color_override("font_outline_color", Color.BLACK)
	_q_label_2d.add_theme_constant_override("outline_size", 4)
	_q_label_2d.modulate = Color(0.9, 0.15, 0.1, 0.85)
	_q_label_2d.visible = false
	_canvas.add_child(_q_label_2d)


func _setup_panels() -> void:
	_q_bg_mat = ShaderMaterial.new()
	_q_bg_mat.shader = _on_top_shader
	_q_bg_mat.set_shader_parameter("albedo", Color(0.9, 0.15, 0.1, 0.85))

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

	_q_fill_mat = ShaderMaterial.new()
	_q_fill_mat.shader = _on_top_shader
	_q_fill_mat.set_shader_parameter("albedo", Color(0.9, 0.15, 0.1, 0.85))

	_q_fill_mesh = MeshInstance3D.new()
	var fill_quad := QuadMesh.new()
	fill_quad.size = Vector2(1.0, 0.55)
	_q_fill_mesh.mesh = fill_quad
	_q_fill_mesh.material_override = _q_fill_mat
	_q_fill_mesh.visible = false
	_q_panel.add_child(_q_fill_mesh)

	_e_bg_mat = ShaderMaterial.new()
	_e_bg_mat.shader = _on_top_shader
	_e_bg_mat.set_shader_parameter("albedo", Color(0.9, 0.8, 0.1, 0.85))

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
		_world_pos = parent.global_position + Vector3(0, 3.0, 0)
		global_position = _world_pos
	if not _visible or not _e_label_2d:
		if _e_label_2d:
			_e_label_2d.visible = false
		if _q_label_2d:
			_q_label_2d.visible = false
		return
	var cam := get_viewport().get_camera_3d()
	if cam:
		var look_dir := (cam.global_position - global_position).normalized()
		var up := Vector3.UP
		if abs(look_dir.dot(up)) > 0.99:
			up = Vector3.FORWARD
		transform.basis = Basis.looking_at(-look_dir, up)

		var screen_pos := cam.unproject_position(_world_pos)
		var e_size := _e_label_2d.get_minimum_size()
		var q_size := _q_label_2d.get_minimum_size()
		_e_label_2d.position = screen_pos + Vector2(85 - e_size.x * 0.5, -e_size.y * 0.5)
		_e_label_2d.visible = _e_label_2d.text.length() > 0
		_q_label_2d.position = screen_pos + Vector2(-85 - q_size.x * 0.5, -q_size.y * 0.5)
		_q_label_2d.visible = _q_label_2d.text.length() > 0


func set_active(v: bool) -> void:
	_visible = v
	visible = v
	if not v:
		if _e_label_2d:
			_e_label_2d.visible = false
		if _q_label_2d:
			_q_label_2d.visible = false


func set_e_text(text: String) -> void:
	_e_label.text = text
	if _e_label_2d:
		_e_label_2d.text = text


func set_q_text(text: String) -> void:
	_q_label.text = text
	if _q_label_2d:
		_q_label_2d.text = text
	_q_panel.visible = text.length() > 0


func update_hold_progress(pct: float) -> void:
	pct = clampf(pct, 0.0, 1.0)
	if pct > 0.0:
		_q_fill_mesh.visible = true
		_q_fill_mesh.scale.y = pct
		_q_fill_mesh.position.y = -0.275 * (1.0 - pct)
		_q_bg_mat.set_shader_parameter("albedo", Color(0.0, 0.0, 0.0, 0.7))
	else:
		_q_fill_mesh.visible = false
		_q_bg_mat.set_shader_parameter("albedo", Color(0.9, 0.15, 0.1, 0.85))
