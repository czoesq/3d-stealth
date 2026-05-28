extends NavigationRegion3D

func _ready() -> void:
	var src := MeshInstance3D.new()
	src.mesh = PlaneMesh.new()
	src.mesh.size = Vector2(20, 20)
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
