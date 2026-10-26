class_name Boot
extends Control
## The loading screen at launch: the game's name, a live legendary specimen (a ruby with lava creeping
## through its rock and dripping off it) floating over its own glow, and a bar.
## Behind it the specimen shaders compile (Spec) and everything the first screens need loads on
## background threads: board sprites, the level backdrop, music and sounds. What was loaded is kept
## (cache), so entering a level never reads from the disk mid-frame. Emits done when it has faded out.

signal done

const MIN_TIME := 1.3
## loaded on background threads while the bar fills, and kept in memory for the whole session
const EXTRA := ["res://assets/ui/level_bg.png", "res://assets/audio/music/home_adit.ogg", "res://assets/audio/music/home_copper.ogg", "res://assets/audio/music/home.ogg", "res://assets/audio/music/level1.ogg",
	"res://assets/audio/music/level2.ogg"]

static var cache := []
## the stone on show is a pre-rendered turn (main.gd bake_boot), not a live 3D view: a live one needs
## its shaders compiled at the very moment the loading screen should be moving
const SHEET := "res://assets/ui/boot_stone.png"
const CELL := 256
const FRAMES := 48
const FPS := 16.0
## the stone on show; boot_seed=N picks another for screenshots
static var seed_v := 88
const STONE := {sid = "ruby", kind = "crystal", gi = 3, traits = [], legend = true, fx = "lava"}

var _paths := []
var _t := 0.0
var _shown := 0.0
var _gem: TextureRect
var _frame: AtlasTexture
var _halo: Control
var _bar_fill: Panel
var _bar_w := 220.0
var _leaving := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("#0d121b")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_halo = Control.new()
	_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_halo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_halo.draw.connect(_draw_halo)
	add_child(_halo)
	_frame = AtlasTexture.new()
	_frame.atlas = load(SHEET)
	_frame.region = Rect2(0, 0, CELL, CELL)
	_gem = TextureRect.new()
	_gem.texture = _frame
	_gem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_gem.size = Vector2(250, 250)
	_gem.pivot_offset = _gem.size / 2
	_gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_gem)
	var title := UI.label("GEMCORE", 34, UI.display, Color("#f3e3bd"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 0)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.name = "Title"
	add_child(title)
	# on the first launch after an install the phone prepares its graphics once; say so if it takes a while
	var note := UI.label("Preparing graphics for your device — only this once", 12, UI.body, Color("#8a93a6"))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.name = "Note"
	note.modulate.a = 0.0
	add_child(note)
	var bar := Panel.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(1, 1, 1, 0.08)
	bs.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("panel", bs)
	bar.name = "Bar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	_bar_fill = Panel.new()
	var fs := StyleBoxFlat.new()
	fs.bg_color = UI.GOLD
	fs.set_corner_radius_all(5)
	_bar_fill.add_theme_stylebox_override("panel", fs)
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_bar_fill)
	_paths = BoardSprites.paths() + BoardKit.paths() + EXTRA
	for f in ResourceLoader.list_directory("res://assets/thumbs/"):
		if f.ends_with(".png"): _paths.append("res://assets/thumbs/" + f)
	for p in _paths:
		ResourceLoader.load_threaded_request(p)
	# on its own canvas layer there is no parent to fill: take the screen's size
	size = get_viewport_rect().size
	get_viewport().size_changed.connect(func(): size = get_viewport_rect().size)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	var c := size / 2
	_gem.position = c - _gem.size / 2 + Vector2(0, -50)
	var title: Label = get_node("Title")
	title.position = Vector2(0, c.y + 110)
	title.size.x = size.x
	var bar: Panel = get_node("Bar")
	bar.size = Vector2(_bar_w, 10)
	bar.position = Vector2(c.x - _bar_w / 2, c.y + 170)
	var note: Label = get_node("Note")
	note.position = Vector2(0, c.y + 192)
	note.size.x = size.x

func _loaded_fraction() -> float:
	var sum := 0.0
	for p in _paths:
		var prog := []
		var st := ResourceLoader.load_threaded_get_status(p, prog)
		if st == ResourceLoader.THREAD_LOAD_LOADED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE or st == ResourceLoader.THREAD_LOAD_FAILED:
			sum += 1.0
		elif prog.size():
			sum += float(prog[0])
	return sum / maxf(1.0, _paths.size())

func _process(dt: float) -> void:
	_t += dt
	# the gem floats, rocks gently and breathes; its glow swells as it rises
	var lift := sin(_t * 2.2)
	_gem.position.y = size.y / 2 - _gem.size.y / 2 - 50 - lift * 12.0
	_gem.scale = Vector2.ONE * (1.0 + 0.02 * sin(_t * 2.2 + 0.6))
	var f := int(_t * FPS) % FRAMES
	_frame.region = Rect2((f % 8) * CELL, (f / 8) * CELL, CELL, CELL)
	_halo.queue_redraw()
	if _leaving:
		return
	if _t > 2.5 and not Spec.warm_done:
		var note: Label = get_node("Note")
		note.modulate.a = minf(1.0, note.modulate.a + dt * 2.0)
	var want := 0.55 * Spec.warm_progress + 0.45 * _loaded_fraction()
	_shown = move_toward(_shown, want, dt * 1.6)
	_bar_fill.size = Vector2(maxf(10.0, _bar_w * _shown), 10)
	if Spec.warm_done and want >= 0.999 and _shown >= 0.999 and _t >= MIN_TIME and not has_meta("hold"):
		_finish()

func _draw_halo() -> void:
	var c := size / 2 + Vector2(0, -40 - sin(_t * 2.2) * 12.0)
	var k := 0.5 + 0.5 * sin(_t * 2.2)
	var col := Color(1.0, 0.42, 0.12)
	GemArt.radial_disc(_halo, c + Vector2(0, -10), 150 + 14 * k, Color(col, 0.3 + 0.1 * k), Color(col, 0.1), Color(col, 0.0))
	# its shadow on the ground below: smaller and fainter the higher it floats
	var g := size / 2 + Vector2(0, 92)
	var sw := 46.0 - 8.0 * k
	_halo.draw_set_transform(g, 0, Vector2(1.0, 0.22))
	GemArt.radial_disc(_halo, Vector2.ZERO, sw, Color(0, 0, 0, 0.55 - 0.2 * k), Color(0, 0, 0, 0.25), Color(0, 0, 0, 0))
	_halo.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _finish() -> void:
	_leaving = true
	for p in _paths:
		if ResourceLoader.load_threaded_get_status(p) == ResourceLoader.THREAD_LOAD_LOADED:
			cache.append(ResourceLoader.load_threaded_get(p))
	done.emit()
	# let the first screen build behind us before fading, so its first frames are not seen
	for i in 3:
		await get_tree().process_frame
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)
