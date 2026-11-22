extends SceneTree
## the glow quad of a glowing mushroom (fungi_halo.gdshader) on a see-through picture, as the inventory's tiles are
## drawn: the picture's alpha at the quad's corner (must stay 0) and middle. `godot --path godot -s res://tests/halo_alpha.gd`
func _init() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(64, 64)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 2)
	vp.add_child(cam)
	var q := MeshInstance3D.new()
	q.mesh = QuadMesh.new()
	(q.mesh as QuadMesh).size = Vector2(1.6, 1.6)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/fungi_halo.gdshader")
	q.material_override = m
	vp.add_child(q)
	for i in 8: await process_frame
	var im := vp.get_texture().get_image()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("save="): im.save_png(a.substr(5))     # (save=user://x.png: the picture itself)
	print("HALO near its corner ", im.get_pixel(18, 18), " edge ", im.get_pixel(18, 32), " middle ", im.get_pixel(32, 32))
	quit()
