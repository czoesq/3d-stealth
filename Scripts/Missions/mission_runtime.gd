extends Node

signal objective_completed(objective_id: String)
signal primary_objective_changed(new_objective: ObjectiveData)
signal mission_ended(outcome: String)

var primary_objective: ObjectiveData = null
var optional_objectives: Array[ObjectiveData] = []
var completed_objectives: Array[ObjectiveData] = []

var _hud: Control = null

const ObjectiveDataClass = preload("res://Scripts/Missions/objective_data.gd")


func _ready() -> void:
	_find_or_create_hud()


func _find_or_create_hud() -> void:
	var hud_node := get_node_or_null("/root/MissionHUD")
	if not hud_node:
		var root := get_tree().current_scene
		if root:
			var scene = load("res://Scenes/MissionHUD.tscn")
			if scene:
				var layer := CanvasLayer.new()
				layer.name = "MissionHUD"
				var control := scene.instantiate()
				layer.add_child(control)
				root.add_child(layer)
				hud_node = control
	if hud_node:
		set_hud_reference(hud_node)


func set_hud_reference(hud: Control) -> void:
	_hud = hud
	queue_update_hud()


func get_mission_id() -> String:
	return MissionManager.current_mission_id


func get_mission_data() -> MissionData:
	return MissionManager.get_mission(get_mission_id())


func add_objective(objective: ObjectiveData) -> void:
	if objective.is_primary:
		push_warning("MissionRuntime: use replace_primary_objective for primary objectives")
		return

	for existing in optional_objectives:
		if existing.id == objective.id:
			push_warning("MissionRuntime: objective ", objective.id, " already exists")
			return

	optional_objectives.append(objective)
	queue_update_hud()


func complete_objective(objective_id: String) -> void:
	if primary_objective and primary_objective.id == objective_id:
		primary_objective.is_complete = true
		completed_objectives.append(primary_objective)
		primary_objective = null
		objective_completed.emit(objective_id)
		queue_update_hud()
		return

	for i in range(optional_objectives.size() - 1, -1, -1):
		var obj: ObjectiveData = optional_objectives[i]
		if obj.id == objective_id:
			obj.is_complete = true
			completed_objectives.append(obj)
			optional_objectives.remove_at(i)
			objective_completed.emit(objective_id)
			queue_update_hud()
			return

	push_warning("MissionRuntime: objective not found: ", objective_id)


func replace_primary_objective(new_objective: ObjectiveData) -> void:
	if primary_objective:
		primary_objective.is_primary = false
		optional_objectives.append(primary_objective)

	new_objective.is_primary = true
	primary_objective = new_objective
	primary_objective_changed.emit(new_objective)
	queue_update_hud()


func fail_primary_objective(alternate_objective: ObjectiveData) -> void:
	if primary_objective:
		primary_objective.is_complete = true
		completed_objectives.append(primary_objective)

	alternate_objective.is_primary = true
	alternate_objective.is_visible = true
	primary_objective = alternate_objective
	primary_objective_changed.emit(alternate_objective)
	queue_update_hud()


func end_mission(final_outcome: String = "success", rewards_override: Dictionary = {}) -> void:
	if not rewards_override.is_empty():
		var data := get_mission_data()
		if data:
			data.rewards = rewards_override.duplicate()

	MissionManager.complete_mission(get_mission_id(), final_outcome)
	mission_ended.emit(final_outcome)
	MissionManager.current_mission_id = ""


func queue_update_hud() -> void:
	if _hud and _hud.has_method("refresh_objectives"):
		var objs := get_all_visible_objectives()
		var completed := get_completed_objective_ids()
		_hud.refresh_objectives(objs, completed, primary_objective)


func get_all_visible_objectives() -> Array[ObjectiveData]:
	var result: Array[ObjectiveData] = []
	if primary_objective and primary_objective.is_visible:
		result.append(primary_objective)
	for obj in optional_objectives:
		if obj.is_visible:
			result.append(obj)
	return result


func get_completed_objective_ids() -> Array[String]:
	var ids: Array[String] = []
	for obj in completed_objectives:
		ids.append(obj.id)
	return ids
