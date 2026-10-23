extends Node
## Photographs of specimens, jewellery and machines for lists and cards: rendered one at a time
## in an offscreen studio and kept in memory. Ask with thumb(o, callback).

const PX := 256

var studio: SpecStudio
var _cache := {}
var _queue := []
var _busy := false
## the ultraviolet flash, shared by every fluorescent specimen (shader global fluor_uv) and their studios:
## every 7 s the lamps dim for about two and a half seconds
var uv := 0.0
var beat := 0.0
var force_uv := -1.0   # screenshots: uv=0..1 holds the flash still
## the start-up shader warm-up, watched by the loading screen
signal warmed
var warm_done := false
var warm_progress := 0.0

func _process(_dt: float) -> void:
	var ph := fmod(Time.get_ticks_msec() / 1000.0, 7.0) / 7.0
	uv = force_uv if force_uv >= 0.0 else smoothstep(0.55, 0.6, ph) * (1.0 - smoothstep(0.88, 0.95, ph))
	RenderingServer.global_shader_parameter_set("fluor_uv", uv)
	# lub-dub, about 70 beats a minute: a strong beat, a softer echo, then rest
	var hb := fmod(Time.get_ticks_msec() / 1000.0, 0.86) / 0.86
	beat = exp(-pow((hb - 0.12) * 11.0, 2.0)) + 0.55 * exp(-pow((hb - 0.36) * 11.0, 2.0))
	RenderingServer.global_shader_parameter_set("heart_beat", beat)

func _ready() -> void:
	studio = SpecStudio.make(PX, Viewport.MSAA_4X)
	studio.vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(studio.vp)
	_warm()

## compile the specimen shaders right at launch, while the boot splash is still up (the first one takes
## a good fraction of a second): a little ball per variant, drawn once in the offscreen studio,
## so neither the home screen nor the first find stutters
func _warm() -> void:
	while _busy:
		await get_tree().process_frame
	_busy = true
	var balls := Node3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.2
	mesh.height = 0.4
	mesh.radial_segments = 8
	mesh.rings = 4
	studio.stage.add_child(balls)
	# one variant per frame: each compile is a short stall instead of one long freeze;
	# the mushrooms' and the star heart's own shaders too
	var mats: Array[Material] = []
	mats.append_array(SpecMat.warm_materials())
	mats.append(SpecFungi.material(0))
	mats.append(SpecLegend.heart_mat(Color.WHITE, 2.0, 0.5))
	mats.append(SpecLegend.glow_mat(Color.WHITE))
	var done := 0
	for m in mats:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = m
		balls.add_child(mi)
		studio.vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		mi.visible = false
		done += 1
		warm_progress = done / float(mats.size())
	balls.queue_free()
	BoardSprites.preload_all()
	warm_done = true
	warmed.emit()
	_busy = false
	if _queue.size():
		_pump()

static func key_of(o: Dictionary) -> String:
	var j: Dictionary = o.get("jewel", {})
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s" % [o.get("seed", 0), o.get("sid", ""), o.get("kind", ""), o.get("gi", ""), ".".join(o.get("traits", [])),
		o.get("cut", ""), int(o.get("legend", false)), str(j.get("rid", "")) + "".join(j.get("cols", [])), o.get("machine", "")]

## the description of a stone from the save, as the builder wants it
static func of_stone(s: Dictionary) -> Dictionary:
	var o := {seed = s.id, sid = s.sid, kind = s.get("kind", "crystal"), gi = s.gi, traits = s.get("traits", []), legend = s.get("legend", false), cut = s.get("cut", "")}
	if s.has("fx"): o.fx = s.fx
	if s.has("shroom"): o.shroom = s.shroom
	return o

static func of_jewel(j: Dictionary) -> Dictionary:
	return {seed = j.id, jewel = {rid = j.rid, cols = j.cols}}

func cached(o: Dictionary) -> Texture2D:
	return _cache.get(key_of(o))

## machines never change: their pictures are baked into the project (bake_thumbs key), not rendered on the phone
const BAKED := "res://assets/thumbs/machine_%s.png"

func thumb(o: Dictionary, cb: Callable) -> void:
	var t := cached(o)
	if t:
		cb.call(t)
		return
	if o.has("machine") and not o.has("bake") and ResourceLoader.exists(BAKED % o.machine):
		var bt: Texture2D = load(BAKED % o.machine)
		_cache[key_of(o)] = bt
		cb.call(bt)
		return
	_queue.append([o, cb])
	if not _busy:
		_pump()

func _pump() -> void:
	_busy = true
	while _queue.size():
		var item: Array = _queue.pop_front()
		var o: Dictionary = item[0]
		var cb: Callable = item[1]
		var key := key_of(o)
		if not _cache.has(key):
			var p: Node3D = await studio.show_async(o)
			p.rotation = Vector3(0.12, 0.6, 0)
			for i in 2:
				studio.vp.render_target_update_mode = SubViewport.UPDATE_ONCE
				await RenderingServer.frame_post_draw
			_cache[key] = ImageTexture.create_from_image(studio.vp.get_texture().get_image())
			studio.clear()
		if cb.is_valid():
			cb.call(_cache[key])
	_busy = false
