extends Node

signal money_changed(new_amount: int)
signal story_flag_set(key: String, value)

var money: int = 0
var story_flags: Dictionary = {}


func add_money(amount: int) -> void:
	if amount == 0:
		return
	money += amount
	money_changed.emit(money)


func spend_money(amount: int) -> bool:
	if amount > money:
		return false
	money -= amount
	money_changed.emit(money)
	return true


func set_story_flag(key: String, value) -> void:
	story_flags[key] = value
	story_flag_set.emit(key, value)


func get_story_flag(key: String, default = null):
	return story_flags.get(key, default)


func has_story_flag(key: String) -> bool:
	return key in story_flags
