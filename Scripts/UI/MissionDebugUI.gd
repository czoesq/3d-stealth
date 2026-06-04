extends Control


const PANEL_PADDING: float = 16.0
const ROW_HEIGHT: float = 30.0
const MissionDataClass = preload("res://Scripts/Missions/mission_data.gd")
const ObjectiveDataClass = preload("res://Scripts/Missions/objective_data.gd")

var _tab_container: TabContainer
var _mission_list_vbox: VBoxContainer
var _mission_rows_vbox: VBoxContainer
var _runtime_section: VBoxContainer
var _no_runtime_label: Label
var _no_mission_label: Label

var _edit_forms: Dictionary = {}
var _editing_text: bool = false

var _obj_id_edit: LineEdit
var _obj_desc_edit: LineEdit
var _obj_primary_check: CheckBox
var _add_obj_btn: Button

var _complete_obj_dropdown: OptionButton
var _complete_obj_btn: Button

var _replace_pri_id: LineEdit
var _replace_pri_desc: LineEdit
var _replace_pri_btn: Button

var _fail_pri_id: LineEdit
var _fail_pri_desc: LineEdit
var _fail_pri_btn: Button

var _outcome_dropdown: OptionButton
var _reward_money: SpinBox
var _reward_xp: SpinBox
var _reward_stim: SpinBox
var _end_mission_btn: Button

var _start_mission_dropdown: OptionButton
var _start_mission_btn: Button
var _mission_info_label: Label

var _runtime: Node = null
var _pd_money_label: Label
var _pd_xp_label: Label
var _pd_stim_label: Label
var _pd_missions_label: Label
var _was_paused: bool = false


func _ready() -> void:
	process_mode = PROCESS_MODE_WHEN_PAUSED
	_was_paused = get_tree().paused
	if not _was_paused:
		get_tree().paused = true
	_build_ui()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("mission_debug_toggle") or \
	   (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo):
		_close()
		get_viewport().set_input_as_handled()
		return


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and _editing_text:
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
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(vb)

	_title_bar(vb)
	vb.add_theme_constant_override("separation", 6)

	_tab_container = TabContainer.new()
	_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_tab_container)

	_build_runtime_tab()
	_build_missions_tab()

	call_deferred("_center_panel")
	call_deferred("_refresh_all")


func _center_panel() -> void:
	var outer := get_node("Outer") as Control
	var vb := outer.get_node("VBox") as Control
	var screen := Vector2(get_viewport().size)
	var w := maxf(screen.x * 0.7, 720.0)
	var h := screen.y * 0.85
	outer.size = Vector2(w, h)
	outer.position = (screen - outer.size) / 2
	vb.position = Vector2(PANEL_PADDING, PANEL_PADDING)
	vb.size = outer.size - Vector2(PANEL_PADDING * 2, PANEL_PADDING * 2)


func _title_bar(parent: Container) -> void:
	var hb := HBoxContainer.new()
	parent.add_child(hb)

	var title := Label.new()
	title.text = "Mission Debug"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.pressed.connect(_close)
	hb.add_child(close_btn)


func _h_line(parent: Container) -> void:
	var line := HSeparator.new()
	parent.add_child(line)


func _make_small_btn(text: String, w: float = 100.0) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(w, 24)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return btn


func _make_label(text: String, color: Color = Color(1, 1, 1), font_size: int = 12) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lbl


func _make_line_edit(placeholder: String, w: float = 140.0) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = placeholder
	le.custom_minimum_size = Vector2(w, 24)
	le.focus_entered.connect(_on_text_focus_entered)
	le.focus_exited.connect(_on_text_focus_exited)
	return le


func _make_spinbox(min_val: float, max_val: float, val: float, w: float = 70.0) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = min_val
	sb.max_value = max_val
	sb.value = val
	sb.custom_minimum_size = Vector2(w, 24)
	sb.editable = true
	return sb


func _hbox(parent: Container) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(hb)
	return hb


# === Tab 1: Runtime ===

func _build_runtime_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Current Mission"
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_child(tab)

	_mission_info_label = _make_label("")
	tab.add_child(_mission_info_label)

	_no_mission_label = _make_label("No mission selected. Use the Missions tab or Start Mission below.", Color(0.7, 0.7, 0.7))
	tab.add_child(_no_mission_label)

	_h_line(tab)

	# Start mission row
	var start_hb := _hbox(tab)
	start_hb.add_child(_make_label("Start mission:", Color(0.8, 0.9, 1.0)))
	_start_mission_dropdown = OptionButton.new()
	_start_mission_dropdown.custom_minimum_size = Vector2(180, 24)
	start_hb.add_child(_start_mission_dropdown)
	_start_mission_btn = _make_small_btn("Go")
	_start_mission_btn.pressed.connect(_on_start_mission)
	start_hb.add_child(_start_mission_btn)

	_h_line(tab)

	# Runtime section
	_runtime_section = VBoxContainer.new()
	_runtime_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_runtime_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(_runtime_section)

	_no_runtime_label = _make_label("No MissionRuntime found in current scene.", Color(0.7, 0.7, 0.7))
	_runtime_section.add_child(_no_runtime_label)

	# Will be populated on refresh
	_build_runtime_controls()


func _build_runtime_controls() -> void:
	# Primary objective area
	var pri_header := _make_label("PRIMARY OBJECTIVE", Color(1, 0.9, 0.3), 13)
	_runtime_section.add_child(pri_header)

	var pri_label := _make_label("", Color(1, 1, 1))
	pri_label.name = "PrimaryLabel"
	_runtime_section.add_child(pri_label)

	# Replace primary
	var rep_hb := _hbox(_runtime_section)
	_replace_pri_id = _make_line_edit("objective_id")
	rep_hb.add_child(_replace_pri_id)
	_replace_pri_desc = _make_line_edit("description")
	rep_hb.add_child(_replace_pri_desc)
	_replace_pri_btn = _make_small_btn("Replace")
	_replace_pri_btn.pressed.connect(_on_replace_primary)
	rep_hb.add_child(_replace_pri_btn)

	# Fail primary
	var fail_hb := _hbox(_runtime_section)
	_fail_pri_id = _make_line_edit("alternate_id")
	fail_hb.add_child(_fail_pri_id)
	_fail_pri_desc = _make_line_edit("description")
	fail_hb.add_child(_fail_pri_desc)
	_fail_pri_btn = _make_small_btn("Fail→Alt")
	_fail_pri_btn.pressed.connect(_on_fail_primary)
	fail_hb.add_child(_fail_pri_btn)

	_h_line(_runtime_section)

	# Optional objectives
	var opt_header := _make_label("OPTIONAL OBJECTIVES", Color(0.8, 0.9, 1.0), 13)
	opt_header.name = "OptHeader"
	_runtime_section.add_child(opt_header)

	var opt_list := VBoxContainer.new()
	opt_list.name = "OptList"
	_runtime_section.add_child(opt_list)

	_h_line(_runtime_section)

	# Completed objectives
	var comp_header := _make_label("COMPLETED", Color(0.4, 0.8, 0.4), 13)
	comp_header.name = "CompHeader"
	_runtime_section.add_child(comp_header)

	var comp_list := VBoxContainer.new()
	comp_list.name = "CompList"
	_runtime_section.add_child(comp_list)

	_h_line(_runtime_section)

	# Add objective form
	var add_header := _make_label("Add Objective", Color(0.8, 0.9, 1.0), 12)
	_runtime_section.add_child(add_header)

	var add_hb := _hbox(_runtime_section)
	_obj_id_edit = _make_line_edit("objective_id", 120)
	add_hb.add_child(_obj_id_edit)
	_obj_desc_edit = _make_line_edit("description", 180)
	add_hb.add_child(_obj_desc_edit)
	_obj_primary_check = CheckBox.new()
	_obj_primary_check.text = "Primary"
	_obj_primary_check.disabled = true
	add_hb.add_child(_obj_primary_check)
	_add_obj_btn = _make_small_btn("Add")
	_add_obj_btn.pressed.connect(_on_add_objective)
	add_hb.add_child(_add_obj_btn)

	# Complete objective dropdown
	var comp_hb := _hbox(_runtime_section)
	comp_hb.add_child(_make_label("Complete:", Color(0.8, 0.9, 1.0)))
	_complete_obj_dropdown = OptionButton.new()
	_complete_obj_dropdown.custom_minimum_size = Vector2(180, 24)
	comp_hb.add_child(_complete_obj_dropdown)
	_complete_obj_btn = _make_small_btn("Complete")
	_complete_obj_btn.pressed.connect(_on_complete_objective)
	comp_hb.add_child(_complete_obj_btn)

	_h_line(_runtime_section)

	# End mission
	var end_header := _make_label("END MISSION", Color(1, 0.7, 0.5), 13)
	_runtime_section.add_child(end_header)

	var end_hb := _hbox(_runtime_section)
	end_hb.add_child(_make_label("Outcome:", Color(1, 1, 1)))
	_outcome_dropdown = OptionButton.new()
	_outcome_dropdown.custom_minimum_size = Vector2(100, 24)
	_outcome_dropdown.add_item("success")
	_outcome_dropdown.add_item("failure")
	_outcome_dropdown.add_item("abandon")
	end_hb.add_child(_outcome_dropdown)

	end_hb.add_child(_make_label("Money:", Color(1, 1, 1)))
	_reward_money = _make_spinbox(-9999, 9999, 0, 60)
	end_hb.add_child(_reward_money)
	end_hb.add_child(_make_label("XP:", Color(1, 1, 1)))
	_reward_xp = _make_spinbox(-9999, 9999, 0, 60)
	end_hb.add_child(_reward_xp)
	end_hb.add_child(_make_label("Stim:", Color(1, 1, 1)))
	_reward_stim = _make_spinbox(-99, 99, 0, 50)
	end_hb.add_child(_reward_stim)

	_end_mission_btn = _make_small_btn("End Mission", 120)
	_end_mission_btn.pressed.connect(_on_end_mission)
	end_hb.add_child(_end_mission_btn)


# === Tab 2: Missions Database ===

func _build_missions_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Missions"
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.custom_minimum_size = Vector2(400, 200)
	_tab_container.add_child(tab)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(scroll)

	_mission_list_vbox = VBoxContainer.new()
	_mission_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_mission_list_vbox)

	# Rows container — gets cleared on refresh
	_mission_rows_vbox = VBoxContainer.new()
	_mission_rows_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mission_list_vbox.add_child(_mission_rows_vbox)

	# Bottom controls (always present, never cleared by refresh)
	_h_line(_mission_list_vbox)

	var reg_btn := Button.new()
	reg_btn.text = "Register New Mission..."
	reg_btn.pressed.connect(_on_register_new)
	_mission_list_vbox.add_child(reg_btn)

	_h_line(_mission_list_vbox)

	var pd_header := _make_label("Player Data (read-only)", Color(0.6, 0.8, 1.0), 12)
	_mission_list_vbox.add_child(pd_header)

	var pd_hb := _hbox(_mission_list_vbox)
	_pd_money_label = Label.new()
	_pd_money_label.name = "PDMoney"
	_pd_money_label.add_theme_color_override("font_color", Color(1, 1, 0.4))
	pd_hb.add_child(_pd_money_label)
	_pd_xp_label = Label.new()
	_pd_xp_label.name = "PDXP"
	_pd_xp_label.add_theme_color_override("font_color", Color(1, 1, 0.4))
	pd_hb.add_child(_pd_xp_label)
	_pd_stim_label = Label.new()
	_pd_stim_label.name = "PDStim"
	_pd_stim_label.add_theme_color_override("font_color", Color(1, 1, 0.4))
	pd_hb.add_child(_pd_stim_label)

	_pd_missions_label = Label.new()
	_pd_missions_label.name = "PDMissions"
	_pd_missions_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_pd_missions_label.add_theme_font_size_override("font_size", 11)
	_mission_list_vbox.add_child(_pd_missions_label)


# === Refresh ===

func _refresh_all() -> void:
	_refresh_mission_info()
	_refresh_start_dropdown()
	_refresh_runtime()
	_refresh_mission_list()
	_refresh_player_data()

	# Debug: check Missions tab state
	var mt := _tab_container.get_child(1) if _tab_container.get_child_count() > 1 else null
	if mt:
		push_warning("Missions tab visible=" + str(mt.visible) + " size=" + str(mt.size))
		for c in mt.get_children():
			var cc = c as Control
			push_warning("  child " + c.name + " visible=" + str(cc.visible) + " size=" + str(cc.size))
		push_warning("  vbox children=" + str(_mission_list_vbox.get_child_count()) + " rows=" + str(_mission_rows_vbox.get_child_count()))


func _refresh_mission_info() -> void:
	var cid := MissionManager.current_mission_id
	if cid.is_empty():
		_mission_info_label.text = "Current mission: (none)"
		_no_mission_label.show()
	else:
		var data := MissionManager.get_mission(cid)
		if data:
			_mission_info_label.text = "Current mission: %s  |  %s  |  scene: %s" % [cid, data.title, data.scene_path]
		else:
			_mission_info_label.text = "Current mission: %s  (data not found)" % cid
		_no_mission_label.hide()


func _refresh_start_dropdown() -> void:
	_start_mission_dropdown.clear()
	var avail := MissionManager.get_available_missions()
	var has_valid := false
	for data in avail:
		if data.scene_path.is_empty():
			continue
		_start_mission_dropdown.add_item("%s (%s)" % [data.title, data.id])
		has_valid = true
	if not has_valid:
		_start_mission_dropdown.add_item("(no available missions)")
		_start_mission_dropdown.disabled = true
		_start_mission_btn.disabled = true
		return
	_start_mission_dropdown.disabled = false
	_start_mission_btn.disabled = false


func _find_runtime() -> void:
	_runtime = null
	var root := get_tree().current_scene
	if root:
		_runtime = root.find_child("MissionRuntime", true, false)


func _refresh_runtime() -> void:
	_find_runtime()

	if not _runtime:
		_no_runtime_label.show()
		_set_runtime_controls_visible(false)
		return

	_no_runtime_label.hide()
	_set_runtime_controls_visible(true)

	if not _runtime.has_method("get_mission_id"):
		return

	# Primary objective
	var pri = _runtime.primary_objective
	var pri_label := _runtime_section.get_node("PrimaryLabel") as Label
	if pri:
		pri_label.text = "[%s] %s  (visible: %s)" % [pri.id, pri.description, str(pri.is_visible)]
		pri_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	else:
		pri_label.text = "(none)"
		pri_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

	# Optional objectives list
	var opt_list := _runtime_section.get_node("OptList") as VBoxContainer
	_clear_vbox(opt_list)

	for obj in _runtime.optional_objectives:
		var hb := HBoxContainer.new()
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		opt_list.add_child(hb)

		var lbl := Label.new()
		lbl.text = "· %s: %s" % [obj.id, obj.description]
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(lbl)

		var complete_btn := _make_small_btn("Complete", 80)
		complete_btn.pressed.connect(_on_complete_specific.bind(obj.id))
		hb.add_child(complete_btn)

	# Completed objectives list
	var comp_list := _runtime_section.get_node("CompList") as VBoxContainer
	_clear_vbox(comp_list)
	for obj in _runtime.completed_objectives:
		var lbl := Label.new()
		lbl.text = "✓ %s — %s" % [obj.id, obj.description]
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
		comp_list.add_child(lbl)

	# Complete objective dropdown
	_complete_obj_dropdown.clear()
	var all_active := _get_active_objective_ids()
	if all_active.is_empty():
		_complete_obj_dropdown.add_item("(no active objectives)")
		_complete_obj_dropdown.disabled = true
		_complete_obj_btn.disabled = true
	else:
		for oid in all_active:
			_complete_obj_dropdown.add_item(oid)
		_complete_obj_dropdown.disabled = false
		_complete_obj_btn.disabled = false


func _get_active_objective_ids() -> Array[String]:
	var ids: Array[String] = []
	if _runtime and _runtime.primary_objective and not _runtime.primary_objective.is_complete:
		ids.append(_runtime.primary_objective.id)
	if _runtime:
		for obj in _runtime.optional_objectives:
			ids.append(obj.id)
	return ids


func _set_runtime_controls_visible(v: bool) -> void:
	for child in _runtime_section.get_children():
		if child != _no_runtime_label:
			child.visible = v


func _refresh_mission_list() -> void:
	_clear_vbox(_mission_rows_vbox)

	if MissionManager.missions.is_empty():
		var lbl := _make_label("No missions registered.", Color(0.7, 0.7, 0.7))
		_mission_rows_vbox.add_child(lbl)
		return

	for mid in MissionManager.missions:
		var data: MissionData = MissionManager.missions[mid] as MissionData
		if not data:
			continue

		var hb := HBoxContainer.new()
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.custom_minimum_size = Vector2(0, ROW_HEIGHT)
		_mission_rows_vbox.add_child(hb)

		var status_icon := Label.new()
		status_icon.custom_minimum_size = Vector2(20, 0)
		status_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if data.is_completed:
			status_icon.text = "✓"
			status_icon.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
		elif data.is_available:
			status_icon.text = "·"
			status_icon.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		else:
			status_icon.text = "✗"
			status_icon.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
		hb.add_child(status_icon)

		var name_lbl := Label.new()
		name_lbl.text = data.title
		name_lbl.custom_minimum_size = Vector2(140, 0)
		name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		hb.add_child(name_lbl)

		var id_lbl := Label.new()
		id_lbl.text = data.id
		id_lbl.custom_minimum_size = Vector2(100, 0)
		id_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
		id_lbl.add_theme_font_size_override("font_size", 11)
		hb.add_child(id_lbl)

		var scene_lbl := Label.new()
		scene_lbl.text = data.scene_path.get_file() if not data.scene_path.is_empty() else "(no scene)"
		scene_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scene_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		scene_lbl.add_theme_font_size_override("font_size", 11)
		hb.add_child(scene_lbl)

		var edit_btn := _make_small_btn("Edit", 50)
		edit_btn.pressed.connect(_on_edit_mission.bind(mid))
		hb.add_child(edit_btn)

		if not MissionManager.is_mission_unlocked(mid):
			var unlock_btn := _make_small_btn("Unlock", 60)
			unlock_btn.pressed.connect(_on_unlock_mission.bind(mid))
			hb.add_child(unlock_btn)

		if data.is_available and not data.is_completed and not data.scene_path.is_empty():
			var start_btn := _make_small_btn("Start", 50)
			start_btn.pressed.connect(_on_start_specific.bind(mid))
			hb.add_child(start_btn)

		# Expanded edit form (hidden initially)
		var edit_vbox := VBoxContainer.new()
		edit_vbox.name = "Edit_%s" % mid
		edit_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit_vbox.hide()
		_mission_rows_vbox.add_child(edit_vbox)
		_edit_forms[mid] = edit_vbox

		_build_edit_form(edit_vbox, data, mid)


func _get_scene_paths() -> Array[String]:
	var paths: Array[String] = []
	_scan_dir("res://", paths)
	return paths


func _scan_dir(dir_path: String, paths: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
	for f in dir.get_files():
		if f.ends_with(".tscn"):
			paths.append(dir_path.path_join(f))
	for d in dir.get_directories():
		if not d.begins_with("."):
			_scan_dir(dir_path.path_join(d), paths)


func _get_mission_ids() -> Array[String]:
	var ids: Array[String] = []
	for mid in MissionManager.missions:
		ids.append(mid)
	return ids


func _make_field_row(parent: VBoxContainer, label: String, text: String) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(hb)
	var lbl := Label.new()
	lbl.text = label.capitalize() + ":"
	lbl.custom_minimum_size = Vector2(160, 0)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	hb.add_child(lbl)
	var le := _make_line_edit(text, 200)
	le.text = text
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(le)
	return hb


func _build_edit_form(parent: VBoxContainer, data: MissionData, mid: String) -> void:
	var edits := {}

	# ── Basic Info ──
	parent.add_child(_make_label("─ Basic Info ─", Color(0.6, 0.8, 1.0), 13))

	var title_hb := _make_field_row(parent, "title", data.title)
	var title_le := title_hb.get_child(1) as LineEdit
	edits["title"] = title_le

	var desc_hb := _make_field_row(parent, "description", data.description)
	var desc_le := desc_hb.get_child(1) as LineEdit
	edits["description"] = desc_le

	# ── Mission Config ──
	parent.add_child(_make_label("─ Mission Config ─", Color(0.6, 0.8, 1.0), 13))

	var scene_hb := HBoxContainer.new()
	scene_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(scene_hb)
	var scene_lbl := Label.new()
	scene_lbl.text = "scene path:"
	scene_lbl.custom_minimum_size = Vector2(160, 0)
	scene_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	scene_hb.add_child(scene_lbl)
	var scene_dd := OptionButton.new()
	scene_dd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scene_dd.add_item("(none)", 0)
	for p in _get_scene_paths():
		scene_dd.add_item(p)
	for i in scene_dd.item_count:
		if scene_dd.get_item_text(i) == data.scene_path:
			scene_dd.select(i)
			break
	scene_hb.add_child(scene_dd)
	scene_dd.focus_entered.connect(_on_text_focus_entered)
	scene_dd.focus_exited.connect(_on_text_focus_exited)
	edits["scene_path"] = scene_dd

	var excl_hb := HBoxContainer.new()
	excl_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(excl_hb)
	var excl_lbl := Label.new()
	excl_lbl.text = "mutually exclusive with:"
	excl_lbl.custom_minimum_size = Vector2(160, 0)
	excl_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	excl_hb.add_child(excl_lbl)
	var excl_dd := OptionButton.new()
	excl_dd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	excl_dd.add_item("(none)", 0)
	for m_id in _get_mission_ids():
		if m_id != mid:
			excl_dd.add_item(m_id)
	for i in excl_dd.item_count:
		if excl_dd.get_item_text(i) == data.mutually_exclusive_with_id:
			excl_dd.select(i)
			break
	excl_hb.add_child(excl_dd)
	excl_dd.focus_entered.connect(_on_text_focus_entered)
	excl_dd.focus_exited.connect(_on_text_focus_exited)
	edits["mutually_exclusive_with_id"] = excl_dd

	var cb_hb := HBoxContainer.new()
	cb_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(cb_hb)

	var is_campaign_cb := CheckBox.new()
	is_campaign_cb.text = "is_campaign"
	is_campaign_cb.button_pressed = data.is_campaign
	cb_hb.add_child(is_campaign_cb)

	var is_available_cb := CheckBox.new()
	is_available_cb.text = "is_available"
	is_available_cb.button_pressed = data.is_available
	cb_hb.add_child(is_available_cb)

	# ── Rewards & Prerequisites ──
	parent.add_child(_make_label("─ Rewards & Prerequisites ─", Color(0.6, 0.8, 1.0), 13))

	var rew_hb := HBoxContainer.new()
	rew_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(rew_hb)
	rew_hb.add_child(_make_label("Rewards:", Color(0.8, 0.8, 0.8)))

	var r_money := _make_spinbox(-9999, 9999, data.rewards.get("money", 0), 60)
	r_money.suffix = " $"
	rew_hb.add_child(r_money)
	var r_xp := _make_spinbox(-9999, 9999, data.rewards.get("xp", 0), 60)
	r_xp.suffix = " XP"
	rew_hb.add_child(r_xp)
	var r_stim := _make_spinbox(-99, 99, data.rewards.get("neural_stimulators", 0), 50)
	r_stim.suffix = " stim"
	rew_hb.add_child(r_stim)

	var preq_hb := HBoxContainer.new()
	preq_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(preq_hb)
	preq_hb.add_child(_make_label("Prerequisites (comma-sep):", Color(0.8, 0.8, 0.8)))
	var preq_le := _make_line_edit("", 200)
	preq_le.text = ",".join(data.prerequisites)
	preq_le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preq_hb.add_child(preq_le)

	# Save button
	_h_line(parent)
	var save_btn := _make_small_btn("Save Changes", 120)
	save_btn.pressed.connect(_on_save_mission_edit.bind(mid, edits, is_campaign_cb, is_available_cb, r_money, r_xp, r_stim, preq_le, scene_dd, excl_dd))
	parent.add_child(save_btn)


func _refresh_player_data() -> void:
	if not _pd_money_label:
		return

	var money_val = PlayerData.money if PlayerData else 0
	var xp_val = SkillManager.get_total_xp() if SkillManager else 0
	var stim_val = SkillManager.get_neural_stimulators() if SkillManager else 0
	_pd_money_label.text = "Money: %d" % money_val
	_pd_xp_label.text = "  XP: %d" % xp_val
	_pd_stim_label.text = "  Stimulators: %d" % stim_val

	_pd_missions_label.text = "Completed: %s  |  Unlocked: %s" % [
		str(MissionManager._progress.completed_mission_ids),
		str(MissionManager._progress.unlocked_mission_ids),
	]


# === Handlers ===

func _on_add_objective() -> void:
	if not _runtime or not _runtime.has_method("add_objective"):
		return
	var oid := _obj_id_edit.text.strip_edges()
	if oid.is_empty():
		return
	var obj := ObjectiveDataClass.new()
	obj.id = oid
	obj.description = _obj_desc_edit.text.strip_edges()
	obj.is_primary = false
	obj.is_visible = true
	_runtime.add_objective(obj)
	_refresh_runtime()


func _on_complete_objective() -> void:
	if not _runtime or not _runtime.has_method("complete_objective"):
		return
	var idx := _complete_obj_dropdown.selected
	if idx < 0:
		return
	var oid := _complete_obj_dropdown.get_item_text(idx)
	_runtime.complete_objective(oid)
	_refresh_runtime()


func _on_complete_specific(oid: String) -> void:
	if _runtime and _runtime.has_method("complete_objective"):
		_runtime.complete_objective(oid)
		_refresh_runtime()


func _on_replace_primary() -> void:
	if not _runtime or not _runtime.has_method("replace_primary_objective"):
		return
	var oid := _replace_pri_id.text.strip_edges()
	if oid.is_empty():
		return
	var obj := ObjectiveDataClass.new()
	obj.id = oid
	obj.description = _replace_pri_desc.text.strip_edges()
	obj.is_primary = true
	obj.is_visible = true
	_runtime.replace_primary_objective(obj)
	_refresh_runtime()


func _on_fail_primary() -> void:
	if not _runtime or not _runtime.has_method("fail_primary_objective"):
		return
	var oid := _fail_pri_id.text.strip_edges()
	if oid.is_empty():
		return
	var obj := ObjectiveDataClass.new()
	obj.id = oid
	obj.description = _fail_pri_desc.text.strip_edges()
	obj.is_primary = true
	obj.is_visible = true
	_runtime.fail_primary_objective(obj)
	_refresh_runtime()


func _on_end_mission() -> void:
	if not _runtime or not _runtime.has_method("end_mission"):
		return
	var outcome_idx := _outcome_dropdown.selected
	var outcome := _outcome_dropdown.get_item_text(outcome_idx) if outcome_idx >= 0 else "success"

	var override := {}
	if _reward_money.value != 0 or _reward_xp.value != 0 or _reward_stim.value != 0:
		override["money"] = int(_reward_money.value)
		override["xp"] = int(_reward_xp.value)
		override["neural_stimulators"] = int(_reward_stim.value)

	_runtime.end_mission(outcome, override)
	_refresh_all()


func _on_start_mission() -> void:
	var idx := _start_mission_dropdown.selected
	if idx < 0:
		return
	var text := _start_mission_dropdown.get_item_text(idx)
	var open_paren := text.rfind("(")
	if open_paren < 0:
		return
	var mid := text.substr(open_paren + 1, text.length() - open_paren - 2)
	MissionManager.start_mission(mid)


func _on_start_specific(mid: String) -> void:
	MissionManager.start_mission(mid)


func _on_unlock_mission(mid: String) -> void:
	MissionManager.unlock_mission(mid)
	_refresh_mission_list()
	_refresh_start_dropdown()
	_refresh_player_data()


func _on_edit_mission(mid: String) -> void:
	var form := _edit_forms.get(mid) as VBoxContainer
	if form:
		form.visible = not form.visible
		call_deferred("_center_panel")


func _on_save_mission_edit(mid: String, edits: Dictionary, is_campaign_cb: CheckBox, is_available_cb: CheckBox, r_money: SpinBox, r_xp: SpinBox, r_stim: SpinBox, preq_le: LineEdit, scene_dd: OptionButton, excl_dd: OptionButton) -> void:
	var data := MissionManager.get_mission(mid)
	if not data:
		return

	data.title = edits["title"].text
	data.description = edits["description"].text
	data.scene_path = "" if scene_dd.selected == 0 else scene_dd.get_item_text(scene_dd.selected)
	data.mutually_exclusive_with_id = "" if excl_dd.selected == 0 else excl_dd.get_item_text(excl_dd.selected)
	data.is_campaign = is_campaign_cb.button_pressed
	data.is_available = is_available_cb.button_pressed
	data.rewards["money"] = int(r_money.value)
	data.rewards["xp"] = int(r_xp.value)
	data.rewards["neural_stimulators"] = int(r_stim.value)

	var preq_text := preq_le.text.strip_edges()
	data.prerequisites.assign(preq_text.split(",", false))

	_refresh_mission_list()
	_center_panel()


func _on_register_new() -> void:
	var data := MissionDataClass.new()
	var rid := "mission_%d" % randi()
	data.id = rid
	data.title = rid.capitalize()
	data.description = "A test mission created at runtime."
	data.scene_path = ""
	data.is_campaign = false
	data.is_available = true
	data.is_completed = false
	data.mutually_exclusive_with_id = ""
	data.prerequisites = []
	data.rewards = {"money": 0, "xp": 0, "neural_stimulators": 0, "story_flags": {}}
	MissionManager.register_mission(data)
	_refresh_mission_list()
	_refresh_start_dropdown()
	_tab_container.current_tab = 1


func _clear_vbox(vbox: VBoxContainer) -> void:
	for child in vbox.get_children():
		vbox.remove_child(child)
		child.queue_free()


func _on_text_focus_entered() -> void:
	_editing_text = true


func _on_text_focus_exited() -> void:
	_editing_text = false


func _exit_tree() -> void:
	if not _was_paused:
		get_tree().paused = false


func _close() -> void:
	queue_free()
