extends CharacterBody3D

enum State { IDLE, PATROL, SUSPICIOUS, ALERT, CHASE, KNOCKED_OUT }

@export_group("Vision")
@export var vision_range: float = 10.0:
	set(v):
		vision_range = v
		if vision_area:
			_setup_vision_area()
@export var vision_angle_h: float = 80.0
@export var vision_angle_v: float = 50.0

@export_group("Hearing")
@export var hearing_range: float = 8.0
@export var hearing_threshold: float = 10.0

@export_group("Detection")
@export var detection_max: float = 100.0
@export var sight_detection_rate: float = 50.0
@export var noise_detection_rate: float = 15.0
@export var detection_decay: float = 10.0
@export var alert_decay: float = 5.0
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
@export var show_waypoints: bool = true
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
var _investigate_timer: float = 0.0
var _detection_bar_bg: MeshInstance3D
var _detection_bar_fill: MeshInstance3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var player: CharacterBody3D
var nav_agent: NavigationAgent3D
var vision_area: Area3D
var hearing_area: Area3D
var vision_ray: RayCast3D
var patrol_points: Array[Node3D] = []
var patrol_world_positions: Array[Vector3] = []
var vision_cone_mesh: MeshInstance3D
var _debug_patrol_markers: Array[MeshInstance3D] = []
var _debug_target_marker: MeshInstance3D
var _vision_cone_mat: StandardMaterial3D

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
	last_known_player_pos = global_position

	_setup_vision_cone_debug()
	_setup_detection_bar()
	_setup_vision_area()
	_setup_hearing_area()
	_collect_patrol_points()
	_auto_generate_patrol()
	_setup_debug_waypoints()

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
	if not player:
		call_deferred("_find_player_node")


func _find_player_node() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0] as CharacterBody3D


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
	patrol_world_positions.clear()
	for child in container.get_children():
		if child is Node3D:
			patrol_points.append(child)
			patrol_world_positions.append(child.global_position)


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
		patrol_world_positions.append(pos)


func _setup_vision_cone_debug() -> void:
	vision_cone_mesh = MeshInstance3D.new()
	vision_cone_mesh.name = "VisionConeDebug"
	add_child(vision_cone_mesh)
	_update_vision_cone_mesh()
	vision_cone_mesh.visible = show_vision_cone


func _setup_detection_bar() -> void:
	var root := Node3D.new()
	root.name = "DetectionBar"
	add_child(root)
	root.position = Vector3(0, 1.2, 0)

	var bg_mesh := BoxMesh.new()
	bg_mesh.size = Vector3(1.0, 0.1, 0.02)
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.15, 0.15, 0.15, 0.85)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mesh.material = bg_mat
	_detection_bar_bg = MeshInstance3D.new()
	_detection_bar_bg.mesh = bg_mesh
	_detection_bar_bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(_detection_bar_bg)

	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3(0.96, 0.08, 0.021)
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.0, 1.0, 0.0, 0.9)
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mesh.material = fill_mat
	_detection_bar_fill = MeshInstance3D.new()
	_detection_bar_fill.mesh = fill_mesh
	_detection_bar_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_detection_bar_fill.position.x = -0.48
	root.add_child(_detection_bar_fill)


func _setup_debug_waypoints() -> void:
	if not show_waypoints:
		return
	for i in patrol_points.size():
		if i >= patrol_world_positions.size():
			break
		var sphere := MeshInstance3D.new()
		sphere.name = "DebugPatrolPoint_" + patrol_points[i].name
		var mesh := SphereMesh.new()
		mesh.radius = 0.15
		mesh.height = 0.3
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.5, 1.0, 0.6)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material = mat
		sphere.mesh = mesh
		add_child(sphere)
		sphere.set_as_top_level(true)
		sphere.global_position = patrol_world_positions[i]
		_debug_patrol_markers.append(sphere)

	var target_sphere := MeshInstance3D.new()
	target_sphere.name = "DebugCurrentTarget"
	var tmesh := SphereMesh.new()
	tmesh.radius = 0.25
	tmesh.height = 0.5
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.2, 1.0, 0.2, 0.8)
	tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tmesh.material = tmat
	target_sphere.mesh = tmesh
	add_child(target_sphere)
	target_sphere.set_as_top_level(true)
	_debug_target_marker = target_sphere


func _update_debug_waypoints() -> void:
	if not show_waypoints:
		return
	if _debug_target_marker:
		_debug_target_marker.global_position = nav_agent.target_position


func _update_detection_bar() -> void:
	if not _detection_bar_fill or not _detection_bar_bg:
		return
	var root := _detection_bar_bg.get_parent() as Node3D
	if not root:
		return
	if detection_meter <= 0.0:
		root.visible = false
		return
	root.visible = true
	var pct := detection_meter / detection_max
	_detection_bar_fill.scale.x = pct
	_detection_bar_fill.position.x = -0.48 + 0.48 * pct

	var color: Color
	if pct < 0.3:
		color = Color(0.0, 1.0, 0.0, 0.9)
	elif pct < 0.6:
		color = Color(1.0, 1.0, 0.0, 0.9)
	else:
		color = Color(1.0, 0.2, 0.0, 0.9)
	var mat := _detection_bar_fill.mesh.surface_get_material(0) as StandardMaterial3D
	if mat:
		mat.albedo_color = color


func _update_vision_cone_mesh() -> void:
	if not vision_cone_mesh or vision_range <= 0.0:
		return
	var apex := Vector3(0.0, 0.9, 0.0)
	var h_seg := 20
	var v_seg := 10
	var half_h := deg_to_rad(vision_angle_h)
	var half_v := deg_to_rad(vision_angle_v)

	var front: Array[Vector3] = []
	for i in h_seg + 1:
		var theta := -half_h + 2.0 * half_h * float(i) / float(h_seg)
		for j in v_seg + 1:
			var phi := -half_v + 2.0 * half_v * float(j) / float(v_seg)
			var dir := Vector3(
				sin(theta) * cos(phi),
				sin(phi),
				-cos(theta) * cos(phi)
			)
			front.append(apex + dir * vision_range)

	var verts := PackedVector3Array()

	# Front face (tessellated grid)
	for i in h_seg:
		for j in v_seg:
			var a := i * (v_seg + 1) + j
			var b := a + 1
			var c := (i + 1) * (v_seg + 1) + j
			var d := c + 1
			verts.append(front[a]); verts.append(front[c]); verts.append(front[b])
			verts.append(front[b]); verts.append(front[c]); verts.append(front[d])

	# Side panels: apex to each perimeter edge
	for i in h_seg:
		var a := i * (v_seg + 1) + v_seg
		var b := (i + 1) * (v_seg + 1) + v_seg
		verts.append(apex); verts.append(front[a]); verts.append(front[b])
		a = i * (v_seg + 1)
		b = (i + 1) * (v_seg + 1)
		verts.append(apex); verts.append(front[b]); verts.append(front[a])
	for j in v_seg:
		var a := j
		var b := j + 1
		verts.append(apex); verts.append(front[b]); verts.append(front[a])
		a = h_seg * (v_seg + 1) + j
		b = a + 1
		verts.append(apex); verts.append(front[a]); verts.append(front[b])
	if not _vision_cone_mat:
		_vision_cone_mat = StandardMaterial3D.new()
		_vision_cone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_vision_cone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_vision_cone_mat.no_depth_test = true
		_vision_cone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_update_vision_cone_color()

	var array := []
	array.resize(Mesh.ARRAY_MAX)
	array[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, array)
	mesh.surface_set_material(0, _vision_cone_mat)
	vision_cone_mesh.mesh = mesh


func _update_vision_cone_color() -> void:
	if not _vision_cone_mat:
		return
	var c: Color
	if state == State.CHASE:
		c = Color(1.0, 0.0, 0.0, 0.15)
	elif player_in_sight and detection_meter > 0:
		var intensity := minf(detection_meter / alert_threshold, 1.0)
		c = Color(1.0, 1.0 - intensity * 0.7, 0.0, 0.12 + 0.2 * intensity)
	elif detection_meter <= 0.0 and state == State.PATROL:
		c = Color(0.1, 0.9, 0.0, 0.08)
	else:
		c = Color(1.0, 0.85, 0.0, 0.12)
	_vision_cone_mat.albedo_color = c


func _enter_idle() -> void:
	state = State.IDLE
	idle_timer = randf_range(2.0, 5.0)
	nav_agent.target_position = global_position


func _on_vision_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player = body


func _on_vision_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_sight = false


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
	_update_detection_bar()
	_update_vision_cone_color()
	_update_debug_waypoints()
	move_and_slide()


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
	if patrol_world_positions.size() == 0:
		if debug:
			print("enemy: pick patrol - empty")
		_enter_idle()
		return
	if patrol_world_positions.size() == 1:
		nav_agent.target_position = patrol_world_positions[0]
		if debug:
			print("enemy: patrol target (single) -> ", nav_agent.target_position)
		return
	if patrol_forward:
		patrol_index += 1
		if patrol_index >= patrol_world_positions.size():
			patrol_forward = false
			patrol_index = maxi(patrol_world_positions.size() - 2, 0)
	else:
		patrol_index -= 1
		if patrol_index < 0:
			patrol_forward = true
			patrol_index = mini(1, patrol_world_positions.size() - 1)
	var target := patrol_world_positions[patrol_index]

	if _is_path_blocked(target):
		if debug:
			print("enemy: path blocked to patrol idx=", patrol_index, " ", target, ", skipping ahead")
		var tries := 0
		while tries < patrol_world_positions.size() and _is_path_blocked(target):
			if patrol_forward:
				patrol_index += 1
				if patrol_index >= patrol_world_positions.size():
					patrol_forward = false
					patrol_index = maxi(patrol_world_positions.size() - 2, 0)
			else:
				patrol_index -= 1
				if patrol_index < 0:
					patrol_forward = true
					patrol_index = mini(1, patrol_world_positions.size() - 1)
			target = patrol_world_positions[patrol_index]
			tries += 1

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
			return
		_pick_next_patrol_point()
	_move_toward_target(patrol_speed, delta)


func _enter_suspicious(target_pos: Vector3) -> void:
	state = State.SUSPICIOUS
	suspicious_target = target_pos


func _process_suspicious(delta: float) -> void:
	velocity = velocity.lerp(Vector3.ZERO, 4.0 * delta)
	_rotate_look(suspicious_target, delta)
	if detection_meter >= detection_max:
		_enter_chase()
	elif detection_meter <= 0.0:
		if patrol_points.size() > 0:
			_enter_patrol()
		else:
			_enter_idle()


func _enter_alert() -> void:
	state = State.ALERT
	alertness_cooldown = 10.0
	_investigate_timer = 0.0
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
	nav_agent.target_position = last_known_player_pos
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
	if player and _check_vision():
		last_known_player_pos = player.global_position
		nav_agent.target_position = last_known_player_pos
		_investigate_timer = 0.0
		_move_toward_target(chase_speed, delta)
		return

	if not nav_agent.is_navigation_finished():
		_move_toward_target(chase_speed, delta)
		return

	_investigate_timer += delta
	if _investigate_timer >= 2.0:
		if debug:
			print("enemy: investigate done, returning to patrol")
		_return_to_nearest_patrol()


func _return_to_nearest_patrol() -> void:
	if patrol_world_positions.size() == 0:
		_enter_idle()
		return
	state = State.PATROL
	patrol_paused = false
	_investigate_timer = 0.0
	var nearest_idx := 0
	var nearest_dist := global_position.distance_squared_to(patrol_world_positions[0])
	for i in range(1, patrol_world_positions.size()):
		var d := global_position.distance_squared_to(patrol_world_positions[i])
		if d < nearest_dist:
			nearest_dist = d
			nearest_idx = i
	patrol_index = nearest_idx
	patrol_forward = nearest_idx < patrol_world_positions.size() - 1
	var target := patrol_world_positions[patrol_index]
	if global_position.distance_to(target) <= target_reached_distance:
		patrol_paused = true
		patrol_pause_timer = randf_range(1.0, 2.0)
		if debug:
			print("enemy: already at nearest patrol, pausing")
		velocity = Vector3.ZERO
		return
	nav_agent.target_position = target
	if debug:
		print("enemy: return to nearest patrol idx=", patrol_index, " ", nav_agent.target_position)


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
			dist = global_position.distance_to(player.global_position)
		var dist_factor := 2.0 - (dist / vision_range) * 1.5
		var move_factor := movement_multiplier if _is_player_moving() else 1.0
		var crouch_factor := 0.8 if player and player.has_method("is_crouching") and player.is_crouching() else 1.0
		var rate := sight_detection_rate * dist_factor * move_factor * crouch_factor * delta
		detection_meter = minf(detection_meter + rate, detection_max)
		if state == State.SUSPICIOUS and player:
			suspicious_target = player.global_position
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

	if state == State.IDLE and detected:
		if player:
			_enter_suspicious(last_known_player_pos if player_in_sight else player.global_position)
		return

	if state == State.PATROL and detected:
		if player_in_sight:
			_enter_suspicious(last_known_player_pos)
		elif player:
			suspicious_target = player.global_position
			_enter_suspicious(suspicious_target)
		return

	if state == State.SUSPICIOUS:
		if detection_meter >= detection_max:
			_enter_chase()
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

	if player.has_method("is_invisible_to_ai") and player.is_invisible_to_ai():
		player_in_sight = false
		return false

	var pos := player.global_position
	var dir_to_player := (pos - global_position).normalized()
	var forward_dir := -global_transform.basis.z

	var angle_h := rad_to_deg(acos( clampf(dir_to_player.dot(forward_dir), -1.0, 1.0) ))
	if angle_h > vision_angle_h:
		player_in_sight = false
		return false

	var angle_v := rad_to_deg(asin( clampf(dir_to_player.y, -1.0, 1.0) ))
	if abs(angle_v) > vision_angle_v:
		player_in_sight = false
		return false

	var dist := global_position.distance_to(pos)
	if dist > vision_range:
		player_in_sight = false
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
		return

	var next_pos := nav_agent.get_next_path_position()
	if next_pos == Vector3.ZERO:
		if debug:
			print("enemy: move - invalid nav path (next_pos is ZERO), stopping")
		velocity = Vector3.ZERO
		return

	var dir := (next_pos - global_position).normalized()
	dir.y = 0.0

	if dir.length_squared() <= 0.0:
		velocity = Vector3.ZERO
		return

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

	var target_basis := Basis.looking_at(dir, Vector3.UP)
	transform.basis = transform.basis.slerp(target_basis, turn_rate * delta)


func _is_path_blocked(target: Vector3) -> bool:
	var diff := target - global_position
	if diff.length_squared() <= 0.01:
		return false
	var map := nav_agent.get_navigation_map()
	if not map.is_valid():
		return false
	var path := NavigationServer3D.map_get_path(map, global_position, target, true)
	return path.size() == 0


func _rotate_look(target: Vector3, delta: float) -> void:
	var dir := (target - global_position).normalized()
	dir.y = 0.0
	if dir.length_squared() > 0.0:
		var target_basis := Basis.looking_at(dir, Vector3.UP)
		transform.basis = transform.basis.slerp(target_basis, turn_rate * delta)
