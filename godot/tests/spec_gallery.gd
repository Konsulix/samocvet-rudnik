extends Control
## A wall of specimens for eyeballing the 3D port:  -- set=0 shot=user://g.png after=4
## set 0: crystals and druses, 1: geodes, nuggets, botryoids, 2: cut stones, jewellery, machines

const SETS := [
	[{seed = 11, sid = "quartz", kind = "crystal", gi = 2, traits = []}, {seed = 12, sid = "amethyst", kind = "druse", gi = 3, traits = []},
	{seed = 13, sid = "fluorite", kind = "druse", gi = 2, traits = ["irid"]}, {seed = 14, sid = "garnet", kind = "crystal", gi = 2, traits = []},
	{seed = 15, sid = "emerald", kind = "crystal", gi = 3, traits = ["rutile"]}, {seed = 16, sid = "gypsum", kind = "crystal", gi = 1, traits = []},
	{seed = 17, sid = "ruby", kind = "druse", gi = 2, traits = ["moss"]}, {seed = 18, sid = "aquamarine", kind = "crystal", gi = 4, traits = ["floater"]},
	{seed = 19, sid = "calcite", kind = "druse", gi = 1, traits = ["coral"]}, {seed = 20, sid = "pyrite", kind = "druse", gi = 2, traits = []},
	{seed = 21, sid = "diamond", kind = "crystal", gi = 4, traits = ["aurora"], legend = true}, {seed = 22, sid = "celestine", kind = "druse", gi = 2, traits = ["bubbles", "druzy"]}],
	[{seed = 31, sid = "amethyst", kind = "geode", gi = 3, traits = []}, {seed = 32, sid = "quartz", kind = "geode", gi = 2, traits = []},
	{seed = 33, sid = "gold", kind = "nugget", gi = 2, traits = []}, {seed = 34, sid = "nativecu", kind = "nugget", gi = 2, traits = []},
	{seed = 35, sid = "malachite", kind = "crystal", gi = 2, traits = []}, {seed = 36, sid = "opal", kind = "crystal", gi = 3, traits = []},
	{seed = 37, sid = "azurite", kind = "druse", gi = 2, traits = []}, {seed = 38, sid = "gold", kind = "nugget", gi = 3, traits = []},
	{seed = 39, sid = "fluorite", kind = "geode", gi = 2, traits = []}, {seed = 40, sid = "chrysocolla", kind = "crystal", gi = 2, traits = []},
	{seed = 41, sid = "sapphire", kind = "crystal", gi = 3, traits = ["phantom", "zoned"]}, {seed = 42, sid = "halite", kind = "crystal", gi = 2, traits = []}],
	[{seed = 51, sid = "ruby", cut = "cab"}, {seed = 52, sid = "emerald", cut = "facet"}, {seed = 53, sid = "sapphire", cut = "master"},
	{seed = 54, jewel = {rid = "ring", cols = ["#d0342c"]}}, {seed = 55, jewel = {rid = "ear", cols = ["#2e8b57", "#2e8b57"]}},
	{seed = 56, jewel = {rid = "pend", cols = ["#3a5fcd", "#ffffff"]}}, {seed = 57, jewel = {rid = "brooch", cols = ["#9b30ff", "#ffd700", "#40e0d0"]}},
	{seed = 58, jewel = {rid = "diadem", cols = ["#ff1744", "#2979ff", "#00e676", "#ffffff"]}}, {seed = 59, jewel = {rid = "crown", cols = ["#e0115f", "#0f52ba", "#50c878", "#e8f4ff", "#ffd700"]}},
	{machine = "hammer"}, {machine = "tbm"}, {machine = "crush"}],
	[{seed = 61, sid = "quartz", kind = "druse", gi = 2, traits = ["moss"]}, {seed = 62, sid = "amethyst", kind = "crystal", gi = 3, traits = ["moss"]},
	{seed = 63, sid = "fluorite", kind = "crystal", gi = 2, traits = []}, {seed = 64, sid = "aquamarine", kind = "druse", gi = 3, traits = ["coral"]}],
	[{machine = "rig"}, {machine = "deep"}, {machine = "lift"}, {machine = "food"}, {machine = "vent"}, {machine = "crush"}],
]

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var list: Array = SETS[int(args.get("set", "0"))]
	var cols := int(args.get("cols", "4"))
	var px := int(args.get("px", "280"))
	var t0 := Time.get_ticks_msec()
	for i in list.size():
		var v := SpecView.new(px)
		v.position = Vector2((i % cols) * px, (i / cols) * px)
		v.size = Vector2(px, px)
		v.still = args.has("still")
		add_child(v)
		var t1 := Time.get_ticks_msec()
		v.show_spec(list[i])
		var bx := SpecUtil.box_of(v.live.get_child(0))
		print("  box ", (v.live.get_child(0) as Node3D).transform * bx)
		print("built ", list[i].get("sid", list[i].get("machine", "jewel")), " in ", Time.get_ticks_msec() - t1, " ms")
	print("total ", Time.get_ticks_msec() - t0, " ms")
	if args.has("shot"):
		await get_tree().create_timer(float(args.get("after", "3"))).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args.shot)
		print("shot saved")
		get_tree().quit()
