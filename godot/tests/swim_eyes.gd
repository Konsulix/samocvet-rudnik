extends SceneTree
## Finds a swimmer's eyes on its model by their colour in the scan's texture (the head's vertices whose texel is
## strongly red or orange): prints, for each side (z < 0, z > 0), where they lie and how far they spread.
##   godot --headless --path godot -s res://tests/swim_eyes.gd -- swim_styxosaurus [x_from=0.44]

func _init() -> void:
	var id := "swim_styxosaurus"
	var x_from := 0.44
	for a in OS.get_cmdline_user_args():
		if a.begins_with("x_from="): x_from = float(a.get_slice("=", 1))
		elif a.begins_with("swim_"): id = a
	var m := SpecReef.mesh(id)
	var img := (load(SpecReef.DIR + id + "_d.png") as Texture2D).get_image()
	if img.is_compressed(): img.decompress()
	for side: float in [-1.0, 1.0]:
		var sum := Vector3.ZERO
		var cnt := 0
		var lo := Vector3.ONE * 9.0
		var hi := Vector3.ONE * -9.0
		for si in m.get_surface_count():
			var arr := m.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			for i in vs.size():
				var v := vs[i]
				if v.x < x_from or v.z * side <= 0.0: continue
				var c := img.get_pixel(clampi(int(uv[i].x * img.get_width()), 0, img.get_width() - 1), clampi(int(uv[i].y * img.get_height()), 0, img.get_height() - 1))
				if c.s > 0.55 and c.v > 0.35 and (c.h < 0.12 or c.h > 0.95):
					sum += v
					cnt += 1
					lo = lo.min(v)
					hi = hi.max(v)
		print(id, " side ", side, ": ", cnt, " verts, mid ", sum / maxf(1.0, cnt), " from ", lo, " to ", hi)
	quit()
