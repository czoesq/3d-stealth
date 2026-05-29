extends CharacterBody3D

enum State { IDLE, PATROL, SUSPICIOUS, ALERT, CHASE, KNOCKED_OUT }

@export_group("Vision")
@export var vision_range: float = 10.0
@export var vision_angle_h: float = 60.0
@export var vision_angle_v: float = 45.0

@export_group("Hearing")
@export var hearing_range: float = 8.0
@export var hearing_threshold: float = 10.0

@export_group("Detection")
@export var detection_max: float = 100.0
@export var sight_detection_rate: float = 20.0
@export var noise_detection_rate: float = 15.0
@export var detection_decay: float = 10.0
@export var alert_decay: float = 5.0
@export var close_range_multiplier: float = 2.0
@export var close_range_threshold: float = 4.0
@export var movement_multiplier: float = 1.5
@export var suspicious_threshold: float = 10.0
@export var alert_threshold: float = 50.0

@export_group("Movement")
@export var patrol_speed: float = 1.25
@export var patrol_pause_chance: float = 0.0
@export var patrol_pause_min: float = 2.0
@export var patrol_pause_max: float = 5.0
@export var chase_speed: float = 5.0
@export var suspicious_speed: float = 3.5
@export var angular_speed: float = 180.0

@export_group("Knocked Out")
@export var revive_time: float = 4.0

@export_group("Navigation")
@export var target_reached_distance: float = 1.0
@export var turn_rate: float = 8.0

@export_group("Patrol")
@export var patrol_radius: float = 15.0

@export_group("Debug")
@export var show_vision_cone: bool = true
@export var debug: bool = false

var state: State = State.IDLE
var detection_meter: float = 0.0
var last_known_player_pos: Vector3
var player_in_sight: bool = false
var patrol_index: int = 0
var patrol_forward: bool = true
var idle_timer: float = 0.0
var being_revived: bool = false
var revive_progress: float = 0.0
var suspicious_target: Vector3
var alertness_cooldown: float = 0.0
var start_position: Vector3
var patrol_paused: bool = false
var patrol_pause_timer: float = 0.0
var _stuck_frames: int = 0
var _last_position: Vector3

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var player: CharacterBody3D
var nav_agent: NavigationAgent3D
var vision_area: Area3D
var hearing_area: Area3D
var vision_ray: RayCast3D
var patrol_points: Array[Node3D] = []
var vision_cone_mesh: MeshInstance3D

@onready var collision_shape: CollisionShape3D = $CollisionShape3D


signal enemy_spotted(instigator)
signal alarm_triggered(instigator)
signal enemy_revived(instigator)


func _ready() -> void:
	nav_agent = $NavigationAgent3D
	vision_area = $VisionArea
	hearing_area = $HearingArea
	vision_ray = $VisionRay
	start_position = global_position
	_last_position = global_position

	_setup_vision_cone_debug()
	_setup_vision_area()
	_setup_hearing_area()
	_collect_patrol_points()
	_auto_generate_patrol()

	if debug:
		print("enemy _ready: pos=", global_position, " patrol_points=", patrol_points.size())
		for p in patrol_points:
			print("  patrol: ", p.name, " global=", p.global_position)

	_enter_idle()


func _setup_vision_area() -> void:
	vision_area.body_entered.connect(_on_vision_body_entered)
	vision_area.body_exited.connect(_on_vision_body_exited)
	var shape := SphereShape3D.new()
	shape.radius = vision_range
	var col := CollisionShape3D.new()
	col.shape = shape
	col.name = "VisionShape"
	for c in vision_area.get_children():
		if c is CollisionShape3D:
			vision_area.remove_child(c)
			c.queue_free()
	vision_area.add_child(col)
	_update_vision_cone_mesh()


func _setup_hearing_area() -> void:
	hearing_area.body_entered.connect(_on_hearing_body_entered)
	hearing_area.body_exited.connect(_on_hearing_body_exited)
	var shape := SphereShape3D.new()
	shape.radius = hearing_range
	var col := CollisionShape3D.new()
	col.shape = shape
	col.name = "HearingShape"
	for c in hearing_area.get_children():
		if c is CollisionShape3D:
			hearing_area.remove_child(c)
			c.queue_free()
	hearing_area.add_child(col)


func _collect_patrol_points() -> void:
	var container := $PatrolPoints
	if not container:
		return
	patrol_points.clear()
	for child in container.get_children():
		if child is Node3D:
			patrol_points.append(child)


func _auto_generate_patrol() -> void:
	if patrol_points.size() > 0:
		return
	var container := $PatrolPoints
	if not container:
		container = Node3D.new()
		container.name = "PatrolPoints"
		add_child(container)
		container.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self
	var n := randi_range(4, 6)
	var circular := randi() % 2 == 0
	var angle_offset := randf_range(0.0, TAU)
	var radius := randf_range(patrol_radius * 0.4, patrol_radius * 0.8)
	var nav_half := 6.0
	for i in n:
		var pt := Marker3D.new()
		pt.name = "PatrolPoint_%d" % i
		var pos: Vector3
		for attempt in 10:
			if circular:
				var a := angle_offset + float(i) / float(n) * TAU
				pos = start_position + Vector3(cos(a) * radius, 0.0, sin(a) * radius)
			else:
				var t := float(i) / float(n - 1) * 2.0 - 1.0
				var dir := Vector3(cos(angle_offset), 0.0, sin(angle_offset))
				pos = start_position + dir * t * radius
			if abs(pos.x) <= nav_half and abs(pos.z) <= nav_half:
				break
			angle_offset += deg_to_rad(30.0)
		pos.x = clampf(pos.x, -nav_half, nav_half)
		pos.z = clampf(pos.z, -nav_half, nav_half)
		pt.position = pos - global_position
		container.add_child(pt)
		patrol_points.append(pt)


func _setup_vision_cone_debug() -> void:
	vision_cone_mesh = MeshInstance3D.new()
	vision_cone_mesh.name = "VisionConeDebug"
	add_child(vision_cone_mesh)
	_update_vision_cone_mesh()
	vision_cone_mesh.visible = show_vision_cone


func _update_vision_cone_mesh() -> void:
	if not vision_cone_mesh or vision_range <= 0.0:
		return
	var hw := vision_range * tan(deg_to_rad(vision_angle_h * 0.5))
	var hh := vision_range * tan(deg_to_rad(vision_angle_v * 0.5))
	var apex := Vector3(0.0, 1.6, 0.0)
	var dist := -vision_range
	var b1 := Vector3(-hw, -hh, dist)
	var b2 := Vector3(hw, -hh, dist)
	var b3 := Vector3(hw, hh, dist)
	var b4 := Vector3(-hw, hh, dist)

	var verts := PackedVector3Array([
		apex, b1, b2,
		apex, b2, b3,
		apex, b3, b4,
		apex, b4, b1,
		b1, b3, b2,
		b1, b4, b3,
	])
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.0, 0.12)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var array := []
	array.resize(Mesh.ARRAY_MAX)
	array[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, array)
	mesh.surface_set_material(0, mat)
	vision_cone_mesh.mesh = mesh


func _enter_idle() -> void:
	state = State.IDLE
	idle_timer = randf_range(2.0, 5.0)
	nav_agent.target_position = global_position


func _on_vision_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player = body


func _on_vision_body_exited(_body: Node) -> void:
	pass


func _on_hearing_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player = body


func _on_hearing_body_exited(_body: Node) -> void:
	pass


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	match state:
		State.IDLE:
			_process_idle(delta)
		State.PATROL:
			_process_patrol(delta)
		State.SUSPICIOUS:
			_process_suspicious(delta)
		State.ALERT:
			_process_alert(delta)
		State.CHASE:
			_process_chase(delta)
		State.KNOCKED_OUT:
			_process_knocked_out(delta)

	_update_detection(delta)


func _process_idle(delta: float) -> void:
	idle_timer -= delta
	if idle_timer <= 0.0:
		if patrol_points.size() > 0:
			if debug:
				print("enemy: idle->patrol")
			_enter_patrol()
		else:
			if debug:
				print("enemy: idle timeout, no patrol points, re-idle")
			idle_timer = randf_range(2.0, 5.0)


func _enter_patrol() -> void:
	state = State.PATROL
	if debug:
		print("enemy: enter patrol")
	_pick_next_patrol_point()


func _pick_next_patrol_point() -> void:
	if patrol_points.size() == 0:
		if debug:
			print("enemy: pick patrol - empty")
		_enter_idle()
		return
	if patrol_points.size() == 1:
		nav_agent.target_position = patrol_points[0].global_position
		if debug:
			print("enemy: patrol target (single) -> ", nav_agent.target_position)
		return
	if patrol_forward:
		patrol_index += 1
		if patrol_index >= patrol_points.size():
			patrol_forward = false
			patrol_index = maxi(patrol_points.size() - 2, 0)
	else:
		patrol_index -= 1
		if patrol_index < 0:
			patrol_forward = true
			patrol_index = mini(1, patrol_points.size() - 1)
	var target := patrol_points[patrol_index].global_position
	nav_agent.target_position = target
	if debug:
		var map := nav_agent.get_navigation_map()
		var path := NavigationServer3D.map_get_path(map, global_position, target, true)
		print("enemy: patrol target idx=", patrol_index, " -> ", target, " path_nodes=", path.size())
		for i in path.size():
			print("  node[", i, "] = ", path[i])


func _process_patrol(delta: float) -> void:
	if patrol_paused:
		patrol_pause_timer -= delta
		velocity = Vector3.ZERO
		move_and_slide()
		if patrol_pause_timer <= 0.0:
			patrol_paused = false
			if debug:
				print("enemy: patrol pause ended")
			_pick_next_patrol_point()
		return
	if nav_agent.is_navigation_finished():
		if debug:
			print("enemy: patrol nav finished")
		if randf() < patrol_pause_chance:
			patrol_paused = true
			patrol_pause_timer = randf_range(patrol_pause_min, patrol_pause_max)
			if debug:
				print("enemy: patrol pausing for %.1fs" % patrol_pause_timer)
			velocity = Vector3.ZERO
			move_and_slide()
			return
		_pick_next_patrol_point()
	_move_toward_target(patrol_speed, delta)


func _enter_suspicious(target_pos: Vector3) -> void:
	state = State.SUSPICIOUS
	suspicious_target = target_pos
	nav_agent.target_position = target_pos


func _process_suspicious(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		_rotate_look(suspicious_target, delta)
	if detection_meter >= alert_threshold:
		_enter_alert()
	elif detection_meter <= 0.0:
		if patrol_points.size() > 0:
			_enter_patrol()
		else:
			_enter_idle()
	else:
		_move_toward_target(suspicious_speed, delta)


func _enter_alert() -> void:
	state = State.ALERT
	alertness_cooldown = 10.0
	nav_agent.target_position = last_known_player_pos
	enemy_spotted.emit(self)


func _process_alert(delta: float) -> void:
	alertness_cooldown -= delta
	if detection_meter >= detection_max:
		_enter_chase()
	elif alertness_cooldown <= 0.0 and detection_meter <= suspicious_threshold:
		if patrol_points.size() > 0:
			_enter_patrol()
		else:
			_enter_idle()
	else:
		if nav_agent.is_navigation_finished():
			_update_last_known_pos()
		_move_toward_target(chase_speed, delta)


func _enter_chase() -> void:
	state = State.CHASE
	alarm_triggered.emit(self)
	enemy_spotted.emit(self)
	_call_for_help()


func _call_for_help() -> void:
	var nearby := get_tree().get_nodes_in_group("enemy")
	for e in nearby:
		if e == self:
			continue
		if e.global_position.distance_to(global_position) < vision_range * 2.0:
			e.respond_to_alarm(self)


func respond_to_alarm(caller) -> void:
	if state == State.KNOCKED_OUT or state == State.CHASE:
		return
	if state == State.ALERT or state == State.SUSPICIOUS:
		detection_meter = maxf(detection_meter, alert_threshold)
	_enter_alert()
	last_known_player_pos = caller.last_known_player_pos if caller.has_method("get_last_known_pos") else caller.global_position
	nav_agent.target_position = last_known_player_pos


func get_last_known_pos() -> Vector3:
	return last_known_player_pos


func _process_chase(delta: float) -> void:
	if player:
		last_known_player_pos = player.global_position
		nav_agent.target_position = last_known_player_pos
	else:
		if nav_agent.is_navigation_finished():
			_enter_alert()
			return
	if detection_meter <= 0.0:
		_enter_alert()
		return
	_move_toward_target(chase_speed, delta)


func _process_knocked_out(delta: float) -> void:
	if being_revived:
		revive_progress += delta / revive_time
		if revive_progress >= 1.0:
			_revive()


func knock_out() -> void:
	state = State.KNOCKED_OUT
	being_revived = false
	revive_progress = 0.0
	detection_meter = 0.0
	nav_agent.target_position = global_position


func revive_check(reviver) -> bool:
	if state != State.KNOCKED_OUT or being_revived:
		return false
	being_revived = true
	revive_progress = 0.0
	reviver.enemy_revived.emit(self)
	return true


func _revive() -> void:
	state = State.ALERT
	detection_meter = alert_threshold
	being_revived = false
	revive_progress = 0.0
	enemy_revived.emit(self)


func _update_detection(delta: float) -> void:
	if state == State.KNOCKED_OUT:
		return

	var detected_this_frame := false

	if _check_vision():
		detected_this_frame = true
		var dist := 1.0
		if player:
			dist = maxf(global_position.distance_to(player.global_position), 1.0)
		var dist_factor := close_range_multiplier if dist < close_range_threshold else 1.0
		var move_factor := movement_multiplier if _is_player_moving() else 1.0
		var rate := sight_detection_rate * dist_factor * move_factor * delta
		detection_meter = minf(detection_meter + rate, detection_max)
		last_known_player_pos = player.global_position if player else global_position

	if not detected_this_frame and _check_hearing():
		detected_this_frame = true
		var noise_level := _get_player_noise()
		if noise_level >= hearing_threshold:
			var rate := noise_detection_rate * (noise_level / detection_max) * delta
			detection_meter = minf(detection_meter + rate, detection_max)
			if player:
				suspicious_target = player.global_position

	if not detected_this_frame:
		var decay := alert_decay if state == State.ALERT or state == State.CHASE else detection_decay
		detection_meter = maxf(detection_meter - decay * delta, 0.0)

	_handle_state_transitions(detected_this_frame)


func _handle_state_transitions(detected: bool) -> void:
	if state == State.KNOCKED_OUT:
		return

	if state == State.IDLE and detected and detection_meter > 0:
		if player:
			_enter_suspicious(last_known_player_pos if player_in_sight else player.global_position)
		return

	if state == State.PATROL and detected:
		if detection_meter >= suspicious_threshold and player_in_sight:
			_enter_suspicious(last_known_player_pos)
		elif detection_meter > 0 and player:
			suspicious_target = player.global_position
			_enter_suspicious(suspicious_target)
		return

	if state == State.SUSPICIOUS:
		if detection_meter >= alert_threshold:
			_enter_alert()
		elif detection_meter <= 0 and not detected:
			if patrol_points.size() > 0:
				_enter_patrol()
			else:
				_enter_idle()
		return

	if state == State.ALERT:
		if detection_meter >= detection_max:
			_enter_chase()
		return

	if state == State.CHASE and not detected:
		if detection_meter <= alert_threshold:
			_enter_alert()
		return


func _check_vision() -> bool:
	if not player:
		return false

	var pos := player.global_position
	var dir_to_player := (pos - global_position).normalized()
	var forward_dir := -global_transform.basis.z

	var angle_h := rad_to_deg(acos( clampf(dir_to_player.dot(forward_dir), -1.0, 1.0) ))
	if angle_h > vision_angle_h * 0.5:
		player_in_sight = false
		return false

	var angle_v := rad_to_deg(acos( clampf(dir_to_player.dot(Vector3.UP), -1.0, 1.0) ))
	if angle_v > vision_angle_v * 0.5 + 90.0:
		player_in_sight = false
		return false

	var dist := global_position.distance_to(pos)
	if dist > vision_range:
		return false

	vision_ray.target_position = vision_ray.to_local(pos)
	vision_ray.force_raycast_update()
	if vision_ray.is_colliding():
		var col := vision_ray.get_collider()
		if col == player or (col is Node and col.is_in_group("player")):
			player_in_sight = true
			return true

	player_in_sight = false
	return false


func _check_hearing() -> bool:
	if not player:
		return false
	var dist := global_position.distance_to(player.global_position)
	if dist > hearing_range:
		return false
	return _get_player_noise() >= hearing_threshold


func _get_player_noise() -> float:
	if not player or not player.has_method("get_noise_level"):
		return 0.0
	return player.get_noise_level()


func _is_player_moving() -> bool:
	if not player:
		return false
	if not player.has_method("get_velocity"):
		return false
	return player.velocity.length_squared() > 0.1


func _update_last_known_pos() -> void:
	if player:
		last_known_player_pos = player.global_position
		nav_agent.target_position = last_known_player_pos


func _move_toward_target(speed: float, delta: float) -> void:
	if nav_agent.is_navigation_finished():
		if debug and velocity.length_squared() > 0.0:
			print("enemy: move nav_finished=true, was moving, stopping")
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var next_pos := nav_agent.get_next_path_position()
	var dir := (next_pos - global_position).normalized()
	dir.y = 0.0

	if dir.length_squared() <= 0.0:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var dist_moved := global_position.distance_to(_last_position)
	_last_position = global_position

	if dist_moved < 0.005:
		_stuck_frames += 1
	else:
		_stuck_frames = 0

	velocity = dir * speed

	if _stuck_frames > 4:
		if debug:
			print("enemy: stuck for ", _stuck_frames, " frames, sidestepping")
		var perp := Vector3(-dir.z, 0.0, dir.x)
		velocity = (dir + perp * 0.6).normalized() * speed

	move_and_slide()

	var target_basis := Basis.looking_at(-dir, Vector3.UP)
	transform.basis = transform.basis.slerp(target_basis, turn_rate * delta)


func _rotate_look(target: Vector3, delta: float) -> void:
	var dir := (target - global_position).normalized()
	dir.y = 0.0
	if dir.length_squared() > 0.0:
		var target_basis := Basis.looking_at(-dir, Vector3.UP)
		transform.basis = transform.basis.slerp(target_basis, turn_rate * delta)
