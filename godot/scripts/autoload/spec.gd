extends Node
## Photographs of specimens, jewellery and machines for lists and cards: rendered one at a time
## in an offscreen studio and kept in memory. Ask with thumb(o, callback).

const PX := 256

var studio: SpecStudio
var _cache := {}
var _queue := []
var _busy := false

func _ready() -> void:
	studio = SpecStudio.make(PX, Viewport.MSAA_4X)
	studio.vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(studio.vp)

static func key_of(o: Dictionary) -> String:
	var j: Dictionary = o.get("jewel", {})
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s" % [o.get("seed", 0), o.get("sid", ""), o.get("kind", ""), o.get("gi", ""), ".".join(o.get("traits", [])),
		o.get("cut", ""), int(o.get("legend", false)), str(j.get("rid", "")) + "".join(j.get("cols", [])), o.get("machine", "")]

## the description of a stone from the save, as the builder wants it
static func of_stone(s: Dictionary) -> Dictionary:
	return {seed = s.id, sid = s.sid, kind = s.get("kind", "crystal"), gi = s.gi, traits = s.get("traits", []), legend = s.get("legend", false), cut = s.get("cut", "")}

static func of_jewel(j: Dictionary) -> Dictionary:
	return {seed = j.id, jewel = {rid = j.rid, cols = j.cols}}

func cached(o: Dictionary) -> Texture2D:
	return _cache.get(key_of(o))

func thumb(o: Dictionary, cb: Callable) -> void:
	var t := cached(o)
	if t:
		cb.call(t)
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
