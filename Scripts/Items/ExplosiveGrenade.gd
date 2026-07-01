extends RigidBody3D

var explosion_radius: float = 5.0
var explosion_damage: float = 60.0

var _fuse_timer: Timer


func _ready() -> void:
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.7
	mat.friction = 0.95
	physics_material_override = mat

	_fuse_timer = Timer.new()
	_fuse_timer.one_shot = true
	_fuse_timer.timeout.connect(_explode)
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


func _explode() -> void:
	_spawn_explosion_fx()

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) <= explosion_radius:
			if enemy.has_method("kill"):
				enemy.kill()

	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p):
			continue
		var dist := global_position.distance_to(p.global_position)
		if dist <= explosion_radius:
			var dmg := explosion_damage * (1.0 - dist / explosion_radius)
			if p.has_method("take_damage"):
				p.take_damage(dmg)

	for node in get_tree().get_nodes_in_group("interactable"):
		if not is_instance_valid(node):
			continue
		if node.has_method("_break_apart"):
			if global_position.distance_to(node.global_position) <= explosion_radius:
				node._break_apart()

	for node in get_tree().get_nodes_in_group("breakable"):
		if not is_instance_valid(node):
			continue
		if global_position.distance_to(node.global_position) <= explosion_radius:
			if node.has_method("break_apart"):
				node.break_apart()

	queue_free()


func _spawn_explosion_fx() -> void:
	var root := Node3D.new()
	root.name = "GrenadeExplosionFX"
	get_parent().add_child(root)
	root.global_position = global_position

	var growth_duration := 1.0
	var max_radius := explosion_radius

	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.0, 0.5, 0.05)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1.0, 0.6, 0.1)
	flash_mat.emission_energy_multiplier = 20.0

	var flash := MeshInstance3D.new()
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.5
	flash_mesh.height = 1.0
	flash_mesh.surface_set_material(0, flash_mat)
	flash.mesh = flash_mesh
	flash.scale = Vector3(0.01, 0.01, 0.01)
	root.add_child(flash)

	var ft := root.create_tween()
	ft.set_parallel(true)
	ft.tween_property(flash, "scale", Vector3(max_radius / 0.5, max_radius / 0.5, max_radius / 0.5), growth_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ft.tween_method(func(v): flash_mat.emission_energy_multiplier = v, 20.0, 0.0, 0.5).set_delay(growth_duration)
	ft.tween_method(func(v): flash_mat.albedo_color = Color(v, 0.5 * v + 0.05, 0.02 * v), 1.0, 0.0, 0.5).set_delay(growth_duration)

	for i in 35:
		var edge_mat := StandardMaterial3D.new()
		edge_mat.albedo_color = Color(
			randf_range(0.9, 1.0),
			randf_range(0.4, 0.7),
			randf_range(0.0, 0.08))
		edge_mat.emission_enabled = true
		edge_mat.emission = edge_mat.albedo_color
		edge_mat.emission_energy_multiplier = 8.0

		var edge_mesh := SphereMesh.new()
		var r := randf_range(0.03, 0.07)
		edge_mesh.radius = r
		edge_mesh.height = r * 2
		edge_mesh.surface_set_material(0, edge_mat)
		var edge := MeshInstance3D.new()
		edge.mesh = edge_mesh
		root.add_child(edge)

		var dir := Vector3(
			randf_range(-1, 1),
			randf_range(-0.3, 1.0),
			randf_range(-1, 1)
		).normalized()
		var delay := randf_range(0.0, growth_duration)
		var progress := clampf(delay / growth_duration, 0.01, 1.0)
		var surface_r := max_radius * sqrt(progress)
		var start_pos := dir * surface_r
		var end_pos := dir * max_radius * randf_range(0.95, 1.4)
		var fly_dur := randf_range(0.15, 0.35)

		edge.position = start_pos
		edge.scale = Vector3.ZERO

		var et := root.create_tween()
		et.set_parallel(true)
		et.tween_property(edge, "scale", Vector3(1, 1, 1), 0.02).set_delay(delay)
		et.tween_property(edge, "position", end_pos, fly_dur).set_trans(Tween.TRANS_QUAD).set_delay(delay)
		et.tween_property(edge_mat, "emission_energy_multiplier", 0.0, 0.12).set_delay(delay + 0.03)
		et.tween_property(edge_mat, "albedo_color", Color(0.5, 0.2, 0.0, 0), 0.15).set_delay(delay + 0.05)
		et.tween_property(edge, "scale", Vector3.ZERO, 0.08).set_delay(delay + fly_dur * 0.4)
		et.tween_callback(edge.queue_free).set_delay(delay + fly_dur + 0.1)

	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.15, 0.08, 0.02, 0.6)
	ground_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var ground := MeshInstance3D.new()
	var ground_mesh := CylinderMesh.new()
	ground_mesh.top_radius = 1.0
	ground_mesh.bottom_radius = 1.0
	ground_mesh.height = 0.02
	ground_mesh.surface_set_material(0, ground_mat)
	ground.mesh = ground_mesh
	ground.rotation.x = PI / 2
	ground.position.y = 0.02
	root.add_child(ground)

	var gt := root.create_tween()
	gt.set_parallel(true)
	gt.tween_property(ground, "scale", Vector3(max_radius, 1, max_radius), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	gt.tween_property(ground_mat, "albedo_color", Color(0.1, 0.05, 0.01, 0), 0.5).set_delay(0.2)

	for i in 35:
		var debris_mat := StandardMaterial3D.new()
		debris_mat.albedo_color = Color(
			randf_range(0.8, 1.0),
			randf_range(0.2, 0.5),
			randf_range(0.0, 0.05)
		)
		debris_mat.emission_enabled = true
		debris_mat.emission = debris_mat.albedo_color
		debris_mat.emission_energy_multiplier = randf_range(1.0, 4.0)

		var debris_mesh := SphereMesh.new()
		var r := randf_range(0.04, 0.12)
		debris_mesh.radius = r
		debris_mesh.height = r * 2
		debris_mesh.surface_set_material(0, debris_mat)
		var debris := MeshInstance3D.new()
		debris.mesh = debris_mesh
		root.add_child(debris)

		var dir := Vector3(
			randf_range(-1, 1),
			randf_range(-0.3, 1.0),
			randf_range(-1, 1)
		).normalized()
		var start_dist := randf_range(0.2, 0.8)
		debris.position = dir * start_dist
		var target_dist := max_radius * randf_range(0.5, 1.0)
		var duration := randf_range(0.3, 0.6)
		var rot_speed := randf_range(-10.0, 10.0)

		var dt := root.create_tween()
		dt.set_parallel(true)
		dt.tween_property(debris, "position", dir * target_dist, duration).set_trans(Tween.TRANS_SINE)
		dt.tween_property(debris, "rotation:y", rot_speed, duration).as_relative()
		dt.tween_property(debris_mat, "emission_energy_multiplier", 0.0, duration * 0.5)
		dt.tween_property(debris_mat, "albedo_color", Color(0.3, 0.1, 0.0, 0), duration).set_delay(duration * 0.3)
		dt.tween_property(debris, "scale", Vector3.ZERO, 0.15).set_delay(duration * 0.5)
		dt.tween_callback(debris.queue_free).set_delay(duration + 0.1)

	for i in 25:
		var spark_mat := StandardMaterial3D.new()
		spark_mat.albedo_color = Color(1.0, 0.9, 0.3)
		spark_mat.emission_enabled = true
		spark_mat.emission = Color(1.0, 0.9, 0.3)
		spark_mat.emission_energy_multiplier = 10.0

		var spark_mesh := SphereMesh.new()
		spark_mesh.radius = 0.025
		spark_mesh.height = 0.05
		spark_mesh.surface_set_material(0, spark_mat)
		var spark := MeshInstance3D.new()
		spark.mesh = spark_mesh
		root.add_child(spark)

		var dir := Vector3(randf_range(-1, 1), randf_range(-0.5, 1), randf_range(-1, 1)).normalized()
		spark.position = dir * randf_range(0.1, 0.5)

		var st := root.create_tween()
		st.set_parallel(true)
		st.tween_property(spark, "position", dir * max_radius * randf_range(0.8, 1.2), randf_range(0.15, 0.35)).set_trans(Tween.TRANS_QUAD)
		st.tween_property(spark_mat, "emission_energy_multiplier", 0.0, 0.15)
		st.tween_property(spark, "scale", Vector3.ZERO, 0.08).set_delay(randf_range(0.08, 0.25))
		st.tween_callback(spark.queue_free).set_delay(0.45)

	for i in 22:
		var smoke_mat := StandardMaterial3D.new()
		var gray := randf_range(0.25, 0.45)
		smoke_mat.albedo_color = Color(gray, gray, gray, 0.35)
		smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

		var smoke_mesh := SphereMesh.new()
		var r := randf_range(0.2, 0.4)
		smoke_mesh.radius = r
		smoke_mesh.height = r * 2
		smoke_mesh.surface_set_material(0, smoke_mat)
		var smoke := MeshInstance3D.new()
		smoke.mesh = smoke_mesh
		root.add_child(smoke)

		var dir := Vector3(
			randf_range(-1, 1),
			randf_range(0.3, 1.5),
			randf_range(-1, 1)
		).normalized()
		smoke.position = dir * randf_range(0.3, 1.0)

		var st := root.create_tween()
		st.set_parallel(true)
		st.tween_property(smoke, "position", dir * max_radius * randf_range(0.3, 0.7) + Vector3(0, randf_range(0.5, 2.5), 0), randf_range(0.8, 1.5)).set_trans(Tween.TRANS_SINE)
		st.tween_property(smoke_mat, "albedo_color", Color(gray, gray, gray, 0), randf_range(0.2, 0.4)).set_delay(randf_range(0.0, 0.15))
		st.tween_property(smoke, "scale", Vector3(randf_range(3.0, 5.0), randf_range(3.0, 5.0), randf_range(3.0, 5.0)), randf_range(0.8, 1.2))
		st.tween_callback(smoke.queue_free).set_delay(2.0)

	var fade_out := root.create_tween()
	fade_out.tween_property(root, "scale", Vector3.ZERO, 0.7).set_delay(growth_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var clear_timer := Timer.new()
	clear_timer.one_shot = true
	clear_timer.timeout.connect(root.queue_free)
	root.add_child(clear_timer)
	clear_timer.start(3.0)


func _safe_cleanup() -> void:
	if is_inside_tree():
		queue_free()
