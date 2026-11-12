extends Node
## Video memory as the player walks through the mines (the Mines tab): each mine's screen is opened in turn, then the
## first again; a mine left behind must give its pictures back. Run:
## "$G" --path godot --resolution 390x844 res://tests/mine_mem.tscn -- save=minemem mines=0,1,2,3,0

func _ready() -> void:
	add_child(load("res://scenes/main.tscn").instantiate())
	var list := [0, 1, 2, 3, 0]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("mines="): list = Array(a.get_slice("=", 1).split(",")).map(func(x): return int(x))
	await get_tree().create_timer(4.0).timeout
	var m: Node = get_tree().current_scene
	for c in get_children(): if c.has_method("_go_mine"): m = c
	for area in list:
		Save.d.reached = maxi(int(Save.d.get("reached", 0)), int(area))
		m.call("_go_mine", int(area))
		await get_tree().create_timer(5.0).timeout
		print("MEM mine %d  vram %4d MB  tex %4d MB  mine pictures %d" % [area,
			roundi(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0),
			roundi(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0), MineView._tex.size()])
	get_tree().quit()
