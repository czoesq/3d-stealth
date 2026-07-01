extends StaticBody3D


func break_apart() -> void:
	var origin := global_position
	var mats := [
		Color(0.75, 0.45, 0.12),
		Color(0.65, 0.4, 0.1),
		Color(0.55, 0.35, 0.08),
	]
	for i in 8:
		var p := RigidBody3D.new()
		p.collision_layer = 2
		p.collision_mask = 1
		var size := Vector3(randf_range(0.15, 0.35), randf_range(0.15, 0.35), randf_range(0.15, 0.35))
		var mi := MeshInstance3D.new()
		mi.mesh = BoxMesh.new()
		mi.mesh.size = size
		var mat := StandardMaterial3D.new()
		mat.albedo_color = mats[randi() % mats.size()]
		mi.mesh.surface_set_material(0, mat)
		p.add_child(mi)
		var cs := CollisionShape3D.new()
		cs.shape = BoxShape3D.new()
		cs.shape.size = size
		p.add_child(cs)
		get_parent().add_child(p)
		p.global_position = origin + Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
		p.apply_central_impulse(Vector3(randf_range(-4.0, 4.0), randf_range(1.0, 5.0), randf_range(-4.0, 4.0)))
	queue_free()
