extends Node
## Looks for pictures the interface stretches or blows up: runs the game (the usual keys: screen=, ui=, level=…),
## waits `audit_after` seconds, then walks every Control and prints the suspicious ones:
##   kit frames whose middle is stretched over STRETCH times (or squashed), textures drawn bigger than they are
##   on a 3x phone (UPSCALE), and textures drawn out of their own proportions (ASPECT).
## Run: "$G" --path godot --resolution 390x844 res://tests/ui_audit.tscn -- screen=home ui=on_play ui_after=1.5 audit_after=3

const PHONE := 3.0         # device pixels per point on an iPhone
const STRETCH := 2.2
const UPSCALE := 1.35
const ASPECT := 0.12

var _seen := {}

func _ready() -> void:
	add_child(load("res://scenes/main.tscn").instantiate())
	var after := 3.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("audit_after="): after = float(a.get_slice("=", 1))
	await get_tree().create_timer(after).timeout
	print("--- ui audit ---")
	_walk(get_tree().root)
	print("--- end ---")
	get_tree().quit()

func _walk(n: Node) -> void:
	if n is Control and (n as Control).is_visible_in_tree():
		_check(n as Control)
	for c in n.get_children():
		_walk(c)

func _where(c: Control) -> String:
	var bits: Array[String] = []
	var n: Node = c
	for i in 4:
		if n == null: break
		bits.push_front(String(n.name))
		n = n.get_parent()
	return "/".join(bits) + " %dx%d pt" % [int(c.size.x), int(c.size.y)]

func _report(c: Control, what: String) -> void:
	var key := what.get_slice(":", 0) + "|" + _where(c)
	if _seen.has(key): return
	_seen[key] = true
	print("  ", what, "   @ ", _where(c))

func _check(c: Control) -> void:
	for st in ["panel", "normal"]:
		if c.has_theme_stylebox_override(st):
			var sb := c.get_theme_stylebox(st)
			if sb is KitBox: _kit(c, sb as KitBox)
	if c is TextureRect:
		var t := c as TextureRect
		if t.texture == null or t.size.x < 2 or t.size.y < 2: return
		var ts := t.texture.get_size()
		var name := t.texture.resource_path.get_file() if t.texture.resource_path != "" else t.texture.get_class()
		var fx := t.size.x * PHONE / ts.x
		var fy := t.size.y * PHONE / ts.y
		var keep := t.stretch_mode in [TextureRect.STRETCH_KEEP_ASPECT, TextureRect.STRETCH_KEEP_ASPECT_CENTERED, TextureRect.STRETCH_KEEP_ASPECT_COVERED]
		var f := minf(fx, fy) if keep else maxf(fx, fy)
		if t.texture is GradientTexture2D: return
		if t.texture is ViewportTexture: return    # 3D views render at the screen's own pixels (SpecView)
		if f > UPSCALE: _report(c, "UPSCALE x%.1f: %s (%dx%d px)" % [f, name, int(ts.x), int(ts.y)])
		if not keep and t.stretch_mode == TextureRect.STRETCH_SCALE and absf(fx / fy - 1.0) > ASPECT:
			_report(c, "ASPECT %.2f: %s" % [fx / fy, name])

func _kit(c: Control, b: KitBox) -> void:
	if b.tex == null: return
	var ts := b.tex.get_size()
	var name := b.tex.resource_path.get_file()
	var k := b.s
	if (b.fit_h or b.pin > 0.0) and c.size.y * b.s < ts.y: k = ts.y / c.size.y
	var mid_t := ts - Vector2(b.margin.x + b.margin.z, b.margin.y + b.margin.w)
	var mid_d := c.size * k - Vector2(b.margin.x + b.margin.z, b.margin.y + b.margin.w)
	if mid_d.x < 0 or mid_d.y < 0:
		_report(c, "SQUASHED corners: %s" % name)
		return
	if b.fill: return     # hollow frame over a tiled fill: only its thin rims stretch
	var sx := mid_d.x / maxf(1.0, mid_t.x)
	var sy := mid_d.y / maxf(1.0, mid_t.y)
	if b.fit_h or (b.pin > 0.0 and c.size.y * b.s >= ts.y): sy = 1.0
	if b.tile_x or b.tile: sx = 1.0     # repeated, not stretched
	if b.tile_y or b.tile: sy = 1.0
	if maxf(sx, sy) > STRETCH: _report(c, "STRETCH x%.1f/%.1f: %s" % [sx, sy, name])
