extends Node
## The app: switches between screens (home, level, depot, museum) and owns the HDR glow pass.
## Command-line extras after `--` for testing:  level=5  depth=2  shot=user://shot.png  after=3.5  autoplay=6

var screen: Node
var args := {}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if not args.has("noglow"): _setup_glow()
	if args.has("level"):
		show_level(int(args.level), [], int(args.get("depth", "0")))
	else:
		show_home()
	if args.has("shot"):
		_take_shot()

func _setup_glow() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 0.97
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(4, 0.3)
	we.environment = env
	add_child(we)

func _swap(n: Node) -> void:
	if screen: screen.queue_free()
	screen = n
	add_child(n)

func show_home() -> void:
	# the home screen is ported next; until then the first unbeaten level opens straight away
	show_level(Save.d.level, [], 0)

func show_level(n: int, pre: Array, dl: int) -> void:
	var lv := Level.new()
	_swap(lv)
	lv.finished.connect(_on_level_finished)
	lv.start(n, pre, dl)
	if args.has("autoplay"):
		_autoplay(lv, int(args.autoplay))

func _on_level_finished(res: Dictionary) -> void:
	show_home()

## plays a few moves by itself, for screenshots of a level in motion
func _autoplay(lv: Level, turns: int) -> void:
	await get_tree().create_timer(1.2).timeout
	for i in turns:
		while lv.busy: await get_tree().create_timer(0.1).timeout
		var mv := lv.model.find_move()
		if mv.is_empty(): return
		if mv[0] == mv[2] and mv[1] == mv[3]: lv._on_tap(mv[0], mv[1])
		else: lv._on_swipe(mv[0], mv[1], mv[2], mv[3])
		await get_tree().create_timer(0.3).timeout

func _take_shot() -> void:
	await get_tree().create_timer(float(args.get("after", "3"))).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(args.shot)
	print("shot saved: ", ProjectSettings.globalize_path(args.shot))
	get_tree().quit()
