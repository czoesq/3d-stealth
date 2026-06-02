extends Control

var _primary_label: Label
var _optional_container: VBoxContainer
var _completed_container: VBoxContainer
var _runtime: Node = null


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var panel := Panel.new()
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	var header := Label.new()
	header.text = "MISSION OBJECTIVES"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	vbox.add_child(header)

	var separator := HSeparator.new()
	vbox.add_child(separator)

	_primary_label = Label.new()
	_primary_label.add_theme_font_size_override("font_size", 14)
	_primary_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3, 1))
	_primary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_primary_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	_optional_container = VBoxContainer.new()
	vbox.add_child(_optional_container)

	var sep2 := HSeparator.new()
	sep2.name = "CompletedSeparator"
	vbox.add_child(sep2)

	_completed_container = VBoxContainer.new()
	vbox.add_child(_completed_container)

	_find_runtime()


func _find_runtime() -> void:
	var root := get_tree().current_scene
	if root:
		_runtime = root.find_child("MissionRuntime", true, false)
		if _runtime and _runtime.has_method("set_hud_reference"):
			_runtime.set_hud_reference(self)


func refresh_objectives(objectives: Array, completed_ids: Array[String], primary: ObjectiveData = null) -> void:
	if primary and primary.is_visible:
		_primary_label.text = "[ " + primary.description + " ]"
		_primary_label.show()
	else:
		_primary_label.hide()

	_clear_container(_optional_container)
	_clear_container(_completed_container)

	var has_optional := false
	for obj in objectives:
		if not obj or obj == primary:
			continue
		if not obj.is_visible:
			continue
		if obj.id in completed_ids:
			continue
		var lbl := Label.new()
		lbl.text = "· " + obj.description
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_optional_container.add_child(lbl)
		has_optional = true

	_optional_container.visible = has_optional

	for obj_id in completed_ids:
		var lbl := Label.new()
		lbl.text = "✓ " + obj_id
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4, 0.6))
		_completed_container.add_child(lbl)

	_completed_container.visible = not completed_ids.is_empty()
	get_node_or_null("CompletedSeparator").visible = not completed_ids.is_empty()


func _clear_container(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()
