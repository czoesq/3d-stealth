extends CharacterBody3D

## Fixed-angle isometric stealth player controller.
##
## Node requirements:
##   - CharacterBody3D (this script)
##   - CollisionShape3D child (CapsuleShape3D recommended)
##
## Camera: orthographic Camera3D, ~45° Y-rotation, ~45° X-tilt, no follow rotation.
##
## Input map actions needed:
##   move_left, move_right, move_forward, move_back, jump, crouch_toggle, sprint

@export_group("Movement")
@export var walk_speed: float = 6.0
@export var sprint_speed: float = 10.0
@export var crouch_speed: float = 2.0
@export var acceleration: float = 15.0
@export var air_control: float = 3.0
@export var friction: float = 20.0
@export var rotation_speed: float = 12.0

@export_group("Crouch")
@export var crouch_collision_height: float = 0.6
@export var crouch_transition_speed: float = 8.0
var normal_collision_height: float = 1.8

@export_group("Sprint Noise")
@export var sprint_noise_rate: float = 1.0
@export var max_noise: float = 100.0
@export var noise_decay_rate: float = 5.0
var current_noise: float = 0.0

@export_group("Stealth")
@export var max_stealth: float = 100.0
@export var stealth_recovery_rate: float = 8.0
var current_stealth: float = 100.0

@export_group("Jump")
@export var jump_velocity: float = 4.5

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var crouching: bool = false
var sprinting: bool = false
var was_on_floor: bool = true
var player_visible: bool = true
var invisible_to_ai: bool = false

var takedown_active: bool = false
var collision_shape: CollisionShape3D
@onready var camera: Camera3D = get_viewport().get_camera_3d()


signal stealth_changed(value: float)
signal noise_generated(amount: float, world_position: Vector3)
signal movement_state_changed(state: String)
signal detected
signal player_visibility_changed(visible: bool)


func _ready() -> void:
	add_to_group("player")
	collision_shape = $CollisionShape3D
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		normal_collision_height = collision_shape.shape.height

	current_stealth = max_stealth
	stealth_changed.emit(current_stealth)

	_setup_takedown_controller()


func _setup_takedown_controller() -> void:
	var TakedownCtrl := preload("res://Scripts/Player/PlayerTakedownController.gd")
	var ctrl := TakedownCtrl.new()
	ctrl.name = "PlayerTakedownController"
	add_child(ctrl)


func _physics_process(delta: float) -> void:
	if takedown_active:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	_handle_state_toggles()
	_handle_gravity(delta)
	_handle_jump()

	var move_dir := _get_input_direction()
	var speed := _get_speed()
	_apply_movement(move_dir, speed, delta)

	move_and_slide()
	_rotate_to_movement(move_dir, delta)

	_update_crouch_collision(delta)
	_update_stealth(delta)
	_update_noise(delta)
	was_on_floor = is_on_floor()


func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta


func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor() and not crouching:
		velocity.y = jump_velocity


func _handle_state_toggles() -> void:
	if Input.is_action_just_pressed("crouch_toggle"):
		crouching = not crouching
		movement_state_changed.emit("crouch" if crouching else "walk")

	if Input.is_action_just_pressed("toggle_invisibility"):
		invisible_to_ai = not invisible_to_ai

	if Input.is_action_just_pressed("skill_debug_toggle"):
		_toggle_skill_debug()

	var moving := _get_input_direction().length_squared() > 0.01
	sprinting = Input.is_action_pressed("sprint") and not crouching and moving


func _get_input_direction() -> Vector2:
	var raw := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var len_sq := raw.length_squared()
	if len_sq < 0.01:
		return Vector2.ZERO
	return raw if len_sq <= 1.0 else raw.normalized()


func _get_speed() -> float:
	if crouching:
		return crouch_speed
	if sprinting:
		return sprint_speed
	return walk_speed


func _apply_movement(move_dir: Vector2, speed: float, delta: float) -> void:
	var forward := -camera.global_transform.basis.z
	var right := camera.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var target := Vector3.ZERO
	if move_dir.length_squared() > 0.0:
		target = (right * move_dir.x + forward * -move_dir.y).normalized() * speed
		if not is_on_floor():
			target.y = velocity.y

	var accel := acceleration if is_on_floor() else air_control
	if move_dir.length_squared() > 0.0:
		velocity.x = move_toward(velocity.x, target.x, accel * delta)
		velocity.z = move_toward(velocity.z, target.z, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)


func _rotate_to_movement(move_dir: Vector2, delta: float) -> void:
	if move_dir.length_squared() == 0.0:
		return
	var fwd := -camera.global_transform.basis.z
	var rgt := camera.global_transform.basis.x
	fwd.y = 0.0
	rgt.y = 0.0
	var world_dir := (rgt * move_dir.x + fwd * -move_dir.y).normalized()
	if world_dir.length_squared() > 0.0:
		var target_basis := Basis.looking_at(-world_dir, Vector3.UP)
		transform.basis = transform.basis.slerp(target_basis, rotation_speed * delta)


func _update_crouch_collision(delta: float) -> void:
	if not collision_shape or not collision_shape.shape is CapsuleShape3D:
		return
	var capsule := collision_shape.shape as CapsuleShape3D
	var target_height := crouch_collision_height if crouching else normal_collision_height
	capsule.height = move_toward(capsule.height, target_height, crouch_transition_speed * delta)


func _update_stealth(delta: float) -> void:
	## Recovery when not actively detected.
	## Hook: Check detection system status here —
	## e.g.  if not detection_system.is_player_detected():
	current_stealth = minf(current_stealth + stealth_recovery_rate * delta, max_stealth)
	stealth_changed.emit(current_stealth)


func _update_noise(delta: float) -> void:
	if sprinting and is_on_floor() and _get_input_direction().length_squared() > 0.0:
		current_noise = minf(current_noise + sprint_noise_rate * delta * 60.0, max_noise)
		noise_generated.emit(current_noise, global_position)
	else:
		current_noise = maxf(current_noise - noise_decay_rate * delta * 60.0, 0.0)


# ── Detection system hooks ──────────────────────────────────────────

## Call when an enemy spots the player.
func on_detected() -> void:
	detected.emit()
	current_stealth = 0.0
	stealth_changed.emit(current_stealth)


## Set player visibility (e.g. when entering/exiting shadow).
func set_visibility(visible_state: bool) -> void:
	player_visible = visible_state
	player_visibility_changed.emit(visible_state)


## Noise value (0–100) for enemy sound detection queries.
func get_noise_level() -> float:
	return current_noise


## Emit a one-shot noise event (e.g. opening a door, dropping an item).
func emit_noise(amount: float) -> void:
	var clamped := clampf(amount, 0.0, max_noise)
	current_noise = minf(current_noise + clamped, max_noise)
	noise_generated.emit(clamped, global_position)


## Visibility factor between 0 (invisible) and 1 (fully visible).
## Hook: Replace with actual light/shadow and line-of-sight calculation.
func get_visibility_factor() -> float:
	return 0.0 if not player_visible else 1.0

func _toggle_skill_debug() -> void:
	var existing := get_tree().current_scene.find_child("SkillDebugUI", false, false)
	if existing:
		existing.queue_free()
		return
	var SkillDebugUI := preload("res://Scripts/UI/SkillDebugUI.gd")
	var ui := SkillDebugUI.new()
	ui.name = "SkillDebugUI"
	get_tree().current_scene.add_child(ui)


func is_invisible_to_ai() -> bool:
	return invisible_to_ai

func is_crouching() -> bool:
	return crouching

func set_takedown_active(active: bool) -> void:
	takedown_active = active
