extends NavigationRegion3D

func _ready() -> void:
	var src := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 0.1, 20)
	col.shape = box
	src.add_child(col)
	add_child(src)

	var nav_mesh := NavigationMesh.new()
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 2.0

	var source_geo := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav_mesh, source_geo, self)
	NavigationServer3D.bake_from_source_geometry_data(nav_mesh, source_geo)
	navigation_mesh = nav_mesh

	remove_child(src)
	src.queue_free()
