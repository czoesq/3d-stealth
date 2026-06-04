extends Node

signal mission_selected(mission_id: String)
signal mission_completed(mission_id: String, outcome: String)
signal mission_unlocked(mission_id: String)
signal mission_availability_changed

const PROGRESS_PATH: String = "user://mission_progress.tres"
const MissionDataClass = preload("res://Scripts/Missions/mission_data.gd")
const ProgressClass = preload("res://Scripts/Missions/mission_progress.gd")

var missions: Dictionary = {}
var current_mission_id: String = ""

var _progress: Resource


func _ready() -> void:
	_load_progress()


func _load_progress() -> void:
	if ResourceLoader.exists(PROGRESS_PATH):
		_progress = load(PROGRESS_PATH)
	else:
		_progress = ProgressClass.new()
		_save_progress()


func _save_progress() -> void:
	ResourceSaver.save(_progress, PROGRESS_PATH)


func register_mission(data: MissionData) -> void:
	missions[data.id] = data
	var unlocked: bool = data.id in _progress.unlocked_mission_ids
	var completed: bool = data.id in _progress.completed_mission_ids
	data.is_available = unlocked or data.prerequisites.is_empty()
	data.is_completed = completed
	if not unlocked and data.prerequisites.is_empty():
		_progress.unlocked_mission_ids.append(data.id)
	mission_availability_changed.emit()


func get_mission(mission_id: String) -> MissionData:
	return missions.get(mission_id) as MissionData


func get_available_missions() -> Array[MissionData]:
	var result: Array[MissionData] = []
	for data in missions.values():
		var md := data as MissionData
		if md and md.is_available and not md.is_completed:
			result.append(md)
	return result


func select_mission(mission_id: String) -> void:
	if mission_id not in missions:
		push_error("MissionManager: unknown mission id: ", mission_id)
		return
	current_mission_id = mission_id
	mission_selected.emit(mission_id)


func complete_mission(mission_id: String, outcome: String = "success") -> void:
	if mission_id not in missions:
		push_error("MissionManager: unknown mission id: ", mission_id)
		return

	if mission_id in _progress.completed_mission_ids:
		return

	var data: MissionData = missions[mission_id] as MissionData
	data.is_completed = true

	_progress.completed_mission_ids.append(mission_id)

	var rewards: Dictionary = data.rewards.duplicate()
	var money_amt: int = rewards.get("money", 0)
	var xp_amt: int = rewards.get("xp", 0)
	var stim_amt: int = rewards.get("neural_stimulators", 0)
	var flags: Dictionary = rewards.get("story_flags", {})

	if money_amt != 0 and PlayerData:
		PlayerData.add_money(money_amt)
	if xp_amt != 0 and SkillManager:
		SkillManager.add_xp(xp_amt)
	if stim_amt != 0 and SkillManager:
		SkillManager.add_neural_stimulators(stim_amt)

	if not flags.is_empty() and PlayerData:
		for key in flags:
			PlayerData.set_story_flag(key, flags[key])

	if data.mutually_exclusive_with_id:
		var excl_id: String = data.mutually_exclusive_with_id
		if excl_id in missions:
			var excl_data: MissionData = missions[excl_id] as MissionData
			excl_data.is_available = false
			if excl_id in _progress.unlocked_mission_ids:
				_progress.unlocked_mission_ids.erase(excl_id)

	_save_progress()
	mission_completed.emit(mission_id, outcome)


func unlock_mission(mission_id: String) -> void:
	if mission_id not in missions:
		push_error("MissionManager: unknown mission id: ", mission_id)
		return
	if mission_id in _progress.unlocked_mission_ids:
		return

	_progress.unlocked_mission_ids.append(mission_id)
	var data: MissionData = missions[mission_id] as MissionData
	data.is_available = true
	_save_progress()
	mission_unlocked.emit(mission_id)


func is_mission_unlocked(mission_id: String) -> bool:
	return mission_id in _progress.unlocked_mission_ids


func is_mission_completed(mission_id: String) -> bool:
	return mission_id in _progress.completed_mission_ids


func start_mission(mission_id: String) -> void:
	var data: MissionData = get_mission(mission_id)
	if not data:
		push_error("MissionManager: cannot start unknown mission: ", mission_id)
		return
	if not data.is_available:
		push_error("MissionManager: mission not available: ", mission_id)
		return
	if data.scene_path.is_empty():
		push_error("MissionManager: mission has no scene_path: ", mission_id)
		return

	select_mission(mission_id)

	var err := get_tree().change_scene_to_file(data.scene_path)
	if err != OK:
		push_error("MissionManager: failed to load scene: ", data.scene_path, " error=", err)
