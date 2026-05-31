extends Control


const PANEL_WIDTH: float = 420.0
const PANEL_PADDING: float = 16.0
const ROW_HEIGHT: float = 32.0
const SKILL_NAMES: Array[String] = ["stealth", "hacking", "subdue", "awareness", "gadgets"]

var _skill_rows: Dictionary = {}
var _stimulator_label: Label
var _xp_label: Label


func _ready() -> void:
	_build_ui()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("skill_debug_toggle") or \
	   (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo):
		_close()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	anchor_right = 1.0
	anchor_bottom = 1.0

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.55)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var outer := Panel.new()
	outer.name = "Outer"
	add_child(outer)

	var vb := VBoxContainer.new()
	vb.name = "VBox"
	vb.add_theme_constant_override("separation", 4)
	outer.add_child(vb)
	vb.position = Vector2(PANEL_PADDING, PANEL_PADDING)

	_title_bar(vb)
	vb.add_theme_constant_override("separation", 6)
	_h_line(vb)
	_skill_section(vb)
	_h_line(vb)
	_stimulator_row(vb)
	_xp_row(vb)

	call_deferred("_center_panel")


func _center_panel() -> void:
	var outer := get_node("Outer") as Control
	var vb := outer.get_node("VBox") as Control
	var content := vb.get_minimum_size()
	outer.size = content + Vector2(PANEL_PADDING * 2, PANEL_PADDING * 2)
	var screen := get_viewport_rect().size
	outer.position = (screen - outer.size) / 2


func _title_bar(parent: Container) -> void:
	var hb := HBoxContainer.new()
	parent.add_child(hb)

	var title := Label.new()
	title.text = "Skills Debug"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(title)

	var reset_btn := Button.new()
	reset_btn.text = "Reset"
	reset_btn.custom_minimum_size = Vector2(50, 30)
	reset_btn.pressed.connect(_on_reset)
	hb.add_child(reset_btn)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.pressed.connect(_close)
	hb.add_child(close_btn)


func _h_line(parent: Container) -> void:
	var line := HSeparator.new()
	parent.add_child(line)


func _skill_section(parent: Container) -> void:
	var header := Label.new()
	header.text = "Skills"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	parent.add_child(header)

	for skill_name in SKILL_NAMES:
		var row := _make_skill_row(skill_name)
		parent.add_child(row)
		_skill_rows[skill_name] = row


func _make_skill_row(skill_name: String) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = skill_name.capitalize()
	name_label.custom_minimum_size = Vector2(100, 0)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	hb.add_child(name_label)

	var level_label := Label.new()
	level_label.name = "Level"
	level_label.custom_minimum_size = Vector2(60, 0)
	level_label.add_theme_color_override("font_color", Color(1, 1, 1))
	hb.add_child(level_label)

	var action_btn := Button.new()
	action_btn.name = "Action"
	action_btn.custom_minimum_size = Vector2(160, 0)
	hb.add_child(action_btn)

	var status_label := Label.new()
	status_label.name = "Status"
	status_label.custom_minimum_size = Vector2(80, 0)
	status_label.add_theme_color_override("font_color", Color(1, 1, 1))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(status_label)

	_refresh_skill_row(skill_name, level_label, action_btn, status_label)
	return hb


func _refresh_skill_row(skill_name: String, level_label: Label, action_btn: Button, status_label: Label) -> void:
	var level := SkillManager.get_skill_level(skill_name)
	var unlocked := SkillManager.is_skill_unlocked(skill_name)
	var cost := SkillManager.get_next_level_xp_cost(skill_name)
	var xp := SkillManager.get_total_xp()

	level_label.text = "Lv %d" % level

	if action_btn.pressed.is_connected(_on_skill_action):
		action_btn.pressed.disconnect(_on_skill_action)

	if not unlocked:
		action_btn.text = "Unlock (1 stim)"
		action_btn.disabled = SkillManager.get_neural_stimulators() <= 0
		status_label.text = "Locked"
		status_label.add_theme_color_override("font_color", Color(1, 0.6, 0.2))
	elif cost < 0:
		action_btn.text = "MAX"
		action_btn.disabled = true
		status_label.text = "Maxed"
		status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		return
	elif xp >= cost:
		action_btn.text = "Upgrade (%d XP)" % cost
		action_btn.disabled = false
		status_label.text = "Ready"
		status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	else:
		action_btn.text = "Need %d XP" % cost
		action_btn.disabled = true
		status_label.text = "Locked"
		status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		return

	action_btn.pressed.connect(_on_skill_action.bind(skill_name, level_label, action_btn, status_label))


func _on_skill_action(skill_name: String, level_label: Label, action_btn: Button, status_label: Label) -> void:
	if not SkillManager.is_skill_unlocked(skill_name):
		SkillManager.unlock_skill_tree(skill_name)
	else:
		SkillManager.upgrade_skill(skill_name)
	_refresh_skill_row(skill_name, level_label, action_btn, status_label)
	_refresh_global_stats()


func _stimulator_row(parent: Container) -> void:
	var hb := HBoxContainer.new()
	hb.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	parent.add_child(hb)

	var label := Label.new()
	label.text = "Neural Stimulators:"
	label.custom_minimum_size = Vector2(240, 0)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	hb.add_child(label)

	_stimulator_label = Label.new()
	_stimulator_label.text = str(SkillManager.get_neural_stimulators())
	_stimulator_label.custom_minimum_size = Vector2(40, 0)
	_stimulator_label.add_theme_color_override("font_color", Color(1, 1, 0.4))
	hb.add_child(_stimulator_label)

	var btn := Button.new()
	btn.text = "+"
	btn.custom_minimum_size = Vector2(36, 30)
	btn.pressed.connect(_on_add_stimulator)
	hb.add_child(btn)


func _xp_row(parent: Container) -> void:
	var hb := HBoxContainer.new()
	hb.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	parent.add_child(hb)

	var label := Label.new()
	label.text = "Total XP:"
	label.custom_minimum_size = Vector2(240, 0)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	hb.add_child(label)

	_xp_label = Label.new()
	_xp_label.text = str(SkillManager.get_total_xp())
	_xp_label.custom_minimum_size = Vector2(40, 0)
	_xp_label.add_theme_color_override("font_color", Color(1, 1, 0.4))
	hb.add_child(_xp_label)

	var btn := Button.new()
	btn.text = "+"
	btn.custom_minimum_size = Vector2(36, 30)
	btn.pressed.connect(_on_add_xp)
	hb.add_child(btn)


func _on_add_stimulator() -> void:
	SkillManager.add_neural_stimulators(1)
	_refresh_global_stats()
	for skill_name in SKILL_NAMES:
		var row := _skill_rows.get(skill_name) as HBoxContainer
		if row:
			var lv := row.get_node("Level") as Label
			var act := row.get_node("Action") as Button
			var st := row.get_node("Status") as Label
			_refresh_skill_row(skill_name, lv, act, st)


func _on_add_xp() -> void:
	SkillManager.add_xp(100)
	_refresh_global_stats()
	for skill_name in SKILL_NAMES:
		var row := _skill_rows.get(skill_name) as HBoxContainer
		if row:
			var lv := row.get_node("Level") as Label
			var act := row.get_node("Action") as Button
			var st := row.get_node("Status") as Label
			_refresh_skill_row(skill_name, lv, act, st)


func _refresh_global_stats() -> void:
	_stimulator_label.text = str(SkillManager.get_neural_stimulators())
	_xp_label.text = str(SkillManager.get_total_xp())


func _on_reset() -> void:
	SkillManager.reset_to_defaults()
	for skill_name in SKILL_NAMES:
		var row := _skill_rows.get(skill_name) as HBoxContainer
		if row:
			var lv := row.get_node("Level") as Label
			var act := row.get_node("Action") as Button
			var st := row.get_node("Status") as Label
			_refresh_skill_row(skill_name, lv, act, st)
	_refresh_global_stats()


func _close() -> void:
	queue_free()
