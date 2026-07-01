extends RigidBody3D

var alert_radius: float = 3.0
var _hit: bool = false


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 1
	can_sleep = false

	var mat := PhysicsMaterial.new()
	mat.bounce = 0.0
	mat.friction = 0.0
	physics_material_override = mat
	continuous_cd = true

	var dart := MeshInstance3D.new()
	var dart_mesh := CylinderMesh.new()
	dart_mesh.top_radius = 0.015
	dart_mesh.bottom_radius = 0.025
	dart_mesh.height = 0.16
	var dart_mat := StandardMaterial3D.new()
	dart_mat.albedo_color = Color(0.9, 0.85, 0.7)
	dart_mat.metallic = 0.4
	dart_mat.roughness = 0.3
	dart_mesh.surface_set_material(0, dart_mat)
	dart.mesh = dart_mesh
	dart.rotation.x = PI / 2
	add_child(dart)

	var tip := MeshInstance3D.new()
	var tip_mesh := SphereMesh.new()
	tip_mesh.radius = 0.025
	tip_mesh.height = 0.05
	var tip_mat := StandardMaterial3D.new()
	tip_mat.albedo_color = Color(0.9, 0.7, 0.2)
	tip_mesh.surface_set_material(0, tip_mat)
	tip.mesh = tip_mesh
	tip.position = Vector3(0, 0.09, 0)
	add_child(tip)

	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.15
	cs.shape = sp
	add_child(cs)

	body_entered.connect(_on_body_entered)

	var timer := Timer.new()
	timer.one_shot = true
	timer.timeout.connect(_safe_cleanup)
	add_child(timer)
	timer.start(3.0)


func _on_body_entered(body: Node) -> void:
	if _hit:
		return
	_hit = true

	if body.is_in_group("player"):
		_hit = false
		return

	if body.is_in_group("enemy"):
		if body.has_method("knock_out"):
			body.knock_out()
		_spawn_hit_fx()
		queue_free()
		return

	_spawn_hit_fx()
	_alert_nearby_enemies()
	queue_free()


func _spawn_hit_fx() -> void:
	var fx := Node3D.new()
	fx.name = "TranqHitFX"
	get_parent().add_child(fx)
	fx.global_position = global_position

	var puff_mat := StandardMaterial3D.new()
	puff_mat.albedo_color = Color(0.9, 0.85, 0.7, 0.3)
	puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var puff := MeshInstance3D.new()
	var puff_mesh := SphereMesh.new()
	puff_mesh.radius = 0.1
	puff_mesh.height = 0.2
	puff_mesh.surface_set_material(0, puff_mat)
	puff.mesh = puff_mesh
	fx.add_child(puff)

	var t := fx.create_tween()
	t.set_parallel(true)
	t.tween_property(puff, "scale", Vector3(3, 3, 3), 0.2)
	t.tween_property(puff_mat, "albedo_color", Color(0.9, 0.85, 0.7, 0.0), 0.2)
	t.tween_callback(fx.queue_free).set_delay(0.25)


func _alert_nearby_enemies() -> void:
	var enemies := get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		var dist := global_position.distance_to(e.global_position)
		if dist <= alert_radius:
			if e.has_method("investigate_location"):
				e.investigate_location(global_position)


func _safe_cleanup() -> void:
	if _hit:
		return
	_hit = true
	_alert_nearby_enemies()
	if is_inside_tree():
		queue_free()
