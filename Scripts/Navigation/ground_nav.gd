extends NavigationRegion3D

@export var obstacle_group: String = "nav_obstacle"


func _ready() -> void:
	var src := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(14, 0.1, 14)
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

	for obs in get_tree().get_nodes_in_group(obstacle_group):
		if obs is StaticBody3D or obs is MeshInstance3D:
			NavigationServer3D.parse_source_geometry_data(nav_mesh, source_geo, obs)

	NavigationServer3D.bake_from_source_geometry_data(nav_mesh, source_geo)
	navigation_mesh = nav_mesh

	remove_child(src)
	src.queue_free()

	print("ground_nav: polygons=%d vertices=%d" % [nav_mesh.get_polygon_count(), nav_mesh.vertices.size()])
