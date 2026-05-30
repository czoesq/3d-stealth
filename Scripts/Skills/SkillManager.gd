extends Node

signal xp_changed(new_total: int)
signal skill_upgraded(skill_name: String, new_level: int)
signal neural_stimulators_changed(new_count: int)

const SAVE_PATH: String = "user://SkillSaveData.tres"

const SKILL_NAMES: Array[String] = ["stealth", "hacking", "subdue", "awareness", "gadgets"]

const MAX_SKILL_LEVEL: int = 5

const XP_COST_PER_LEVEL: Dictionary = {
	"stealth": 100,
	"hacking": 100,
	"subdue": 150,
	"awareness": 150,
	"gadgets": 200,
}

const REQUIRES_STIMULATOR: Dictionary = {
	"stealth": false,
	"hacking": false,
	"subdue": true,
	"awareness": true,
	"gadgets": true,
}

const SkillSaveData = preload("res://Scripts/Skills/SkillSaveData.gd")

var save_data: Resource


func _ready() -> void:
	_load_save()


func _load_save() -> void:
	if ResourceLoader.exists(SAVE_PATH):
		save_data = load(SAVE_PATH)
	else:
		save_data = SkillSaveData.new()
		_save()


func _save() -> void:
	ResourceSaver.save(save_data, SAVE_PATH)


func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	save_data.total_xp += amount
	xp_changed.emit(save_data.total_xp)
	_save()


func upgrade_skill(skill_name: String) -> bool:
	skill_name = skill_name.to_lower()
	if skill_name not in SKILL_NAMES:
		return false
	if not save_data.skill_unlocked.get(skill_name, false):
		return false
	var current_level: int = save_data.skill_levels.get(skill_name, 0)
	if current_level >= MAX_SKILL_LEVEL:
		return false
	var cost: int = _get_upgrade_cost(skill_name, current_level)
	if save_data.total_xp < cost:
		return false
	save_data.total_xp -= cost
	save_data.skill_levels[skill_name] = current_level + 1
	xp_changed.emit(save_data.total_xp)
	skill_upgraded.emit(skill_name, current_level + 1)
	_save()
	return true


func unlock_skill_tree(skill_name: String) -> bool:
	skill_name = skill_name.to_lower()
	if skill_name not in SKILL_NAMES:
		return false
	if save_data.skill_unlocked.get(skill_name, false):
		return false
	if not REQUIRES_STIMULATOR.get(skill_name, true):
		return false
	if save_data.neural_stimulators <= 0:
		return false
	save_data.neural_stimulators -= 1
	save_data.skill_unlocked[skill_name] = true
	neural_stimulators_changed.emit(save_data.neural_stimulators)
	skill_upgraded.emit(skill_name, save_data.skill_levels.get(skill_name, 0))
	_save()
	return true


func get_skill_level(skill_name: String) -> int:
	skill_name = skill_name.to_lower()
	return save_data.skill_levels.get(skill_name, 0)


func get_next_level_xp_cost(skill_name: String) -> int:
	skill_name = skill_name.to_lower()
	if skill_name not in SKILL_NAMES:
		return -1
	var current_level: int = save_data.skill_levels.get(skill_name, 0)
	if current_level >= MAX_SKILL_LEVEL:
		return -1
	return _get_upgrade_cost(skill_name, current_level)


func is_skill_unlocked(skill_name: String) -> bool:
	skill_name = skill_name.to_lower()
	return save_data.skill_unlocked.get(skill_name, false)


func get_total_xp() -> int:
	return save_data.total_xp


func get_neural_stimulators() -> int:
	return save_data.neural_stimulators


func add_neural_stimulators(amount: int) -> void:
	if amount <= 0:
		return
	save_data.neural_stimulators += amount
	neural_stimulators_changed.emit(save_data.neural_stimulators)
	_save()


func reset_to_defaults() -> void:
	save_data = SkillSaveData.new()
	_save()
	xp_changed.emit(save_data.total_xp)
	neural_stimulators_changed.emit(save_data.neural_stimulators)
	for name in SKILL_NAMES:
		skill_upgraded.emit(name, save_data.skill_levels.get(name, 0))


func _get_upgrade_cost(skill_name: String, current_level: int) -> int:
	var base_cost: int = XP_COST_PER_LEVEL.get(skill_name, 100)
	return base_cost * (current_level + 1)
