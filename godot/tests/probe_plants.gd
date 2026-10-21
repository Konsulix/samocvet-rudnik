extends Node
func _ready() -> void:
	for a in ["moss_01", "fern_02", "grass_medium_02", "grass_bermuda_01"]:
		var sc: PackedScene = load("res://assets/plants/%s/%s.gltf" % [a, a])
		var n := sc.instantiate()
		for m in n.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			print(a, " ", mi.name, " aabb ", mi.mesh.get_aabb(), " xf ", mi.transform.origin, " basis ", mi.transform.basis.get_euler())
		n.free()
	get_tree().quit()
