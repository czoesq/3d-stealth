extends NavigationRegion3D

func _ready() -> void:
	_setup_nav.call_deferred()


func _setup_nav() -> void:
	var nav_mesh := NavigationMesh.new()
	nav_mesh.vertices = PackedVector3Array([
		Vector3(-10, 0, -10),
		Vector3(10, 0, -10),
		Vector3(-10, 0, 10),
		Vector3(10, 0, 10),
	])
	nav_mesh.polygons = [
		PackedInt32Array([0, 2, 3]),
		PackedInt32Array([0, 3, 1]),
	]
	navigation_mesh = nav_mesh
