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
var warm_secs := 0.0     # how long the shader warm-up took this launch (Boot writes it to the journal)
## (15.11) the loading screen waits only for the common stone shaders (the mine's niches, a find's usual glass and
## rock); the rest — mushrooms, legends, fossils, the sea, the showy minerals — warm up behind the home screen, one
## at a time, and not while a level is being played (warm_pause: Level sets it). After iOS cleared its shader cache
## the whole warm-up took ~30 s on the loading screen
var warm_pause := false
var warm_all_done := false

## (26.11) the star heart's pace: calm as a rule — a slow lub-dub, a long rest; shaken (SpecView.shake_find, a hard
## flick of the stone: heart_rush 1) it races, and settles again over some ten seconds
var heart_rush := 0.0
var heart_t := 0.0       # seconds into this beat
var heart_gap := 0.3     # the dub after the lub, s
var _heart_ph := 0.0

func _process(_dt: float) -> void:
	# (26.11: the glow lasts longer — some 5 s dark of every 10; it was 2.5 of 7: the card's back could hardly be read)
	var ph := fmod(Time.get_ticks_msec() / 1000.0, 10.0) / 10.0
	uv = force_uv if force_uv >= 0.0 else smoothstep(0.42, 0.47, ph) * (1.0 - smoothstep(0.92, 0.98, ph))
	RenderingServer.global_shader_parameter_set("fluor_uv", uv)
	# lub-dub: a short strong beat, a softer one a third of a second after it, then a long rest — some 46 beats a
	# minute at rest (26.11: at 70, the two beats spread evenly over the cycle, it read as a blinking, not a heart);
	# racing — 105, harder
	heart_rush = maxf(0.0, heart_rush - _dt / 10.0)
	var rush := smoothstep(0.0, 1.0, heart_rush)
	var period := lerpf(1.3, 0.57, rush)
	_heart_ph = fposmod(_heart_ph + _dt / period, 1.0)
	heart_t = _heart_ph * period
	heart_gap = lerpf(0.3, 0.21, rush)
	beat = (exp(-pow((heart_t - 0.07) / 0.045, 2.0)) + 0.6 * exp(-pow((heart_t - 0.07 - heart_gap) / 0.06, 2.0))) * lerpf(0.7, 1.0, rush)
	RenderingServer.global_shader_parameter_set("heart_beat", beat)

func _ready() -> void:
	studio = SpecStudio.make(PX, Viewport.MSAA_4X)
	studio.vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(studio.vp)
	_disk_init()
	_warm()

## compile the specimen shaders right at launch, while the boot splash is still up (the first one takes
## a good fraction of a second): a little ball per variant, drawn once in the offscreen studio,
## so neither the home screen nor the first find stutters
func _warm() -> void:
	while _busy:
		await get_tree().process_frame
	_busy = true
	var warm_t0 := Time.get_ticks_msec()
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
	mats.append(SpecJelly.material(Color.WHITE, 0, 0.0, 1.0))
	var fm := ShaderMaterial.new()
	fm.shader = SpecFossil.SHADER
	mats.append(fm)
	var wm := ShaderMaterial.new()
	wm.shader = SpecWood.SHADER
	mats.append(wm)
	var src := ShaderFiles.sources()
	for nm in ["legend_over", "foliage", "plants", "plants_bed", "bolt"]:
		var gm := ShaderMaterial.new()
		gm.shader = ShaderFiles.get_shader(nm, src[nm])
		mats.append(gm)
	for sh: Shader in [SpecBranch.SHADER, SpecWood.STONE, SpecFlower.AMBER, SpecTrilobite.SHADER, SpecTrilobite.PLATE, SpecPearl.SHADER, SpecSea.CAUSTIC, SpecSea.LIFE, SpecSea.BUBBLE, SpecFern.FILM_SHADER, SpecPolar.AURORA, SpecPolar.FROST, SpecForms.BISMUTH, SpecForms.BLADES, SpecForms.PEARL]:
		var xm := ShaderMaterial.new()
		xm.shader = sh
		mats.append(xm)
	var first := SpecMat.COMMON.size()
	var done := 0
	for m in mats:
		if done == first:
			# the loading screen may go: the rest warms behind the home screen
			BoardSprites.preload_all()
			warm_secs = (Time.get_ticks_msec() - warm_t0) / 1000.0
			warm_done = true
			warmed.emit()
			_busy = false
			# (a picture asked for meanwhile waited in the queue: _pump starts only when the studio is free)
			if _queue.size(): _pump()
		if done >= first:
			# (one every few frames, never while a level is played or a stone is being built)
			for k in 6:
				await get_tree().process_frame
			while warm_pause or _busy:
				await get_tree().create_timer(0.25).timeout
			_busy = true
		# (a picture built between two of these clears the studio, and the balls' node with it: made again then)
		if not is_instance_valid(balls) or not balls.is_inside_tree():
			balls = Node3D.new()
			studio.stage.add_child(balls)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = m
		balls.add_child(mi)
		studio.vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		mi.visible = false
		if done >= first:
			_busy = false
			if _queue.size(): _pump()
		else:
			# breathe between compiles, so the loading screen keeps moving and its bar keeps filling
			for k in 3:
				await get_tree().process_frame
		done += 1
		if done <= first: warm_progress = done / float(first)
	if is_instance_valid(balls): balls.queue_free()
	warm_all_done = true
	Diag.note("background shader warm-up done: %d more in %.1f s from the start" % [mats.size() - first, (Time.get_ticks_msec() - warm_t0) / 1000.0])
	if _queue.size():
		_pump()

static func key_of(o: Dictionary) -> String:
	var j: Dictionary = o.get("jewel", {})
	var tail := ""
	if o.get("form", "") == "skull":
		tail = "|skull" + ("|" + String(o.beast) if o.has("beast") else "")
	if int(o.get("integ", 100)) < 100: tail += "|i%d" % int(o.integ)
	if o.get("gulp", false): tail += "|gulp"
	if o.get("mend", false): tail += "|mend"
	if o.has("dl"): tail += "|d%d" % int(o.dl)
	if o.has("accents"): tail += "|a" + ".".join(o.accents) + "|f%d" % int(o.get("flora", -1))
	if o.has("flies"): tail += "|b%d%s" % [int(o.flies), String(o.get("fly_kind", ""))]
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [o.get("seed", 0), o.get("sid", ""), o.get("kind", ""), o.get("gi", ""), ".".join(o.get("traits", [])),
		o.get("cut", ""), int(o.get("legend", false)), str(j.get("rid", "")) + "".join(j.get("cols", [])), o.get("machine", ""), o.get("fx", "")] + tail

## the description of a stone from the save, as the builder wants it
static func of_stone(s: Dictionary) -> Dictionary:
	var o := {seed = s.id, sid = s.sid, kind = s.get("kind", "crystal"), gi = s.gi, traits = s.get("traits", []), legend = s.get("legend", false), cut = s.get("cut", "")}
	if s.has("fx"): o.fx = s.fx
	# (the depth it came from: deeper finds grow more crowded — SpecGenome, Stones.depth_forms)
	if s.has("dl"): o.dl = int(s.dl)
	if s.has("shroom"): o.shroom = s.shroom
	# how well it came out of the rock: a careless dig shows on the stone (SpecimenBuilder.damage_of)
	if int(s.get("integ", 100)) < 100: o.integ = int(s.integ)
	# (the plesiosaur swallowed it: its card shows the plesiosaur alone)
	if s.get("gulp", false): o.gulp = true
	# (mended with gold by a kintsugi stone: its breaks filled with gold — CardKintsugi)
	if s.get("mended", false): o.mend = true
	# butterflies pinned on a find (test keys, -- reveal=N flies=3 fly_kind=monarch); a rolled find leaves them to its seed
	for k in ["flies", "fly_kind", "fly_mode"]:
		if s.has(k): o[k] = s[k]
	# (22.11) a find picked by eye (the old man's gift, the first stone of one's own — Stones.picked): its shared layer
	# pinned, as the gallery's acc= / flora=
	for k in ["accents", "flora"]:
		if s.has(k): o[k] = s[k]
	# a skull (SpecSkull): its body, and any of its genes pinned
	if s.get("form", "") == "skull":
		o.form = "skull"
		for k in SpecSkull.KEYS:
			if s.has(k): o[k] = s[k]
	return o

static func of_jewel(j: Dictionary) -> Dictionary:
	return {seed = j.id, jewel = {rid = j.rid, cols = j.cols}}

func cached(o: Dictionary) -> Texture2D:
	return _cache.get(key_of(o))

# ---------------------------------------------------------------- pictures kept on disk
## a picture made once is saved (user://thumbs) and read back next launch: a full inventory of skulls is ~1 s
## per stone to build on a phone, a png ~ms. Each build of the game starts afresh (the generator changes between
## builds): its stamp (res://build_stamp.gd, written by the iOS build) is kept beside the pictures. On the PC (25.11:
## every launch rebuilt the whole inventory — ~30 builds, a barite 3.3 s — and it ran hot) the stamp is the newest
## change to the generator's own files (DEV_SRC): any edit to it drops the old pictures by itself. `no_thumbs_disk`
## turns the disk off there
const DISK := "user://thumbs/"
const DISK_V := 1    # bump when the pictures' framing changes
static var _stamp := ""

static func _disk_init() -> void:
	if ResourceLoader.exists("res://build_stamp.gd"):
		_stamp = str((load("res://build_stamp.gd") as GDScript).get_script_constant_map().get("ID", ""))
	elif OS.has_feature("editor") and not OS.get_cmdline_user_args().has("no_thumbs_disk"):
		_stamp = "dev:%d" % _dev_mtime()
	if _stamp == "": return
	_stamp += "|%d" % DISK_V
	DirAccess.make_dir_recursive_absolute(DISK)
	var sf := DISK + "stamp.txt"
	var was := FileAccess.get_file_as_string(sf) if FileAccess.file_exists(sf) else ""
	if was != _stamp:
		var n := 0
		for f in DirAccess.get_files_at(DISK):
			if f.ends_with(".png"):
				DirAccess.remove_absolute(DISK + f)
				n += 1
		var w := FileAccess.open(sf, FileAccess.WRITE)
		if w: w.store_string(_stamp)
		Diag.note("thumbs on disk: new build, %d old pictures dropped" % n)

## what a find's picture is made of on the PC: the generator, its shaders, its models and scans
const DEV_SRC := ["res://scripts/specimen", "res://scripts/autoload/spec.gd", "res://scripts/core/stones.gd", "res://scripts/core/worth.gd",
	"res://shaders", "res://assets/specimen", "res://assets/textures"]

## the newest change among them (seconds), sub-folders too
static func _dev_mtime() -> int:
	var t := 0
	var todo: Array = DEV_SRC.duplicate()
	while todo.size():
		var p: String = todo.pop_back()
		if DirAccess.dir_exists_absolute(p):
			for d in DirAccess.get_directories_at(p): todo.append(p + "/" + d)
			for f in DirAccess.get_files_at(p): t = maxi(t, FileAccess.get_modified_time(p + "/" + f))
		elif FileAccess.file_exists(p):
			t = maxi(t, FileAccess.get_modified_time(p))
	return t

static func _disk_path(kind: String, key: String) -> String:
	return DISK + kind + "_" + key.md5_text() + ".png"

## a picture saved earlier (kind: "t" thumbnails, "c" the atlas's cutouts), or null
static func disk_get(kind: String, key: String) -> Texture2D:
	if _stamp == "": return null
	var p := _disk_path(kind, key)
	if not FileAccess.file_exists(p): return null
	var img := Image.load_from_file(p)
	if img == null or img.is_empty(): return null
	return ImageTexture.create_from_image(img)

static func disk_put(kind: String, key: String, img: Image) -> void:
	if _stamp == "" or img == null: return
	img.save_png(_disk_path(kind, key))

## machines never change: their pictures are baked into the project (bake_thumbs key), not rendered on the phone
const BAKED := "res://assets/thumbs/machine_%s.png"

## a picture cache kept to its last `n` entries (a Dictionary keeps the order things were put in): unbounded, the
## thumbnails and cutouts of a big collection held hundreds of MB of video memory for the whole game
const THUMBS_MAX := 160
static func trim(d: Dictionary, n: int) -> void:
	while d.size() > n:
		d.erase(d.keys()[0])

## owner: as Atlas.cutout's - left behind with its screen, the thumbnail isn't built
func thumb(o: Dictionary, cb: Callable, owner: Object = null) -> void:
	var t := cached(o)
	if t == null and not o.has("bake"):
		t = disk_get("t", key_of(o))
		if t:
			_cache[key_of(o)] = t
			trim(_cache, THUMBS_MAX)
	if t:
		cb.call(t)
		return
	if o.has("machine") and not o.has("bake") and ResourceLoader.exists(BAKED % o.machine):
		var bt: Texture2D = load(BAKED % o.machine)
		_cache[key_of(o)] = bt
		cb.call(bt)
		return
	_queue.append([o, cb, owner])
	if not _busy:
		_pump()

func _pump() -> void:
	_busy = true
	while _queue.size():
		var item: Array = _queue.pop_front()
		var o: Dictionary = item[0]
		var cb: Callable = item[1]
		var key := key_of(o)
		if not _cache.has(key) and Atlas._gone(item[2]):
			continue
		if not _cache.has(key):
			var p: Node3D = await studio.show_async(o)
			if p == null:
				continue   # the build failed (see Diag): no picture, but the queue goes on
			p.rotation = Vector3(0.12, 0.6, 0)
			for i in 2:
				studio.vp.render_target_update_mode = SubViewport.UPDATE_ONCE
				await RenderingServer.frame_post_draw
			var img := studio.vp.get_texture().get_image()
			_cache[key] = ImageTexture.create_from_image(img)
			trim(_cache, THUMBS_MAX)
			if not o.has("bake") and not o.has("machine"): disk_put("t", key, img)
			studio.clear()
		if cb.is_valid():
			cb.call(_cache[key])
	_busy = false
