extends SceneTree
## Prints the snout's tip of every swimmer's model (SpecReef.MODELS, group "swim"): the middle of the vertices
## furthest forward (+x) — what a ram at the card's glass aims with (`nose` in the model's anim).
##   godot --headless --path godot -s res://tests/swim_nose.gd

func _init() -> void:
	for id: String in SpecReef.group("swim"):
		var m := SpecReef.mesh(id)
		var top := -INF
		var all: Array = []
		for si in m.get_surface_count():
			var vs: PackedVector3Array = m.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
			for v in vs:
				all.append(v)
				top = maxf(top, v.x)
		var sum := Vector3.ZERO
		var cnt := 0
		for v: Vector3 in all:
			if v.x > top - 0.012:
				sum += v
				cnt += 1
		var bx := m.get_aabb()
		for x0: float in [0.4, 0.3, 0.2, 0.1]:
			var ms := Vector3.ZERO
			var mc := 0
			for v: Vector3 in all:
				if absf(v.x - x0) < 0.02:
					ms += v
					mc += 1
			print(id, " mid at ", x0, " z ", snappedf(ms.z / maxf(1.0, mc), 0.001), " y ", snappedf(ms.y / maxf(1.0, mc), 0.001))
		print(id, " nose ", sum / maxf(1.0, cnt), " of ", cnt, " box ", bx.position, " .. ", bx.end)
	quit()
