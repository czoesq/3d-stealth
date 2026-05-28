extends NavigationRegion3D

func _ready() -> void:
	var nav_mesh := NavigationMesh.new()
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 2.0

	var source_geo := NavigationMeshSourceGeometryData3D.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-10, 0, -10),
		Vector3(10, 0, -10),
		Vector3(-10, 0, 10),
		Vector3(10, 0, 10),
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 3, 0, 3, 1])
	source_geo.create_from_mesh_arrays(arrays)

	NavigationServer3D.bake_from_source_geometry_data(nav_mesh, source_geo)
	navigation_mesh = nav_mesh
