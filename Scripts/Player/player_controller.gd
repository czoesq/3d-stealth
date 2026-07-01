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

@export_group("Stamina")
@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 20.0
@export var stamina_recharge_rate: float = 25.0

@export_group("Health")
@export var max_health: float = 100.0

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
@export var crouch_jump_velocity: float = 3.0

@export_group("Ladder")
@export var climb_speed: float = 4.0

@export_group("Respawn")
@export var respawn_height: float = -10.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var crouching: bool = false
var sprinting: bool = false
var was_on_floor: bool = true
var player_visible: bool = true
var invisible_to_ai: bool = false

var takedown_active: bool = false
var dragging: bool = false
var on_ladder: bool = false
var _ladder_nearby: bool = false
var _current_ladder: Node3D = null
var _ladder_height: float = 3.0
var _ladder_width: float = 1.0
var _ladder_grace_timer: float = 0.0
var _ladder_attach_side: float = 1.0
var _player_half_height: float = 0.9
var collision_shape: CollisionShape3D
var _outline_mesh: MeshInstance3D
var _occlusion_timer: float = 0.0
var _ladder_detector: Area3D

var inventory: Array[String] = []
var stamina: float = 100.0
var health: float = 100.0
var _spawn_position: Vector3

# ── Item slot system ─────────────────────────────────────────────────
const ITEM_DB = {
	"Tranquilizer Gun": {"slot": "weapon", "icon": null},
	"EMP Grenade": {"slot": "weapon", "icon": null},
	"Smoke Grenade": {"slot": "weapon", "icon": null},
	"Explosive Grenade": {"slot": "weapon", "icon": null},
	"Trip Mine": {"slot": "weapon", "icon": null},
	"Health Kit": {"slot": "consumable", "icon": null},
	"Sword": {"slot": "weapon", "icon": null},
}

var _weapon_items: Array[String] = []
var _consumable_items: Array[String] = []
var _weapon_index: int = -1
var _consumable_index: int = -1

var _held_item: Node3D
var _held_item_tween: Tween
var _bob_time: float = 0.0
var _was_moving: bool = false
var _sword_hitbox: Area3D
var _sword_attacking: bool = false
var _grenade_charging: bool = false
var _grenade_charge: float = 0.0
var _grenade_cooldown: float = 0.0
const GRENADE_CHARGE_TIME: float = 3.0
const GRENADE_COOLDOWN_TIME: float = 2.0

var _grenade_model: Node3D
var _aim_indicator: Node3D
var _aim_target_marker: MeshInstance3D

const GRENADE_VH_FACTOR: float = 1.0 / 1.118
const GRENADE_VV_FACTOR: float = 0.5 / 1.118 + 0.25

var _tranq_model: Node3D
var _tranq_cooldown: float = 0.0
const TRANQ_COOLDOWN_TIME: float = 0.8
const TRANQ_PROJECTILE_SPEED: float = 35.0
const GRENADE_INITIAL_HEIGHT: float = 0.8
const GRENADE_MIN_SPEED: float = 5.0
const GRENADE_MAX_SPEED: float = 17.0

@onready var camera: Camera3D = get_viewport().get_camera_3d()


signal stealth_changed(value: float)
signal noise_generated(amount: float, world_position: Vector3)
signal movement_state_changed(state: String)
signal detected
signal player_visibility_changed(visible: bool)
signal stamina_changed(current: float, max_val: float)
signal stamina_depleted
signal health_changed(current: float, max_val: float)
signal item_collected(item_name: String)
signal weapon_changed(item_name: String)
signal consumable_changed(item_name: String)
signal weapon_activated(item_name: String)
signal consumable_activated(item_name: String)


func _ready() -> void:
	add_to_group("player")
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(60)
	max_slides = 16
	collision_shape = $CollisionShape3D
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		normal_collision_height = collision_shape.shape.height

	current_stealth = max_stealth
	stealth_changed.emit(current_stealth)
	stamina = max_stamina
	stamina_changed.emit(stamina, max_stamina)
	health = max_health
	health_changed.emit(health, max_health)

	_setup_takedown_controller()
	_setup_ladder_detector()
	_setup_outline()
	_setup_hud()
	_setup_held_item()
	_setup_grenade_model()
	_setup_tranq_model()
	_setup_aim_indicator()
	weapon_changed.connect(_on_weapon_changed_for_held_item)
	weapon_activated.connect(_on_weapon_activated)

	_spawn_position = global_position


func _setup_takedown_controller() -> void:
	var TakedownCtrl := preload("res://Scripts/Player/PlayerTakedownController.gd")
	var ctrl := TakedownCtrl.new()
	ctrl.name = "PlayerTakedownController"
	add_child(ctrl)


func _setup_ladder_detector() -> void:
	_ladder_detector = Area3D.new()
	_ladder_detector.name = "LadderDetector"
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, 1.8, 0.6)
	shape_node.shape = box
	shape_node.position = Vector3(0, 0.9, 0.3)
	_ladder_detector.add_child(shape_node)
	_ladder_detector.collision_layer = 0
	_ladder_detector.collision_mask = 2
	add_child(_ladder_detector)
	_ladder_detector.body_entered.connect(_on_ladder_body_entered)
	_ladder_detector.body_exited.connect(_on_ladder_body_exited)


func _on_ladder_body_entered(body: Node3D) -> void:
	if body.is_in_group("ladder"):
		_ladder_nearby = true
		_current_ladder = body


func _on_ladder_body_exited(body: Node3D) -> void:
	if body.is_in_group("ladder"):
		_ladder_nearby = false
		if not on_ladder:
			_current_ladder = null


func _attach_to_ladder(ladder_node: Node3D) -> void:
	on_ladder = true
	_current_ladder = ladder_node
	_ladder_grace_timer = 0.4
	_ladder_height = 3.0
	_ladder_width = 1.0
	if ladder_node.has_method("get_ladder_height"):
		_ladder_height = ladder_node.get_ladder_height()
	if ladder_node.has_method("get_ladder_width"):
		_ladder_width = ladder_node.get_ladder_width()
	velocity = Vector3.ZERO

	var lp := ladder_node.global_position
	var ladder_basis := ladder_node.global_transform.basis.orthonormalized()

	var to_player := global_position - lp
	to_player.y = 0.0
	var local_to_player := ladder_basis.inverse() * to_player
	_ladder_attach_side = signf(local_to_player.z)
	if _ladder_attach_side == 0.0:
		_ladder_attach_side = 1.0

	var climb_dist := 0.5
	var climb_offset := ladder_basis * Vector3(0, 0, _ladder_attach_side * climb_dist)

	if ladder_node.has_method("get_world_top_y"):
		var top_y: float = ladder_node.get_world_top_y()
		if global_position.y - _player_half_height >= top_y:
			global_position = Vector3(lp.x + climb_offset.x, top_y - 0.3 + _player_half_height, lp.z + climb_offset.z)
			var ladder_dir := lp - global_position
			ladder_dir.y = 0.0
			if ladder_dir.length_squared() > 0.0:
				transform.basis = Basis.looking_at(ladder_dir.normalized(), Vector3.UP)
			return

	global_position = Vector3(lp.x + climb_offset.x, global_position.y + 0.15, lp.z + climb_offset.z)

	var ladder_dir := lp - global_position
	ladder_dir.y = 0.0
	if ladder_dir.length_squared() > 0.0:
		transform.basis = Basis.looking_at(ladder_dir.normalized(), Vector3.UP)


func _detach_from_ladder() -> void:
	if _current_ladder:
		var ladder = _current_ladder
		_current_ladder = null
		ladder._detach_player()
		return
	on_ladder = false
	_ladder_height = 3.0
	_ladder_width = 1.0
	_ladder_grace_timer = 0.0
	if Vector2(velocity.x, velocity.z).length_squared() < 0.01:
		var fwd := -global_transform.basis.z
		fwd.y = 0.0
		if fwd.length_squared() > 0.0:
			velocity = fwd.normalized() * walk_speed * 0.5
	velocity.y = 0.0


func _setup_hud() -> void:
	var HUD := preload("res://Scripts/UI/PlayerHUD.gd")
	var hud := HUD.new()
	hud.name = "PlayerHUD"
	add_child(hud)


func _setup_held_item() -> void:
	_held_item = Node3D.new()
	_held_item.name = "HeldItem"
	add_child(_held_item)

	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.08, 0.875, 0.01)
	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.7, 0.7, 0.75)
	blade_mat.metallic = 0.8
	blade_mat.roughness = 0.2
	blade_mesh.surface_set_material(0, blade_mat)
	var blade := MeshInstance3D.new()
	blade.name = "Blade"
	blade.mesh = blade_mesh
	blade.position = Vector3(0, 0.2, 0)
	_held_item.add_child(blade)

	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.03, 0.08, 0.03)
	var handle_mat := StandardMaterial3D.new()
	handle_mat.albedo_color = Color(0.35, 0.2, 0.1)
	handle_mesh.surface_set_material(0, handle_mat)
	var handle := MeshInstance3D.new()
	handle.name = "Handle"
	handle.mesh = handle_mesh
	handle.position = Vector3(0, -0.05, 0)
	_held_item.add_child(handle)

	var guard_mesh := BoxMesh.new()
	guard_mesh.size = Vector3(0.08, 0.02, 0.03)
	var guard_mat := StandardMaterial3D.new()
	guard_mat.albedo_color = Color(0.5, 0.35, 0.15)
	guard_mesh.surface_set_material(0, guard_mat)
	var guard := MeshInstance3D.new()
	guard.name = "Guard"
	guard.mesh = guard_mesh
	guard.position = Vector3(0, 0.02, 0)
	_held_item.add_child(guard)

	_sword_hitbox = Area3D.new()
	_sword_hitbox.name = "SwordHitbox"
	var hit_shape := CollisionShape3D.new()
	hit_shape.shape = BoxShape3D.new()
	hit_shape.shape.size = Vector3(0.25, 0.5, 0.25)
	hit_shape.position = Vector3(0, 0.3, 0)
	_sword_hitbox.add_child(hit_shape)
	_sword_hitbox.collision_mask = 1
	_sword_hitbox.monitoring = false
	_sword_hitbox.body_entered.connect(_on_sword_hit)
	_held_item.add_child(_sword_hitbox)

	_held_item.position = Vector3(0.7, 0.65, 0.15)
	_held_item.rotation = Vector3(0.3, -0.4, -0.5)
	_held_item.visible = false


func _on_weapon_changed_for_held_item(item_name: String) -> void:
	var is_sword := item_name == "Sword"
	var is_grenade := "Grenade" in item_name
	var is_tranq := item_name == "Tranquilizer Gun"
	if _held_item:
		_held_item.visible = is_sword
	if _grenade_model:
		_grenade_model.visible = is_grenade
	if _tranq_model:
		_tranq_model.visible = is_tranq
	if _aim_indicator:
		_aim_indicator.visible = is_grenade or is_tranq


func _on_sword_hit(body: Node3D) -> void:
	if not _sword_attacking:
		return
	if body.has_method("kill"):
		body.kill()


func _on_weapon_activated(item_name: String) -> void:
	match item_name:
		"Sword":
			_sword_attack()
		"Tranquilizer Gun":
			_fire_tranq()


func _sword_attack() -> void:
	if _held_item_tween and _held_item_tween.is_valid():
		_held_item_tween.kill()
	_sword_attacking = true
	_sword_hitbox.monitoring = true
	_sword_arc_hit_check()
	var start_rot := _held_item.rotation.y
	_held_item_tween = create_tween()
	_held_item_tween.set_trans(Tween.TRANS_QUAD)
	_held_item_tween.tween_property(_held_item, "rotation:y", start_rot + 4.0, 0.2)
	_held_item_tween.tween_property(_held_item, "rotation:y", start_rot, 0.15)
	_held_item_tween.finished.connect(_on_slash_finished, CONNECT_ONE_SHOT)


func _sword_arc_hit_check() -> void:
	for entry in get_tree().get_nodes_in_group("enemy"):
		var enemy := entry as Node3D
		if not enemy or not is_instance_valid(enemy):
			continue
		var offset := enemy.global_position - global_position
		offset.y = 0
		if offset.length() > 2.0:
			continue
		var fwd := -global_transform.basis.z
		fwd.y = 0
		if fwd.dot(offset.normalized()) > 0.3:
			enemy.kill()


func _on_slash_finished() -> void:
	_sword_attacking = false
	_sword_hitbox.monitoring = false


func _handle_tranq_cooldown(delta: float) -> void:
	if _tranq_cooldown > 0.0:
		_tranq_cooldown = maxf(_tranq_cooldown - delta, 0.0)


func _fire_tranq() -> void:
	if _tranq_cooldown > 0.0:
		return
	_tranq_cooldown = TRANQ_COOLDOWN_TIME

	var target := _get_mouse_target()
	var dir := (target - global_position).normalized()
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		dir = -global_transform.basis.z
	else:
		dir = dir.normalized()

	var spawn_pos := global_position + Vector3(0, 0.8, 0) + dir * 1.0

	var Projectile := preload("res://Scripts/Items/TranquilizerProjectile.gd")
	var proj := Projectile.new()
	get_parent().add_child(proj)
	proj.global_position = spawn_pos
	proj.linear_velocity = dir * TRANQ_PROJECTILE_SPEED

	emit_noise(10.0)


func _handle_grenade_charge(delta: float) -> void:
	if _grenade_cooldown > 0.0:
		_grenade_cooldown = maxf(_grenade_cooldown - delta, 0.0)
		return
	var current := get_current_weapon()
	if current != "Explosive Grenade" and current != "Smoke Grenade":
		if _grenade_charging:
			_grenade_charging = false
			_grenade_charge = 0.0
		return
	if Input.is_action_just_pressed("item_slot1_activate") and not _grenade_charging:
		_grenade_charging = true
		_grenade_charge = 0.0
	elif _grenade_charging:
		if Input.is_action_just_released("item_slot1_activate"):
			_throw_grenade()
		elif Input.is_action_pressed("item_slot1_activate"):
			_grenade_charge = minf(_grenade_charge + delta / GRENADE_CHARGE_TIME, 1.0)


func _get_mouse_target() -> Vector3:
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_from := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)
	var t := -ray_from.y / ray_dir.y
	if t <= 0:
		return global_position
	return ray_from + ray_dir * t


func _throw_grenade() -> void:
	if not _grenade_charging:
		return
	_grenade_charging = false
	_grenade_cooldown = GRENADE_COOLDOWN_TIME
	var charge := _grenade_charge
	_grenade_charge = 0.0

	var current := get_current_weapon()
	var grenade: RigidBody3D
	if current == "Smoke Grenade":
		var scene := preload("res://Scripts/Items/SmokeGrenade.gd")
		grenade = scene.new()
	else:
		var scene := preload("res://Scripts/Items/ExplosiveGrenade.gd")
		grenade = scene.new()
		grenade.explosion_radius = 5.0
		grenade.explosion_damage = 60.0
	get_parent().add_child(grenade)

	var target := _get_mouse_target()
	var fwd := (target - global_position)
	fwd.y = 0.0
	if fwd.length_squared() < 0.01:
		fwd = -global_transform.basis.z
	else:
		fwd = fwd.normalized()

	grenade.global_position = global_position + Vector3(0, 0.8, 0) + fwd * 0.5

	var speed: float
	if current == "Smoke Grenade":
		speed = charge * 12.0
	else:
		speed = 5.0 + charge * 12.0
	var launch_dir := (fwd * Vector3(1, 0.3, 1) + Vector3(0, 0.5, 0)).normalized()
	grenade.linear_velocity = launch_dir * speed + Vector3(0, speed * 0.25, 0)


func _bob_held_item(delta: float, moving: bool) -> void:
	if not _held_item:
		return
	if moving:
		_bob_time += delta * 8.0
		var bob_y := sin(_bob_time) * 0.04
		var bob_z := cos(_bob_time * 0.7) * 0.02
		_held_item.position.y = 0.65 + bob_y
		_held_item.position.z = 0.15 + bob_z
		if _grenade_model and _grenade_model.visible:
			_grenade_model.position.y = 0.4 + bob_y * 0.5
			_grenade_model.rotation.z = -0.1 + sin(_bob_time * 0.5) * 0.02
	else:
		_bob_time = 0.0
		_held_item.position.y = 0.65
		_held_item.position.z = 0.15
		if _grenade_model and _grenade_model.visible:
			_grenade_model.position.y = 0.4
			_grenade_model.rotation.z = -0.1


func _setup_grenade_model() -> void:
	_grenade_model = Node3D.new()
	_grenade_model.name = "GrenadeModel"
	add_child(_grenade_model)

	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.07
	body_mesh.height = 0.14
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.25, 0.55, 0.2)
	body_mat.metallic = 0.3
	body_mat.roughness = 0.6
	body_mesh.surface_set_material(0, body_mat)
	var body := MeshInstance3D.new()
	body.mesh = body_mesh
	_grenade_model.add_child(body)

	var fuse_mesh := CylinderMesh.new()
	fuse_mesh.top_radius = 0.025
	fuse_mesh.bottom_radius = 0.035
	fuse_mesh.height = 0.02
	var fuse_mat := StandardMaterial3D.new()
	fuse_mat.albedo_color = Color(0.4, 0.4, 0.4)
	fuse_mat.metallic = 0.5
	fuse_mat.roughness = 0.3
	fuse_mesh.surface_set_material(0, fuse_mat)
	var fuse := MeshInstance3D.new()
	fuse.mesh = fuse_mesh
	fuse.position = Vector3(0, 0.07, 0)
	_grenade_model.add_child(fuse)

	_grenade_model.position = Vector3(-0.45, 0.4, 0.15)
	_grenade_model.rotation = Vector3(0.1, 0.3, -0.1)
	_grenade_model.visible = false


func _setup_tranq_model() -> void:
	_tranq_model = Node3D.new()
	_tranq_model.name = "TranqModel"
	add_child(_tranq_model)

	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.02
	barrel_mesh.bottom_radius = 0.03
	barrel_mesh.height = 0.35
	var barrel_mat := StandardMaterial3D.new()
	barrel_mat.albedo_color = Color(0.25, 0.25, 0.28)
	barrel_mat.metallic = 0.6
	barrel_mat.roughness = 0.3
	barrel_mesh.surface_set_material(0, barrel_mat)
	var barrel := MeshInstance3D.new()
	barrel.mesh = barrel_mesh
	barrel.position = Vector3(0, 0, -0.18)
	barrel.rotation.x = PI / 2
	_tranq_model.add_child(barrel)

	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.04, 0.06, 0.15)
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.2, 0.2, 0.22)
	body_mat.metallic = 0.5
	body_mat.roughness = 0.4
	body_mesh.surface_set_material(0, body_mat)
	var body := MeshInstance3D.new()
	body.mesh = body_mesh
	body.position = Vector3(0, 0, 0.03)
	_tranq_model.add_child(body)

	var grip_mesh := BoxMesh.new()
	grip_mesh.size = Vector3(0.03, 0.08, 0.04)
	var grip_mat := StandardMaterial3D.new()
	grip_mat.albedo_color = Color(0.15, 0.12, 0.08)
	grip_mat.metallic = 0.2
	grip_mat.roughness = 0.7
	grip_mesh.surface_set_material(0, grip_mat)
	var grip := MeshInstance3D.new()
	grip.mesh = grip_mesh
	grip.position = Vector3(0, -0.07, 0.05)
	_tranq_model.add_child(grip)

	_tranq_model.position = Vector3(0.65, 0.55, 0.1)
	_tranq_model.rotation = Vector3(-0.1, -0.3, -0.6)
	_tranq_model.visible = false


func _setup_aim_indicator() -> void:
	_aim_indicator = Node3D.new()
	_aim_indicator.name = "AimIndicator"
	add_child(_aim_indicator)

	var dot_mesh := CylinderMesh.new()
	dot_mesh.top_radius = 0.15
	dot_mesh.bottom_radius = 0.15
	dot_mesh.height = 0.02
	var dot_mat := StandardMaterial3D.new()
	dot_mat.albedo_color = Color(1.0, 0.3, 0.1, 0.8)
	dot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dot_mesh.surface_set_material(0, dot_mat)
	_aim_target_marker = MeshInstance3D.new()
	_aim_target_marker.mesh = dot_mesh
	_aim_indicator.add_child(_aim_target_marker)

	var inner_dot_mesh := CylinderMesh.new()
	inner_dot_mesh.top_radius = 0.06
	inner_dot_mesh.bottom_radius = 0.06
	inner_dot_mesh.height = 0.03
	var inner_dot_mat := StandardMaterial3D.new()
	inner_dot_mat.albedo_color = Color(1.0, 0.3, 0.1, 0.5)
	inner_dot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	inner_dot_mesh.surface_set_material(0, inner_dot_mat)
	var inner_dot := MeshInstance3D.new()
	inner_dot.mesh = inner_dot_mesh
	_aim_target_marker.add_child(inner_dot)

	_aim_indicator.visible = false


func _update_aim_indicator() -> void:
	if not _aim_indicator or not _aim_indicator.visible:
		return

	var target := _get_mouse_target()
	var current := get_current_weapon()

	if current == "Tranquilizer Gun":
		_aim_target_marker.global_position = Vector3(target.x, 0.02, target.z)
		return

	var dir_3d := target - global_position
	dir_3d.y = 0.0
	var dir: Vector3
	if dir_3d.length_squared() < 0.01:
		dir = -global_transform.basis.z
	else:
		dir = dir_3d.normalized()

	var throw_dist := _estimate_grenade_range(_grenade_charge)
	var marker_pos := global_position + dir * throw_dist
	_aim_target_marker.global_position = Vector3(marker_pos.x, 0.02, marker_pos.z)


func _estimate_grenade_range(charge: float) -> float:
	var current := get_current_weapon()
	var min_speed: float = 0.0 if current == "Smoke Grenade" else GRENADE_MIN_SPEED
	var max_speed: float = 12.0 if current == "Smoke Grenade" else GRENADE_MAX_SPEED
	var speed: float = min_speed + charge * (max_speed - min_speed)
	var vh: float = speed * GRENADE_VH_FACTOR
	var vv: float = speed * GRENADE_VV_FACTOR
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var t: float = (vv + sqrt(vv * vv + 2.0 * g * GRENADE_INITIAL_HEIGHT)) / g
	return 0.5 + vh * t


func _setup_outline() -> void:
	var original_mesh := $MeshInstance3D as MeshInstance3D
	if not original_mesh or not original_mesh.mesh is CapsuleMesh:
		return
	var cap := original_mesh.mesh as CapsuleMesh
	var dup_mesh := CapsuleMesh.new()
	dup_mesh.height = cap.height
	dup_mesh.radius = cap.radius
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://Shaders/player_outline.gdshader")
	_outline_mesh = MeshInstance3D.new()
	_outline_mesh.name = "OutlineMesh"
	_outline_mesh.mesh = dup_mesh
	_outline_mesh.material_override = mat
	add_child(_outline_mesh)


func _update_outline_occlusion() -> void:
	if not _outline_mesh or not camera:
		return

	_occlusion_timer -= get_physics_process_delta_time()
	if _occlusion_timer > 0.0:
		return
	_occlusion_timer = 0.1

	var space := get_world_3d().direct_space_state
	if not space:
		_outline_mesh.visible = false
		return

	var origin := camera.global_position
	var num_samples := 32
	var data: Array[float] = []
	data.resize(num_samples)
	var any_occluded := false

	for i in num_samples:
		var h := -0.9 + 1.8 * float(i) / float(num_samples - 1)
		var p := global_position + Vector3(0, h, 0)
		var dist := origin.distance_to(p)
		var query := PhysicsRayQueryParameters3D.create(origin, p)
		query.exclude = [self]
		var hit := space.intersect_ray(query)
		if hit and origin.distance_to(hit.position) < dist - 0.05:
			data[i] = 1.0
			any_occluded = true
		else:
			data[i] = 0.0

	var mat := _outline_mesh.material_override as ShaderMaterial
	if mat:
		mat.set_shader_parameter("occlusion_data", data)

	_outline_mesh.visible = any_occluded


func _physics_process(delta: float) -> void:
	if global_position.y < respawn_height:
		respawn()
		return

	if takedown_active:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if on_ladder:
		_handle_ladder_movement(delta)
		move_and_slide()
		_rotate_to_movement(_get_input_direction(), delta)
		return

	_handle_state_toggles()
	_handle_item_input()
	_handle_grenade_charge(delta)
	_handle_tranq_cooldown(delta)
	_handle_gravity(delta)
	_handle_jump()

	var move_dir := _get_input_direction()
	var speed := _get_speed()
	_apply_movement(move_dir, speed, delta)

	_step_up(delta)
	move_and_slide()
	_rotate_to_movement(move_dir, delta)

	_update_crouch_collision(delta)
	_update_stamina(delta)
	_update_stealth(delta)
	_update_noise(delta)
	_update_outline_occlusion()
	_update_aim_indicator()
	var moving := is_on_floor() and move_dir.length_squared() > 0.0
	_bob_held_item(delta, moving)
	if _sword_attacking and _sword_hitbox:
		for body in _sword_hitbox.get_overlapping_bodies():
			if body.has_method("kill"):
				body.kill()
	was_on_floor = is_on_floor()


func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta


func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		if crouching:
			crouching = false
			movement_state_changed.emit("walk")
		velocity.y = jump_velocity


func _handle_state_toggles() -> void:
	if Input.is_action_just_pressed("crouch_toggle"):
		crouching = not crouching
		movement_state_changed.emit("crouch" if crouching else "walk")
		if crouching and sprinting:
			sprinting = false
			movement_state_changed.emit("crouch")

	if Input.is_action_just_pressed("toggle_invisibility"):
		invisible_to_ai = not invisible_to_ai

	if Input.is_action_just_pressed("skill_debug_toggle"):
		_toggle_skill_debug()

	if Input.is_action_just_pressed("mission_debug_toggle"):
		_toggle_mission_debug()

	if Input.is_action_just_pressed("sprint"):
		if sprinting:
			sprinting = false
			movement_state_changed.emit("walk" if not crouching else "crouch")
		elif stamina > 0.0:
			crouching = false
			sprinting = true
			movement_state_changed.emit("sprint")


func _get_input_direction() -> Vector2:
	var raw := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var len_sq := raw.length_squared()
	if len_sq < 0.01:
		return Vector2.ZERO
	return raw if len_sq <= 1.0 else raw.normalized()


func _get_speed() -> float:
	if dragging:
		return crouch_speed
	if crouching:
		return crouch_speed
	if sprinting:
		return sprint_speed
	return walk_speed


func _handle_ladder_movement(delta: float) -> void:
	if not _current_ladder:
		_detach_from_ladder()
		return

	_ladder_grace_timer = maxf(_ladder_grace_timer - delta, 0.0)

	var ladder_pos := _current_ladder.global_position
	var ladder_basis := _current_ladder.global_transform.basis.orthonormalized()
	var climb_dist := 0.5
	var climb_offset := ladder_basis * Vector3(0, 0, _ladder_attach_side * climb_dist)

	var from_ladder := Vector2(global_position.x - ladder_pos.x, global_position.z - ladder_pos.z)
	if from_ladder.length_squared() > 4.0:
		velocity = -global_transform.basis.z * walk_speed * 0.5
		_detach_from_ladder()
		return

	var base_y: float = _current_ladder.get_world_base_y()
	var top_y: float = _current_ladder.get_world_top_y()
	var player_bottom_y := global_position.y - _player_half_height
	if player_bottom_y >= top_y:
		_ladder_attach_side = -_ladder_attach_side
		climb_offset = ladder_basis * Vector3(0, 0, _ladder_attach_side * climb_dist)
		global_position = Vector3(ladder_pos.x + climb_offset.x, global_position.y, ladder_pos.z + climb_offset.z)
		var away_dir := global_position - ladder_pos
		away_dir.y = 0.0
		transform.basis = Basis.looking_at(away_dir.normalized(), Vector3.UP)
		velocity = -global_transform.basis.z * walk_speed * 0.5
		_detach_from_ladder()
		return
	if _ladder_grace_timer <= 0.0 and is_on_floor():
		var dist_from_base := player_bottom_y - base_y
		if dist_from_base > 0.5 and abs(velocity.y) < 0.01:
			velocity = -global_transform.basis.z * walk_speed * 0.5
			_detach_from_ladder()
			return

	var move_dir := _get_input_direction()
	var target_y := 0.0
	if move_dir.y < -0.5:
		target_y = climb_speed
	elif move_dir.y > 0.5:
		target_y = -climb_speed
	velocity.y = move_toward(velocity.y, target_y, acceleration * delta)
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)

	global_position.x = ladder_pos.x + climb_offset.x
	global_position.z = ladder_pos.z + climb_offset.z


func _step_up(delta: float) -> void:
	if not is_on_floor():
		return
	var move_dir := _get_input_direction()
	if move_dir.length_squared() == 0.0:
		return

	var max_step := 0.35
	var probe_dist := 0.8
	var fwd := -camera.global_transform.basis.z
	var rgt := camera.global_transform.basis.x
	var dir := (rgt * move_dir.x + fwd * -move_dir.y).normalized()

	var space := get_world_3d().direct_space_state
	var feet_y := global_position.y - _player_half_height

	var from1 := Vector3(global_position.x, feet_y + 0.05, global_position.z)
	var to1 := from1 + dir * probe_dist
	var q1 := PhysicsRayQueryParameters3D.create(from1, to1)
	q1.exclude = [self]
	var hit1 := space.intersect_ray(q1)
	if not hit1:
		return

	var from2 := Vector3(global_position.x, feet_y + max_step + 0.1, global_position.z)
	var to2 := from2 + dir * probe_dist
	var q2 := PhysicsRayQueryParameters3D.create(from2, to2)
	q2.exclude = [self]
	var hit2 := space.intersect_ray(q2)
	if hit2:
		return

	var land_pos: Vector3 = hit1.position + dir * 0.4
	var from3 := Vector3(land_pos.x, hit1.position.y + max_step, land_pos.z)
	var to3 := Vector3(land_pos.x, feet_y - 0.1, land_pos.z)
	var q3 := PhysicsRayQueryParameters3D.create(from3, to3)
	q3.exclude = [self]
	var hit3 := space.intersect_ray(q3)
	if not hit3:
		return

	var surface_normal: Vector3 = hit3.normal
	if surface_normal.angle_to(Vector3.UP) > floor_max_angle:
		return

	var land_y: float = hit3.position.y + 0.05
	global_position.y = land_y + _player_half_height
	velocity.y = 0.0


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
		var target_basis := Basis.looking_at(world_dir, Vector3.UP)
		transform.basis = transform.basis.slerp(target_basis, rotation_speed * delta)


func _update_crouch_collision(delta: float) -> void:
	if not collision_shape or not collision_shape.shape is CapsuleShape3D:
		return
	var capsule := collision_shape.shape as CapsuleShape3D
	var target_height := crouch_collision_height if crouching else normal_collision_height
	capsule.height = move_toward(capsule.height, target_height, crouch_transition_speed * delta)


func _update_stamina(delta: float) -> void:
	if sprinting and _get_input_direction().length_squared() > 0.01:
		stamina = maxf(stamina - stamina_drain_rate * delta, 0.0)
		stamina_changed.emit(stamina, max_stamina)
		if stamina <= 0.0:
			sprinting = false
			movement_state_changed.emit("walk" if not crouching else "crouch")
			stamina_depleted.emit()
	elif stamina < max_stamina:
		stamina = minf(stamina + stamina_recharge_rate * delta, max_stamina)
		stamina_changed.emit(stamina, max_stamina)


func respawn() -> void:
	if _current_ladder:
		_current_ladder._detach_player()
		_current_ladder = null
	on_ladder = false
	takedown_active = false
	dragging = false
	crouching = false
	sprinting = false
	velocity = Vector3.ZERO
	global_position = _spawn_position
	health = max_health
	health_changed.emit(health, max_health)
	stamina = max_stamina
	stamina_changed.emit(stamina, max_stamina)


func take_damage(amount: float) -> void:
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)


func heal(amount: float) -> void:
	health = minf(health + amount, max_health)
	health_changed.emit(health, max_health)


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


func _toggle_mission_debug() -> void:
	var existing := get_tree().current_scene.find_child("MissionDebugUI", false, false)
	if existing:
		existing.queue_free()
		return
	var MissionDebugUI := preload("res://Scripts/UI/MissionDebugUI.gd")
	var ui := MissionDebugUI.new()
	ui.name = "MissionDebugUI"
	get_tree().current_scene.add_child(ui)


func is_invisible_to_ai() -> bool:
	return invisible_to_ai

func is_crouching() -> bool:
	return crouching

func set_takedown_active(active: bool) -> void:
	takedown_active = active

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_TAB and event.ctrl_pressed and event.pressed and not event.echo:
		_cycle_slot2(1)
		return
	if event is InputEventMouseButton and event.ctrl_pressed and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_slot2(1)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_slot2(-1)
			return


func _handle_item_input() -> void:
	if Input.is_action_just_pressed("item_slot1_forward"):
		_cycle_slot1(1)
	if Input.is_action_just_pressed("item_slot1_backward"):
		_cycle_slot1(-1)
	if Input.is_action_just_pressed("item_slot1_activate"):
		var weapon := get_current_weapon()
		if weapon == "Explosive Grenade" or weapon == "Smoke Grenade":
			pass
		else:
			_activate_slot1()
	if Input.is_action_just_pressed("item_slot2_active"):
		_activate_slot2()


func _cycle_slot1(dir: int) -> void:
	if _weapon_items.is_empty():
		return
	var count := _weapon_items.size()
	_weapon_index = (_weapon_index + dir) % count
	if _weapon_index < 0:
		_weapon_index += count
	weapon_changed.emit(_weapon_items[_weapon_index])


func _cycle_slot2(dir: int) -> void:
	if _consumable_items.is_empty():
		return
	var count := _consumable_items.size()
	_consumable_index = (_consumable_index + dir) % count
	if _consumable_index < 0:
		_consumable_index += count
	consumable_changed.emit(_consumable_items[_consumable_index])


func _activate_slot1() -> void:
	if _weapon_items.is_empty() or _weapon_index < 0:
		return
	weapon_activated.emit(_weapon_items[_weapon_index])


func _activate_slot2() -> void:
	if _consumable_items.is_empty() or _consumable_index < 0:
		return
	consumable_activated.emit(_consumable_items[_consumable_index])


func get_weapon_items() -> Array[String]:
	return _weapon_items.duplicate()


func get_current_weapon() -> String:
	if _weapon_items.is_empty() or _weapon_index < 0:
		return ""
	return _weapon_items[_weapon_index]


func get_consumable_items() -> Array[String]:
	return _consumable_items.duplicate()


func get_current_consumable() -> String:
	if _consumable_items.is_empty() or _consumable_index < 0:
		return ""
	return _consumable_items[_consumable_index]


func add_item(item_name: String) -> void:
	inventory.append(item_name)
	var entry = ITEM_DB.get(item_name)
	if entry:
		if entry.slot == "weapon":
			_weapon_items.append(item_name)
			if _weapon_index == -1:
				_weapon_index = 0
				weapon_changed.emit(_weapon_items[0])
		else:
			_consumable_items.append(item_name)
			if _consumable_index == -1:
				_consumable_index = 0
				consumable_changed.emit(_consumable_items[0])
	item_collected.emit(item_name)

func has_item(item_name: String) -> bool:
	return item_name in inventory
