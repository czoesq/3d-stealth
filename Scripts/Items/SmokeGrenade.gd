extends RigidBody3D

var smoke_duration: float = 10.0
var smoke_radius: float = 2.5

var _fuse_timer: Timer


func _ready() -> void:
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.7
	mat.friction = 0.95
	physics_material_override = mat

	_fuse_timer = Timer.new()
	_fuse_timer.one_shot = true
	_fuse_timer.timeout.connect(_deploy_smoke)
	add_child(_fuse_timer)
	_fuse_timer.start(3.0)

	var sphere := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.1
	sm.height = 0.2
	var sphere_mat := StandardMaterial3D.new()
	sphere_mat.albedo_color = Color(0.25, 0.55, 0.2)
	sphere_mat.metallic = 0.3
	sphere_mat.roughness = 0.6
	sm.surface_set_material(0, sphere_mat)
	sphere.mesh = sm
	add_child(sphere)

	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.1
	cs.shape = sp
	add_child(cs)

	var cleanup := Timer.new()
	cleanup.one_shot = true
	cleanup.timeout.connect(_safe_cleanup)
	add_child(cleanup)
	cleanup.start(8.0)


func _deploy_smoke() -> void:
	var root := Node3D.new()
	root.name = "SmokeCloud"
	get_parent().add_child(root)
	root.global_position = global_position

	var smoke_area := Area3D.new()
	smoke_area.name = "SmokeArea"
	smoke_area.collision_layer = 4
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = smoke_radius
	shape.shape = sphere_shape
	smoke_area.add_child(shape)
	root.add_child(smoke_area)
	smoke_area.add_to_group("smoke")

	_spawn_smoke_vfx(root)
	_alert_enemies()

	var clear_timer := Timer.new()
	clear_timer.one_shot = true
	clear_timer.timeout.connect(root.queue_free)
	root.add_child(clear_timer)
	clear_timer.start(smoke_duration)

	queue_free()


func _spawn_smoke_vfx(root: Node3D) -> void:
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.4, 0.4, 0.4, 0.15)
	ground_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ground_mesh := CylinderMesh.new()
	ground_mesh.top_radius = smoke_radius * 0.9
	ground_mesh.bottom_radius = smoke_radius * 0.9
	ground_mesh.height = 0.01
	ground_mesh.surface_set_material(0, ground_mat)
	var ground := MeshInstance3D.new()
	ground.mesh = ground_mesh
	ground.rotation.x = PI / 2
	ground.position.y = 0.02
	root.add_child(ground)

	var gt := root.create_tween()
	gt.set_loops()
	gt.set_parallel(true)
	gt.tween_property(ground_mat, "albedo_color", Color(0.5, 0.5, 0.5, 0.25), 2.5)
	gt.tween_property(ground_mat, "albedo_color", Color(0.3, 0.3, 0.3, 0.08), 2.5).set_delay(2.5)

	for i in 35:
		var puff_mat := StandardMaterial3D.new()
		var gray := randf_range(0.3, 0.5)
		puff_mat.albedo_color = Color(gray, gray, gray, 0.4)
		puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

		var puff_mesh := SphereMesh.new()
		var r := randf_range(0.3, 0.7)
		puff_mesh.radius = r
		puff_mesh.height = r * 2
		puff_mesh.surface_set_material(0, puff_mat)

		var puff := MeshInstance3D.new()
		puff.mesh = puff_mesh
		root.add_child(puff)

		var offset := Vector3(
			randf_range(-1, 1),
			randf_range(0, 0.6),
			randf_range(-1, 1)
		) * smoke_radius * 0.5
		puff.position = offset

		var drift_target := offset + Vector3(
			randf_range(-0.6, 0.6),
			randf_range(0.2, 0.8),
			randf_range(-0.6, 0.6)
		)

		var pt := root.create_tween()
		pt.set_loops()
		pt.set_parallel(true)
		pt.tween_property(puff, "position", drift_target, randf_range(2.5, 4.5)).set_trans(Tween.TRANS_SINE)
		pt.tween_property(puff, "position", offset, randf_range(2.5, 4.5)).set_delay(randf_range(2.5, 4.5))
		var scale_pulse := 1.0 + randf_range(0.1, 0.4)
		pt.tween_property(puff, "scale", Vector3(scale_pulse, scale_pulse, scale_pulse), randf_range(1.5, 3.5))
		pt.tween_property(puff, "scale", Vector3.ONE, randf_range(1.5, 3.5)).set_delay(randf_range(1.5, 3.5))
		var fade_a := randf_range(0.2, 0.5)
		pt.tween_property(puff_mat, "albedo_color", Color(gray, gray, gray, fade_a), randf_range(2.0, 3.0))
		pt.tween_property(puff_mat, "albedo_color", Color(gray, gray, gray, 0.4), randf_range(2.0, 3.0)).set_delay(randf_range(2.0, 3.0))


func _alert_enemies() -> void:
	var enemies := get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		var dist := global_position.distance_to(e.global_position)
		if dist <= smoke_radius * 3.0:
			if e.has_method("smoke_detected"):
				e.smoke_detected(global_position, smoke_radius)


func _safe_cleanup() -> void:
	if is_inside_tree():
		queue_free()
