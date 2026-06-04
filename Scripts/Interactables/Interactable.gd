extends Node3D
class_name Interactable

@export var interaction_range: float = 2.5

func get_e_label() -> String:
	return ""

func get_q_label() -> String:
	return ""

func get_q_hold_time() -> float:
	return 1.0

func on_e_interact(_player: Node3D) -> void:
	pass

func on_q_start(_player: Node3D) -> void:
	pass

func on_q_hold(_delta: float, _player: Node3D) -> float:
	return 0.0

func on_q_complete(_player: Node3D) -> void:
	pass

func show_prompt(visible: bool) -> void:
	pass
