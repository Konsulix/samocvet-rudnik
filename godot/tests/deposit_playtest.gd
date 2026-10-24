extends Node
## Render the real level with 0..4 contacts: -- touches=4 [safe] shot=user://deposits.png

func _ready() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var level := Level.new()
	add_child(level)
	await level.start(22)
	var m := level.model
	for i in clampi(int(args.get("touches", "0")), 0, 4):
		var events := []
		for geo in m.geos:
			events.append({r = geo.r, c = geo.c, t = 0.0, kind = "fx"})
		if not m.find.is_empty():
			events.append({r = m.find.r, c = m.find.c, t = 0.0, kind = "adj" if args.has("safe") else "fx"})
		m.run_blast(events)
		for event in m.fx:
			if event.type in ["geo_hit", "find_hit"]:
				level._fx_one(event, {})
		m.fx.clear()
		await get_tree().create_timer(0.35).timeout
	m.collapse()
	level.board.rebuild(m)
	level._render_hud()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	if args.has("shot"):
		get_viewport().get_texture().get_image().save_png(args.shot)
		get_tree().quit()
