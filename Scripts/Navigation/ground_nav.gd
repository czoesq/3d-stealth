extends NavigationRegion3D

@export var debug_show_navmesh: bool = true
@export var debug_navmesh_color: Color = Color(0.0, 1.0, 0.0, 0.25)


func _ready() -> void:
	var nav_mesh := NavigationMesh.new()
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS

	var source_geo := NavigationMeshSourceGeometryData3D.new()
	var root := get_tree().current_scene
	NavigationServer3D.parse_source_geometry_data(nav_mesh, source_geo, root)
	NavigationServer3D.bake_from_source_geometry_data(nav_mesh, source_geo)
	navigation_mesh = nav_mesh

	if debug_show_navmesh and nav_mesh.get_polygon_count() > 0:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var verts := nav_mesh.vertices
		for i in nav_mesh.get_polygon_count():
			var poly := nav_mesh.get_polygon(i)
			for j in range(1, poly.size() - 1):
				st.add_vertex(verts[poly[0]])
				st.add_vertex(verts[poly[j]])
				st.add_vertex(verts[poly[j + 1]])
		st.generate_normals()
		var debug_mesh := st.commit()
		var mat := StandardMaterial3D.new()
		mat.albedo_color = debug_navmesh_color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var mi := MeshInstance3D.new()
		mi.mesh = debug_mesh
		mi.material_override = mat
		add_child(mi)

	print("ground_nav: polygons=%d vertices=%d" % [nav_mesh.get_polygon_count(), nav_mesh.vertices.size()])
