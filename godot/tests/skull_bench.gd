extends Node3D
## Skull cost on this GPU: each skull alone in a studio, spinning, full frame; prints GPU ms, triangles, draw calls.
## -- seeds=501,508 skins=bone,gold sid=amethyst frames=40 slow (old shader, no batching)
## -- rand=N area=A: N finds as the admin makes them (Stones.roll, kind skull)

var args := {}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("slow"): SpecUtil.fast = false
	if args.has("crumb"): SpecSkull.CRUMB_DETAIL = int(args.crumb)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 4.2)
	cam.fov = 40
	add_child(cam)
	var l := DirectionalLight3D.new()
	l.rotation = Vector3(-0.7, 0.5, 0)
	l.shadow_enabled = true
	add_child(l)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.4, 0.4, 0.45)
	add_child(env)
	var list := []
	if args.has("rand"):
		var r := Rng32.new(int(args.get("base", "7")))
		for k in int(args.rand):
			var sd := 1 + int(r.next() * 999999)
			var st := Stones.roll(sd, int(args.get("area", "0")), 1.5, 3)
			var sids := ["amethyst", "venom", "morion", "cinnabar", "celestine", "smoky", "quartz", "fluorite"]
			if st.kind in ["nugget", "fossil"]: st.sid = sids[k % sids.size()]
			st.kind = "druse"
			st.form = "skull"
			list.append(Spec.of_stone(st))
	else:
		for sd in String(args.get("seeds", "501,508,515,522,529,536,543,550")).split(","):
			for sk in String(args.get("skins", "bone")).split(","):
				var o := {seed = int(sd), sid = args.get("sid", "amethyst"), kind = "druse", gi = 2, traits = [], form = "skull", skin = sk}
				# beasts=all | wolf,deer: an animal's skull each (SpecSkull.BEASTS in turn)
				if args.has("beasts"):
					var bl: Array = SpecSkull.BEASTS if args.beasts == "all" else Array(String(args.beasts).split(","))
					o.beast = bl[list.size() % bl.size()]
				list.append(o)
	var n := int(args.get("frames", "40"))
	for o: Dictionary in list:
		var t0 := Time.get_ticks_msec()
		var p: Node3D = SpecStudio.seat(SpecimenBuilder.build(o))
		var bt := Time.get_ticks_msec() - t0
		add_child(p)
		for k in 8: await get_tree().process_frame
		var gpu := 0.0
		var tris := 0
		var calls := 0
		for k in n:
			p.rotation.y += 0.05
			await RenderingServer.frame_post_draw
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
			tris = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
			calls = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var sk: Dictionary = SpecSkull.genes(int(o.seed), {})
		print("BENCH %s %s#%s skin=%s gpu %.2f ms  tris %dk  calls %d  build %d ms  | crown=%s trees=%s moss=%s flies=%s stream=%s roots=%s" % [o.get("beast", "human"), o.sid, o.seed, o.get("skin", sk.get("skin")), gpu / n, tris / 1000, calls, bt, sk.get("crown"), sk.get("trees"), sk.get("moss"), sk.get("flies"), sk.get("stream"), sk.get("roots")])
		remove_child(p)
		p.free()
	get_tree().quit()
