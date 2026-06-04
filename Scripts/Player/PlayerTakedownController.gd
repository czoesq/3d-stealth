extends Node3D

@export var interact_range: float = 1.5
@export var facing_angle: float = 180.0
@export var knockout_hold_time: float = 1.0
@export var takedown_anim_time: float = 0.5
@export var drag_hold_time: float = 0.5
@export var drag_follow_distance: float = 2.0

enum TargetType { NONE, TAKEDOWN, DRAG, INTERACTABLE }

var player: CharacterBody3D
var current_target: Node3D = null
var current_target_type: int = TargetType.NONE
var _last_indicator_target: Node3D = null
var hold_progress: float = 0.0
var takedown_active: bool = false
var takedown_cooldown: float = 0.0

var dragging: bool = false
var _dragged_enemy: Node3D = null
var _drag_hold_timer: float = 0.0
var _hold_locked_target: Node3D = null

var _interactable_target: Node3D = null
var _interactable_hold_progress: float = 0.0
var _interactable_hold_active: bool = false

@onready var camera: Camera3D = get_viewport().get_camera_3d()


func _ready() -> void:
	player = get_parent() as CharacterBody3D


func _physics_process(delta: float) -> void:
	if dragging:
		_process_drag(delta)
		return

	if takedown_active:
		return

	takedown_cooldown -= delta

	if _hold_locked_target and hold_progress > 0.0:
		if not is_instance_valid(_hold_locked_target):
			_hold_locked_target = null
			hold_progress = 0.0
			_clear_indicators()
			return
		current_target = _hold_locked_target
		current_target_type = TargetType.TAKEDOWN
		_process_takedown_input(delta)
		return

	if takedown_cooldown > 0.0:
		_clear_indicators()
		return

	var enemy_target := _find_nearest_interactable_enemy()
	var enemy_type := _get_target_type(enemy_target)

	var inter_target: Node3D = null
	if not enemy_target:
		inter_target = _find_nearest_interactable()

	if enemy_target:
		current_target = enemy_target
		current_target_type = enemy_type
		_interactable_target = null
		_interactable_hold_progress = 0.0
		_interactable_hold_active = false
	elif inter_target:
		_clear_enemy_target()
		current_target = inter_target
		current_target_type = TargetType.INTERACTABLE
	else:
		current_target = null
		current_target_type = TargetType.NONE
		_clear_enemy_target()
		_interactable_target = null

	_update_indicator_target()

	if not current_target:
		hold_progress = 0.0
		_drag_hold_timer = 0.0
		return

	if current_target_type == TargetType.TAKEDOWN:
		_process_takedown_input(delta)
	elif current_target_type == TargetType.DRAG:
		_process_drag_input(delta)
	elif current_target_type == TargetType.INTERACTABLE:
		_process_interactable_input(delta)


func _process_takedown_input(delta: float) -> void:
	if hold_progress <= 0.0:
		if not _is_valid_takedown_target(current_target):
			_clear_current_target()
			return
		_hold_locked_target = current_target

	if Input.is_action_just_pressed("lethal_takedown"):
		_perform_lethal_takedown(current_target)
		return

	if Input.is_action_pressed("knockout"):
		hold_progress += delta / _get_knockout_hold_time()
		current_target.update_hold_progress(hold_progress)
		if hold_progress >= 1.0:
			_perform_knockout_takedown(current_target)
	else:
		hold_progress = 0.0
		current_target.update_hold_progress(0.0)
		_hold_locked_target = null


func _process_drag_input(delta: float) -> void:
	if not is_instance_valid(current_target):
		_clear_current_target()
		return

	if Input.is_action_just_pressed("knockout"):
		_drag_hold_timer = 0.0

	if Input.is_action_pressed("knockout"):
		_drag_hold_timer += delta
		current_target.update_hold_progress(minf(_drag_hold_timer / drag_hold_time, 1.0))
		if _drag_hold_timer >= drag_hold_time:
			_start_drag(current_target)
	else:
		_drag_hold_timer = 0.0
		current_target.update_hold_progress(0.0)


func _process_drag(delta: float) -> void:
	if not is_instance_valid(_dragged_enemy):
		_drop_enemy()
		return

	if Input.is_action_just_pressed("knockout"):
		_drop_enemy()
		return

	var player_fwd := -player.global_transform.basis.z
	var desired_pos := player.global_position - player_fwd * drag_follow_distance
	var offset := desired_pos - _dragged_enemy.global_position
	offset.y = 0.0

	var correction := offset * 5.0
	_dragged_enemy.velocity = player.velocity + correction
	_dragged_enemy.velocity.y = 0.0


func _start_drag(enemy: Node3D) -> void:
	dragging = true
	_dragged_enemy = enemy
	_drag_hold_timer = 0.0
	_clear_indicators()
	if enemy.has_method("update_hold_progress"):
		enemy.update_hold_progress(0.0)
	if "dragging" in player:
		player.dragging = true


func _drop_enemy() -> void:
	if "dragging" in player:
		player.dragging = false
	dragging = false
	if is_instance_valid(_dragged_enemy):
		_dragged_enemy.velocity = Vector3.ZERO
	_dragged_enemy = null


func _get_knockout_hold_time() -> float:
	var subdue_level := 0
	if SkillManager:
		subdue_level = SkillManager.get_skill_level("subdue")
	var base := knockout_hold_time
	return maxf(base - subdue_level * 0.2, 0.3)


func _find_nearest_interactable_enemy() -> Node3D:
	var enemies := get_tree().get_nodes_in_group("enemy")
	var nearest: Node3D = null
	var nearest_dist_sq := interact_range * interact_range
	var player_pos := player.global_position
	var player_fwd := -player.global_transform.basis.z

	for node in enemies:
		var enemy := node as Node3D
		if not enemy:
			continue
		if not _is_enemy_eligible(enemy) and not _is_enemy_draggable(enemy):
			continue

		var enemy_pos := enemy.global_position
		var to_enemy := enemy_pos - player_pos
		var dist_sq := to_enemy.length_squared()

		if dist_sq > nearest_dist_sq or dist_sq < 0.01:
			continue

		if _is_enemy_eligible(enemy):
			var to_enemy_n := to_enemy.normalized()
			var angle := rad_to_deg(acos(clampf(player_fwd.dot(to_enemy_n), -1.0, 1.0)))
			if angle > facing_angle:
				continue

		nearest = enemy
		nearest_dist_sq = dist_sq

	return nearest


func _get_target_type(enemy: Node3D) -> int:
	if not enemy:
		return TargetType.NONE
	if _is_enemy_eligible(enemy):
		return TargetType.TAKEDOWN
	if _is_enemy_draggable(enemy):
		return TargetType.DRAG
	return TargetType.NONE


func _is_enemy_eligible(enemy: Node3D) -> bool:
	return enemy.has_method("is_eligible_for_takedown") and enemy.is_eligible_for_takedown()


func _is_enemy_draggable(enemy: Node3D) -> bool:
	return enemy.has_method("is_draggable") and enemy.is_draggable()


func _is_valid_takedown_target(target: Node3D) -> bool:
	if not is_instance_valid(target):
		return false
	var dist := player.global_position.distance_to(target.global_position)
	if dist > interact_range:
		return false
	if not target.has_method("is_eligible_for_takedown") or not target.is_eligible_for_takedown():
		return false
	var player_fwd := -player.global_transform.basis.z
	var to_enemy := (target.global_position - player.global_position).normalized()
	var angle := rad_to_deg(acos(clampf(player_fwd.dot(to_enemy), -1.0, 1.0)))
	return angle <= facing_angle


func _update_indicator_target() -> void:
	if _last_indicator_target and _last_indicator_target != current_target:
		if is_instance_valid(_last_indicator_target):
			if _last_indicator_target.has_method("show_takedown_indicators"):
				_last_indicator_target.show_takedown_indicators(false)
				_last_indicator_target.update_hold_progress(0.0)
			if _last_indicator_target.has_method("show_prompt"):
				_last_indicator_target.show_prompt(false)

	if current_target and current_target != _last_indicator_target:
		if current_target.has_method("show_takedown_indicators"):
			current_target.show_takedown_indicators(true)
			if current_target.has_method("set_indicator_mode"):
				var mode := "takedown" if current_target_type == TargetType.TAKEDOWN else "drag"
				current_target.set_indicator_mode(mode)
		if current_target.has_method("show_prompt"):
			current_target.show_prompt(true)

	_last_indicator_target = current_target


func _clear_indicators() -> void:
	if _last_indicator_target and is_instance_valid(_last_indicator_target):
		if _last_indicator_target.has_method("show_takedown_indicators"):
			_last_indicator_target.show_takedown_indicators(false)
			_last_indicator_target.update_hold_progress(0.0)
		if _last_indicator_target.has_method("show_prompt"):
			_last_indicator_target.show_prompt(false)
	_last_indicator_target = null
	current_target = null
	_hold_locked_target = null
	hold_progress = 0.0
	_interactable_hold_progress = 0.0
	_interactable_hold_active = false


func _clear_current_target() -> void:
	current_target = null
	_hold_locked_target = null
	hold_progress = 0.0
	_interactable_hold_progress = 0.0
	_interactable_hold_active = false
	if _last_indicator_target:
		if _last_indicator_target.has_method("update_hold_progress"):
			_last_indicator_target.update_hold_progress(0.0)


func _clear_enemy_target() -> void:
	current_target = null
	_hold_locked_target = null
	hold_progress = 0.0
	_drag_hold_timer = 0.0


func _find_nearest_interactable() -> Node3D:
	var nodes := get_tree().get_nodes_in_group("interactable")
	var nearest: Node3D = null
	var nearest_dist_sq := INF
	var player_pos := player.global_position
	var player_fwd := -player.global_transform.basis.z

	for node in nodes:
		var obj := node as Node3D
		if not obj or not is_instance_valid(obj):
			continue
		if obj.has_method("get_q_label") and obj.has_method("on_e_interact"):
			pass
		else:
			continue

		var range_val: float = obj.interaction_range if "interaction_range" in obj else 2.5
		var range_sq: float = range_val * range_val

		var to_obj := obj.global_position - player_pos
		var dist_sq := to_obj.length_squared()

		if dist_sq > range_sq:
			continue

		if dist_sq < nearest_dist_sq:
			var to_obj_n := to_obj.normalized()
			var angle := rad_to_deg(acos(clampf(player_fwd.dot(to_obj_n), -1.0, 1.0)))
			if angle > facing_angle:
				continue
			nearest = obj
			nearest_dist_sq = dist_sq

	return nearest


func _process_interactable_input(delta: float) -> void:
	if not is_instance_valid(current_target):
		_clear_current_target()
		return

	var target := current_target
	if not target.has_method("on_e_interact"):
		_clear_current_target()
		return

	if Input.is_action_just_pressed("knockout"):
		target.on_e_interact(player)
		return

	if Input.is_action_just_pressed("lethal_takedown"):
		_interactable_hold_active = true
		_interactable_hold_progress = 0.0
		if target.has_method("on_q_start"):
			target.on_q_start(player)

	if _interactable_hold_active:
		if Input.is_action_pressed("lethal_takedown"):
			var hold_time := 1.0
			if target.has_method("get_q_hold_time"):
				hold_time = target.get_q_hold_time()
			_interactable_hold_progress += delta / hold_time
			if target.has_method("update_hold_progress"):
				target.update_hold_progress(_interactable_hold_progress)
			if target.has_method("on_q_hold"):
				target.on_q_hold(delta, player)
			if _interactable_hold_progress >= 1.0:
				if target.has_method("update_hold_progress"):
					target.update_hold_progress(0.0)
				if target.has_method("on_q_complete"):
					target.on_q_complete(player)
				_interactable_hold_active = false
				_interactable_hold_progress = 0.0
		else:
			if _interactable_hold_active and target.has_method("update_hold_progress"):
				target.update_hold_progress(0.0)
			if _interactable_hold_active and target.has_method("on_q_cancel"):
				target.on_q_cancel()
			_interactable_hold_active = false
			_interactable_hold_progress = 0.0


func _perform_lethal_takedown(target: Node3D) -> void:
	if not _is_valid_takedown_target(target):
		return
	takedown_active = true
	_hold_locked_target = null

	if is_instance_valid(target) and target.has_method("flash_indicators"):
		target.flash_indicators("lethal")

	var enemy_pos := target.global_position
	var dir_to_player := (player.global_position - enemy_pos).normalized()
	var behind_offset := dir_to_player * 0.8
	player.global_position = enemy_pos + behind_offset
	player.global_position.y = enemy_pos.y

	var look_target := -dir_to_player
	if look_target.length_squared() > 0.0:
		player.transform.basis = Basis.looking_at(look_target, Vector3.UP)

	if player.has_method("set_takedown_active"):
		player.set_takedown_active(true)
	player.velocity = Vector3.ZERO

	await get_tree().create_timer(takedown_anim_time).timeout

	if is_instance_valid(target) and target.has_method("kill"):
		target.kill()

	_clear_indicators()

	if player.has_method("set_takedown_active"):
		player.set_takedown_active(false)

	takedown_active = false
	takedown_cooldown = 0.3

func _perform_knockout_takedown(target: Node3D) -> void:
	takedown_active = true
	_hold_locked_target = null

	if is_instance_valid(target) and target.has_method("flash_indicators"):
		target.flash_indicators("knockout")

	var enemy_pos := target.global_position
	var dir_to_player := (player.global_position - enemy_pos).normalized()
	var behind_offset := dir_to_player * 0.8
	player.global_position = enemy_pos + behind_offset
	player.global_position.y = enemy_pos.y

	var look_target := -dir_to_player
	if look_target.length_squared() > 0.0:
		player.transform.basis = Basis.looking_at(look_target, Vector3.UP)

	if player.has_method("set_takedown_active"):
		player.set_takedown_active(true)
	player.velocity = Vector3.ZERO

	await get_tree().create_timer(takedown_anim_time).timeout

	if is_instance_valid(target) and target.has_method("knock_out"):
		target.knock_out()

	_clear_indicators()

	if player.has_method("set_takedown_active"):
		player.set_takedown_active(false)

	takedown_active = false
	takedown_cooldown = 0.3
