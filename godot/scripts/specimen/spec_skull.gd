class_name SpecSkull
extends RefCounted
## A human skull as the generator's host rock (Koschei's mine, docs/skulls.md): the body is a scan
## (PolyOne Studio, "Free Pack - Human Skull", CC BY — prototype/tools/skull/export_skull.py → assets/specimen/skull.json),
## dressed in its own bone (shaders/bone.gdshader) and handed to the builder as its rock, so the shared layer (lichen, mushrooms...)
## grows on it by itself; the skull's own genes place the crystals by its landmarks.

const U := preload("res://scripts/specimen/spec_util.gd")
const SRC := "res://assets/specimen/skull.json"
const K := 0.15            # source centimetres → generator units (the skull ~1.3 tall)
const LIFT := 4.4          # source height of the middle: the skull sits around the origin, like a rock
const BONE := preload("res://shaders/bone.gdshader")
## how finely a soil crumb is cut (RockKit.crumble): 0 by its size (_earth), a number — every crumb so (tests, `crumb=`)
static var CRUMB_DETAIL := 0
const BONE_OLD := preload("res://shaders/bone_old.gdshader")   # (admin "Skull speedups: off" — the cost before 7.11)
## a waterfall out of the eye: its sheet's width at the lip and where it lands
const FALL_W := [0.085, 0.065]
const FALL := preload("res://shaders/skull_fall.gdshader")
const GLASS := preload("res://shaders/skull_glass.gdshader")
const BARK := preload("res://shaders/bark.gdshader")
const METAL_RUN := preload("res://shaders/metal_run.gdshader")
## the cast metals: [colour, roughness, (patina colour)]
const METALS := {
	gold = [Color(0.95, 0.68, 0.28), 0.16],
	silver = [Color(0.86, 0.87, 0.9), 0.18],
	copper = [Color(0.86, 0.45, 0.3), 0.22, Color(0.16, 0.36, 0.3)],
}

## the genes a skull may have pinned from outside (the save, tests, the admin): SpecGenome and Spec pass these on
const KEYS := ["eyes", "breach", "crown", "jaw", "earth", "milk", "tone", "show", "rock_kind", "lie", "dmg", "fangs", "moss", "trees",
	"flies", "fly_kind", "fly_mode", "skin", "stream", "roots", "tree_kind", "bloom", "bloom_pal", "wine", "coins", "diadem", "lantern", "pile"]
## the skins water may run over (not cast metal, the mosaic or glass: there it would sit like a sticker)
const WET_SKINS := ["bone", "nacre", "gilt", "agate", "opal", "pyrite", "geode"]
## the bones that are not bone any more (bone.gdshader skins 5–8)
const STONE_SKINS := {agate = 5, opal = 6, pyrite = 7, geode = 8}

static var _parts := {}
static var _lock := Mutex.new()

## the scan's parts (cranium, teeth_up, mandible, teeth_low) as Geo, with the pits shaded into vertex red
## (and the ridges into green), loaded once
static func parts() -> Dictionary:
	_lock.lock()
	if _parts.is_empty():
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SRC))
		var ps: Dictionary = d.parts
		for k: String in ps:
			var p: Dictionary = ps[k]
			var fv: Array = p.v
			var ff: Array = p.f
			var g := Geo.new()
			g.v.resize(fv.size() / 3)
			for i in g.v.size():
				g.v[i] = Vector3(float(fv[i * 3]), float(fv[i * 3 + 1]) - LIFT, float(fv[i * 3 + 2])) * K
			g.idx.resize(ff.size())
			for i in ff.size():
				g.idx[i] = int(ff[i])
			_shade(g)
			_parts[k] = g
			# each tooth on its own, so a skull can lose some
			if k.begins_with("teeth"):
				_parts[k + "_each"] = _split(g)
	_lock.unlock()
	return _parts

## how deep in a pit each point lies: the mesh smoothed hard pulls out of its hollows (eye sockets, the nose,
## between the teeth, the sutures) and sinks over its ridges; the gap along the normal is the shading
static func _shade(g: Geo) -> void:
	var n := g.v.size()
	var nb: Array[PackedInt32Array] = []
	nb.resize(n)
	var seen := {}
	for t in g.idx.size() / 3:
		for e in 3:
			var a := g.idx[t * 3 + e]
			var b := g.idx[t * 3 + (e + 1) % 3]
			var key := mini(a, b) * 1000003 + maxi(a, b)
			if seen.has(key): continue
			seen[key] = true
			nb[a].append(b)
			nb[b].append(a)
	var s := g.v.duplicate()
	for it in 30:
		var s2 := s.duplicate()
		for i in n:
			if nb[i].is_empty(): continue
			var acc := Vector3.ZERO
			for j in nb[i]:
				acc += s[j]
			s2[i] = s[i].lerp(acc / nb[i].size(), 0.8)
		s = s2
	var nr := g.normals()
	var raw := PackedFloat32Array()
	raw.resize(n)
	var lo := 0.0
	var hi := 0.0
	for i in n:
		raw[i] = (s[i] - g.v[i]).dot(nr[i])
		lo = minf(lo, raw[i])
		hi = maxf(hi, raw[i])
	var sorted := raw.duplicate()
	sorted.sort()
	var top := maxf(0.0001, sorted[int(n * 0.97)])
	var bot := minf(-0.0001, sorted[int(n * 0.03)])
	g.col.resize(n)
	for i in n:
		var cav := clampf(raw[i] / top, 0.0, 1.0)
		var crest := clampf(raw[i] / bot, 0.0, 1.0)
		var k := clampf(1.0 - cav * 0.85, 0.08, 1.0)
		g.col[i] = Color(k, 0.5 + crest * 0.5, 0.0)   # (blue: soil, laid on where crystals break out)

## a mesh's separate pieces (by shared vertices), each its own Geo
static func _split(g: Geo) -> Array[Geo]:
	var par := PackedInt32Array()
	par.resize(g.v.size())
	for i in par.size(): par[i] = i
	var fd := func(a: int) -> int:
		while par[a] != a:
			a = par[a]
		return a
	for t in g.idx.size() / 3:
		var a: int = fd.call(g.idx[t * 3])
		for e in [1, 2]:
			var bb: int = fd.call(g.idx[t * 3 + e])
			if bb != a: par[bb] = a
	var by := {}
	for t in g.idx.size() / 3:
		var r: int = fd.call(g.idx[t * 3])
		if not by.has(r): by[r] = []
		(by[r] as Array).append(t)
	var out: Array[Geo] = []
	for r: int in by:
		var piece := Geo.new()
		var remap := {}
		for t: int in by[r]:
			for e in 3:
				var i := g.idx[t * 3 + e]
				if not remap.has(i):
					remap[i] = piece.v.size()
					piece.v.append(g.v[i])
					piece.col.append(g.col[i])
				piece.idx.append(int(remap[i]))
		out.append(piece)
	return out

static func _copy(g: Geo) -> Geo:
	var c := Geo.new()
	c.v = g.v.duplicate()
	c.idx = g.idx.duplicate()
	c.col = g.col.duplicate()
	return c

## the skull's own genes (on their own random stream: nothing else in the find moves)
static func genes(seed_v: int, o: Dictionary) -> Dictionary:
	var r := Rng32.new((seed_v * 2246822519 + 3266489917) % 4294967296)
	var g := {
		jaw = o.get("jaw", r.next() < 0.75),
		# where the crystals break out: down one side of the head toward the temple, or a crest along the top
		breach = o.get("breach", "side" if r.next() < 0.6 else "crest"),
		side = -1.0 if r.next() < 0.8 else 1.0,   # (-X: the side the card turns to the viewer — SpecView sways a face find round y 0.6)
		crown_at = r.next(),
		crown_n = 80 + int(r.next() * 60),
		earth = o.get("earth", r.next() < 0.85),
		# the bone: how old (white → brown, cracked), how polished
		age = r.next(),
		gloss = r.next(),
		cracks = r.next(),
		# the head's own build: broad or narrow, high or low, long or short, a little lopsided
		shape = [0.93 + r.next() * 0.14, 0.94 + r.next() * 0.12, 0.93 + r.next() * 0.14, r.next() * 1000.0],
		# crystals out of the eye sockets: none, one, both (with the breach, or instead of it)
		eyes = o.get("eyes", "none" if r.next() < 0.6 else "one" if r.next() < 0.5 else "both"),
		eye_side = -1.0 if r.next() < 0.5 else 1.0,
		eye_n = 18 + int(r.next() * 18),
		crown = o.get("crown", r.next() < 0.8),
		# the bone's tone: clean; dug out of the grave — dark grey-brown, soil ground into it; or black as soot
		tone = o.get("tone", "bone" if r.next() < 0.6 else "grave" if r.next() < 0.7 else "ash"),
		# the crystals: clear as their species grows them, or cloudy (milky glass) or matte (opaque, like resin)
		milk = o.get("milk", "clear" if r.next() < 0.55 else "frost" if r.next() < 0.65 else "wax"),
		# shown loose, or half sunk in a slab of rock, lying as it fell (yaw, roll, pitch, x, how deep, z)
		show = o.get("show", "rock" if r.next() < 0.4 else "loose"),
		rock_kind = o.get("rock_kind", Stones.pick_w([["slab", 3.5], ["buried", 2.5], ["boulder", 2.5], ["perched", 1.5]], r)),
		rock_x = int(r.next() * 18),
		sink = r.next(),
		lie_x = (r.next() - 0.5) * 0.3,
		lie_z = (r.next() - 0.5) * 0.2,
		# how it lies: [yaw, roll, pitch]
		lie = o.get("lie", Stones.pick_w([["upright", 3.5], ["tilt", 2.5], ["side", 2.0], ["up", 1.0], ["down", 1.0]], r)),
		lie_r = [r.next(), r.next(), r.next(), -1.0 if r.next() < 0.5 else 1.0],
		# the sutures: how plain (none at all on a third), and where they run on this head
		sutures = [0.0 if r.next() < 0.3 else 0.25 + r.next() * 0.75, (r.next() - 0.5) * 0.04, (r.next() - 0.5) * 0.08, (r.next() - 0.5) * 0.08],
		# knocks it took: none, worn (a chip or two, a few teeth gone), broken (a hole in the vault, more chips and teeth)
		dmg = o.get("dmg", Stones.pick_w([["none", 5.0], ["worn", 3.0], ["broken", 2.0]], r)),
		dmg_seed = int(r.next() * 100000),
		marks = [],
		reserve = [],   # (places crystals keep off: the big tree's foot)
		taken = [],   # (spots crystals and trees already hold)
		# crystal teeth: none, some (where teeth fell out, and a few more), or the whole grin in crystal
		fangs = o.get("fangs", Stones.pick_w([["none", 7.2], ["some", 1.8], ["all", 1.0]], r)),
		fang_seed = int(r.next() * 100000),
		# a forest on the head: moss in patches, or a cap of it over the vault; little trees standing in the moss
		moss = o.get("moss", Stones.pick_w([["none", 5.5], ["patches", 2.5], ["cap", 2.0]], r)),
		moss_seed = int(r.next() * 100000),
		trees = int(o.get("trees", -1)),
		# butterflies resting on it: how many (mostly none), and of one kind or a mix
		flies = int(o.get("flies", 0 if r.next() < 0.68 else 1 + int(r.next() * 3))),
		fly_kind = String(o.get("fly_kind", "")),
		fly_mode = int(o.get("fly_mode", -1)),   # (tests: 1 all fly, 0 all rest)
		fly_seed = int(r.next() * 100000),
		# what the skull is made of / dressed in: bone, gold leaf over part, cast in molten gold, a kintsugi mosaic of
		# stones on gold seams, turned to mother-of-pearl, or the whole skull in clear glass with flowers inside
		skin = o.get("skin", Stones.pick_w([["bone", 6.0], ["nacre", 1.4], ["gilt", 1.0], ["gold", 0.35], ["silver", 0.21], ["copper", 0.14], ["kintsugi", 0.7], ["glass", 0.5]], r)),
		skin_k = r.next(),
		skin_seed = int(r.next() * 100000),
		gilt_dir = [(r.next() - 0.5) * 2.0, r.next() - 0.3, r.next()],
		# a stream out of an eye (mostly with moss), roots of a tree over the skull
		stream = o.get("stream", r.next() < 0.2),
		stream_side = -1.0 if r.next() < 0.8 else 1.0,   # (mostly the side the card shows)
		roots = o.get("roots", r.next() < 0.1),
		# the crown of the trees on it: a flocked moss puff, leaves, blossom with buds, autumn, or bare
		# a bouquet bursting out of the crown in place of the crystals (red and gold, white and lilac...)
		bloom = o.get("bloom", r.next() < 0.1),
		bloom_pal = int(o.get("bloom_pal", int(r.next() * SpecBloom.PALETTES.size()))),
		tree_kind = o.get("tree_kind", Stones.pick_w([["moss", 3.0], ["leaves", 2.5], ["blossom", 2.0], ["autumn", 1.5], ["bare", 1.0]], r)),
	}
	# the spring runs scarlet, as wine, in about a third (its own draw: the other genes stay as they were)
	g.wine = o.get("wine", Rng32.new(int(g.skin_seed) * 3 + 333).next() < 0.3)
	# later genes, each on its own draw (no older skull changes): a bone turned to stone — banded agate, opal, pyrite,
	# or a geode's black crust; obols on the eyes; Koschei's diadem; fireflies living inside; a pile of two or three
	var x := func(k: int) -> float: return Rng32.new(int(g.skin_seed) * 13 + k * 7919).next()
	if g.skin == "bone" and not o.has("skin") and x.call(1) < 0.16:
		g.skin = Stones.pick_w([["agate", 3.0], ["pyrite", 3.0], ["geode", 2.5], ["opal", 1.5]], Rng32.new(int(g.skin_seed) * 13 + 5))
	g.coins = o.get("coins", x.call(2) < 0.05)
	g.diadem = o.get("diadem", x.call(3) < 0.05)
	g.lantern = o.get("lantern", false)   # (fireflies inside: set aside 7.11)
	# (a pile of skulls: built, but not rolled — set aside 7.11; the admin or tests can still pin it)
	g.pile = int(o.get("pile", 0))
	g.fx = String(o.get("fx", ""))
	if g.show == "rock": g.pile = 0
	# what fills the eyes: a fire, watching eyes or fireflies need them open; obols lie over them
	# a cloud of butterflies: many, all resting to begin with (SpecSkullFx.Flock sends them up together)
	if g.fx == "flutter":
		g.flies = 7
		g.fly_mode = 0
	if g.fx in ["yaga", "watching"] or g.lantern or g.coins:
		g.eyes = "none"
		g.crown = true
	if g.fx in ["yaga", "watching"] or g.coins: g.stream = false
	if g.fx in ["yaga", "watching"]: g.coins = false
	# a diadem sits where a crown of crystals would: the crystals then come out of the eyes (if they are free)
	if g.diadem:
		if g.eyes == "none" and not (g.coins or g.lantern or g.fx in ["yaga", "watching"]):
			g.crown = false
			g.eyes = "both"
		elif g.eyes != "none":
			g.crown = false
		else:
			g.diadem = false
	# deathless: the skull falls to shards and gathers itself again — loose, nothing running over it
	if g.fx == "deathless":
		g.show = "loose"
		g.stream = false
		g.pile = 0
	# a candle on the crown: no crystal crown under it, no tree in the way
	if g.fx == "candle":
		g.roots = false
		g.crown = false
		g.bloom = false
		g.trees = 0
		if g.eyes == "none": g.eyes = "one"
	# a glass skull is the crystal: no breach, no crystals out of the eyes, no moss
	if g.skin == "glass":
		g.crown = false
		g.eyes = "none"
		g.fangs = "none"
		g.moss = "none"
		g.trees = 0
		g.dmg = "none"
	# cast metal: nothing grows on it (moss, trees, a stream would sit on the metal like stickers)
	if g.skin in ["gold", "silver", "copper", "kintsugi", "glass"]:
		g.moss = "none"
		g.trees = 0
		g.stream = false
		g.roots = false
	if g.stream and g.moss == "none" and not o.has("moss"): g.moss = "patches"
	# which butterflies: decided here, not while building, so the achievements (Awards.genes_of) know them
	# (8.11; until then the builder picked them on its own stream - the skulls' butterflies changed then)
	var kinds: Array = []
	var fk := Rng32.new(int(g.fly_seed) * 31 + 17)
	var one: String = String(g.fly_kind) if String(g.fly_kind) != "" else ("" if fk.next() < 0.3 else SpecButterfly.pick(fk))
	for k in int(g.flies): kinds.append(one if one != "" else SpecButterfly.pick(fk))
	g.fly_kinds = kinds
	if int(g.trees) < 0:
		var tr := Rng32.new(int(g.moss_seed) + 5)
		g.trees = 0 if g.moss == "none" or tr.next() < 0.45 else 1 + int(tr.next() * (4.0 if g.moss == "cap" else 2.0))
	var dr := Rng32.new(int(g.dmg_seed) * 7 + 1)
	var nl := 0 if g.dmg == "none" else 1 + int(dr.next() * 4) if g.dmg == "worn" else 3 + int(dr.next() * 7)
	var lost := []
	for k in nl:
		lost.append(int(dr.next() * 200))
	g.lost = lost
	# the pose's angles, [yaw, roll, pitch]: upright, tipped, on its side (on a temple), face up, chin down
	var q: Array = g.lie_r
	var sg := float(q[3])
	var yaw := (float(q[0]) - 0.5) * 1.0
	match String(g.lie):
		"upright": g.lie_a = [yaw, (float(q[1]) - 0.5) * 0.3, -0.1 - float(q[2]) * 0.2]
		"tilt": g.lie_a = [yaw, sg * (0.3 + float(q[1]) * 0.3), (float(q[2]) - 0.5) * 0.6]
		"side": g.lie_a = [yaw * 0.6, sg * (1.0 + float(q[1]) * 0.4), (float(q[2]) - 0.5) * 0.4]
		"up": g.lie_a = [yaw * 0.6, (float(q[1]) - 0.5) * 0.4, -0.7 - float(q[2]) * 0.4]
		_: g.lie_a = [yaw * 0.6, (float(q[1]) - 0.5) * 0.4, 0.3 + float(q[2]) * 0.3]
	# a spring only where it can be seen running: not on a skull lying face up or face down (it would fill the eyes or
	# run unseen underneath), nor one turned away from the viewer — the badge goes with it (_stream decides the same)
	if g.stream:
		var dn := down_of(g)
		if absf(dn.dot(Vector3.BACK)) > 0.6 or (pose_basis(g) * Vector3.BACK).z < -0.1: g.stream = false
	return g

## the skull's build: stretched by its own proportions and a soft lopsidedness (one transform for every part, so
## the jaw and teeth still meet the head)
static func _shape(g: Geo, sh: Array) -> Geo:
	var fn := FastNoiseLite.new()
	fn.seed = int(sh[3])
	fn.frequency = 1.1
	for i in g.v.size():
		var p := g.v[i]
		var top := clampf((p.y + 0.1) / 0.7, 0.0, 1.0)
		var s := Vector3(lerpf(1.0, float(sh[0]), top), float(sh[1]), lerpf(1.0, float(sh[2]), top))
		g.v[i] = p * s + p.normalized() * fn.get_noise_3dv(p) * 0.025
	return g

static func bone_mat(sk: Dictionary, seed_v: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = BONE if SpecUtil.fast else BONE_OLD
	m.set_shader_parameter("age", float(sk.age))
	m.set_shader_parameter("gloss", float(sk.gloss))
	# a scarlet spring stains the bone it runs over
	if sk.stream and sk.get("wine", false): m.set_shader_parameter("wet_col", Vector3(1.35, 0.28, 0.3))
	m.set_shader_parameter("crack_k", 0.2 + float(sk.cracks) * 0.8)
	if String(sk.get("fx", "")) == "deathless":
		m.set_shader_parameter("deathless", 1.0)
		m.set_shader_parameter("crack_k", 1.0)
		m.set_shader_parameter("suture_k", 1.0)
	m.set_shader_parameter("seed", float(seed_v % 97) * 1.37)
	var su: Array = sk.sutures
	m.set_shader_parameter("suture_k", 1.0 if String(sk.get("fx", "")) == "deathless" else float(su[0]))
	m.set_shader_parameter("sut_shift", Vector3(float(su[1]), float(su[2]), float(su[3])))
	match String(sk.skin):
		"gilt": m.set_shader_parameter("skin", 1)
		"gold", "silver", "copper":
			m.set_shader_parameter("skin", 2)
			var mt: Array = METALS[String(sk.skin)]
			var mc: Color = mt[0]
			m.set_shader_parameter("metal_col", Vector3(mc.r, mc.g, mc.b))
			m.set_shader_parameter("metal_rough", float(mt[1]) + 0.14)
			if mt.size() > 2:
				var pc: Color = mt[2]
				m.set_shader_parameter("patina_col", Vector3(pc.r, pc.g, pc.b))
				m.set_shader_parameter("patina_k", 1.0)
			if sk.skin == "silver": m.set_shader_parameter("patina_col", Vector3(0.06, 0.06, 0.07))
			if sk.skin == "silver": m.set_shader_parameter("patina_k", 0.8)
		"kintsugi": m.set_shader_parameter("skin", 3)
		"agate", "opal", "pyrite", "geode":
			m.set_shader_parameter("skin", int(STONE_SKINS[sk.skin]))
			m.set_shader_parameter("skin_k", float(sk.skin_k))
			# (a stone skull is polished or weathered, its crust cracked: fewer bone cracks)
			m.set_shader_parameter("crack_k", 0.15)
		"nacre": m.set_shader_parameter("skin", 4)
	m.set_shader_parameter("skin_k", 0.25 + float(sk.skin_k) * 0.6)
	m.set_shader_parameter("fire", [0.0, 0.33, 0.6, 0.75][int(float(sk.skin_k) * 997.0) % 4])
	var gd: Array = sk.gilt_dir
	m.set_shader_parameter("gilt_dir", Vector3(float(gd[0]), float(gd[1]), float(gd[2])))
	if sk.tone == "grave":
		m.set_shader_parameter("bone_col", Color(0.42, 0.38, 0.33))
		m.set_shader_parameter("stain_col", Color(0.24, 0.19, 0.14))
		m.set_shader_parameter("age", 0.5 + float(sk.age) * 0.5)
	elif sk.tone == "ash":
		# charred: matte charcoal grey, its ridges rubbed paler
		m.set_shader_parameter("bone_col", Color(0.21, 0.205, 0.2))
		m.set_shader_parameter("stain_col", Color(0.11, 0.1, 0.095))
		m.set_shader_parameter("pit_col", Color(0.02, 0.02, 0.02))
		m.set_shader_parameter("age", 0.25)
		m.set_shader_parameter("gloss", 0.05)
		m.set_shader_parameter("wear", 0.7)
	m.set_meta("rock", true)   # (ultraviolet lights crystals, never the host)
	return m

## the body: lays the skull in as the find's rock (st.pick, st.nrm, st.hollows, st.rock, st.rock_geo, like use_rock),
## then grows the crystals out through it. Returns the largest crystal.
static func build(b: RefCounted, gene: Dictionary, st: Dictionary, rock_mat: Callable, crystal: Callable, lean: Callable, use_rock: Callable) -> MeshInstance3D:
	var rng: Rng32 = b.rng
	var root: Node3D = b.root
	var before := root.get_children()
	var seed_v := int(gene.get("shroom_seed", 1))
	var sk := genes(seed_v, gene.get("skull", {}))
	var P := parts()
	var bm: Material = bone_mat(sk, seed_v)
	if sk.skin == "glass":
		var gm := ShaderMaterial.new()
		gm.shader = GLASS
		gm.render_priority = 1
		bm = gm
	var cr := _shape(_copy(P.cranium), sk.shape)
	_damage(cr, sk)
	var nr := cr.normals()
	# loose earth at the crystals' feet: plain dark soil (the rock material showed odd pale islands on it)
	var earth_m := StandardMaterial3D.new()
	earth_m.albedo_color = Color(0.2, 0.14, 0.09)
	earth_m.roughness = 1.0
	# the big tree's foot is kept clear before the crystals choose their places
	if sk.roots:
		var rr := Rng32.new(int(sk.skin_seed) + 11)
		rr.next()
		var bbx := cr.aabb()
		var want := Vector3((rr.next() - 0.5) * 0.15, bbx.position.y + bbx.size.y + 0.05, (rr.next() - 0.3) * 0.2)
		(sk.reserve as Array).append([want, 0.26])
	# crystals from the crown and/or the eyes (never neither)
	var crown: bool = sk.crown or sk.eyes == "none"
	var main: MeshInstance3D = null
	if crown and sk.skin != "glass":
		if sk.bloom:
			# the breach grows flowers, not crystals
			var bt := SpecBloom.batch()
			var br := Rng32.new(int(sk.skin_seed) + 31)
			var flower := func(f: float, at: Vector3, dir: Vector3) -> MeshInstance3D:
				# (a few crystals of the find's own kind among the flowers, so its name still shows)
				if br.next() < 0.1:
					return crystal.call(0.35 + f * 0.4, at, dir)
				_flower(bt, br, sk, f, at, dir)
				return null
			main = _breach(b, st, sk, cr, nr, earth_m, flower, lean)
			SpecBloom.flush(bt, root)
		else:
			main = _breach(b, st, sk, cr, nr, earth_m, crystal, lean)
	if sk.eyes != "none":
		var em := _eyes(b, st, sk, cr, nr, earth_m, crystal, lean)
		if main == null: main = em
	_earth_done(b, earth_m)

	# a geode: the crust broken away in patches, the bone hollowed there (crystals grow in them: SpecSkullFx.dress)
	if sk.skin == "geode": sk.geode_pits = SpecSkullFx.dig(cr, nr, sk, float(seed_v % 97) * 1.37)
	var mi := U.mesh(cr, bm, root)
	sk.cr_mi = mi
	mi.set_meta("base", Color(0.6, 0.55, 0.45))
	var tu := _teeth(P.teeth_up_each, _gone(sk, P.teeth_up_each.size(), 0, false))
	if tu.v.size(): U.mesh(_shape(tu, sk.shape), bm, root)
	_fangs(b, sk, P.teeth_up_each, _gone(sk, P.teeth_up_each.size(), 0, true), true, crystal, lean)
	var bones: Array[Geo] = [cr]
	if sk.jaw:
		var jaw := _shape(_copy(P.mandible), sk.shape)
		var jaw_mi := U.mesh(jaw, bm, root)
		sk.jaw_mi = jaw_mi
		var tl := _teeth(P.teeth_low_each, _gone(sk, P.teeth_low_each.size(), 100, false))
		if tl.v.size(): U.mesh(_shape(tl, sk.shape), bm, root)
		_fangs(b, sk, P.teeth_low_each, _gone(sk, P.teeth_low_each.size(), 100, true), false, crystal, lean)
		bones.append(jaw)
	var nrs: Array = bones.map(func(g: Geo) -> PackedVector3Array: return g.normals())
	if sk.skin in METALS: _drips(b, sk, bones, nrs)
	if sk.skin == "glass":
		_glass_flowers(b, sk)
		main = mi
	if sk.roots: _roots(b, sk, bones, nrs, cr)
	if sk.stream and sk.skin in WET_SKINS:
		_stream(b, sk, bones, nrs)
		# the bone it runs over, wet (the meshes rebuilt with the wetness in their vertex alpha)
		cr._mesh = null
		mi.mesh = cr.to_mesh()
		if sk.has("jaw_mi"):
			(bones[1] as Geo)._mesh = null
			(sk.jaw_mi as MeshInstance3D).mesh = (bones[1] as Geo).to_mesh()
	# the top of the head (where things settle) and the pits (eye sockets, nose) where moss and lichen like to sit
	var top: Array[int] = []
	var hol := []
	var bb := cr.aabb()
	var y_top := bb.position.y + bb.size.y
	for i in cr.v.size():
		var p := cr.v[i]
		if not _alive(cr, i): continue
		if nr[i].y > 0.25 and p.y > y_top - bb.size.y * 0.55:
			top.append(i)
		if cr.col[i].r < 0.55 and cr.col[i].b < 0.3 and nr[i].dot(Vector3(p.x, 0, p.z).normalized() + Vector3(0, 0.3, 0)) > 0.0 and i % 2 == 0:
			hol.append([p, nr[i]])
	st.rocky = true
	st.hollows = hol
	st.pick = func() -> Vector3: return cr.v[top[int(floor(rng.next() * top.size()))]]
	# (picks land on vertices: their normal straight from a table, anything else by the nearest vertex)
	var at_v := {}
	for i in cr.v.size():
		at_v[cr.v[i]] = i
	st.nrm = func(w: Vector3) -> Vector3:
		if at_v.has(w): return nr[int(at_v[w])]
		var best := 0
		var bd := INF
		for i in cr.v.size():
			var dd := cr.v[i].distance_squared_to(w)
			if dd < bd:
				bd = dd
				best = i
		return nr[best]
	st.rock = mi
	st.rock_geo = cr
	# butterflies: resting on the crown of the head, or flying round the find, each kind its own way
	if int(sk.flies) > 0 and top.size():
		var fr := Rng32.new(int(sk.fly_seed))
		# where they may land: the crown of the head, facing up
		var perches := []
		for q in (140 if String(sk.get("fx", "")) == "flutter" else 40):
			var j: int = top[int(fr.next() * top.size())]
			if nr[j].y > 0.45: perches.append([cr.v[j], nr[j]])
		for k in int(sk.flies):
			var id: String = sk.fly_kinds[k]
			var style: String = SpecButterfly.KINDS[id][6]
			var flying := fr.next() < (0.7 if style in ["hover", "flit"] else 0.45)
			if int(sk.fly_mode) >= 0: flying = int(sk.fly_mode) == 1
			var i: int = top[int(fr.next() * top.size())]
			SpecButterfly.put(root, fr, id, cr.v[i], nr[i], (0.34 + fr.next() * 0.12) * 0.8, flying, perches)
	# obols, a diadem, fireflies inside, a pile; its own legend (SpecSkullFx)
	SpecSkullFx.dress(b, sk, bones, nrs, bm, crystal, lean)
	_forest(b, sk, cr, nr, gene)
	_marks(b, st, sk, cr, nr, main, P)
	var T := Transform3D.IDENTITY
	if sk.show == "rock":
		var body := PackedVector3Array()
		for g: Geo in bones:
			for i in range(0, g.v.size(), 4):
				body.append(g.v[i])
		T = _on_rock(b, st, sk, cr, body, root.get_children().filter(func(n: Node) -> bool: return not n in before), crystal, lean, use_rock)
	for m: Array in sk.marks:
		b.call("_mark", String(m[0]), T * (m[1] as Vector3), (T.basis * (m[2] as Vector3)).normalized())
	return main

## where each of the skull's own genes shows (for the gene badges and their callouts), in the skull's space
static func _marks(b: RefCounted, st: Dictionary, sk: Dictionary, cr: Geo, nr: PackedVector3Array, main: MeshInstance3D, P: Dictionary) -> void:
	var mk: Array = sk.marks
	# (a badge of the bone itself points at bare bone: not under the flowers, the moss, the water)
	var taken: Array = sk.taken
	var bare := func(p: Vector3) -> bool:
		for k in range(0, taken.size(), 2):
			if p.distance_to(taken[k][0]) < 0.1: return false
		return true
	var best := func(score: Callable) -> int:
		var bi := 0
		var bs := -INF
		for i in range(0, cr.v.size(), 3):
			if not _alive(cr, i) or not bare.call(cr.v[i]): continue
			var v: float = score.call(cr.v[i], nr[i])
			if v > bs:
				bs = v
				bi = i
		return bi
	# the skin: on the side the leaf covers, or the brow
	var i_skin: int = best.call(func(p: Vector3, n: Vector3) -> float: return n.z + p.y * 0.8)
	if sk.skin == "gilt":
		var gd: Array = sk.gilt_dir
		var dir := Vector3(float(gd[0]), float(gd[1]), float(gd[2])).normalized()
		i_skin = best.call(func(p: Vector3, n: Vector3) -> float: return n.dot(dir) + n.z * 0.4)
	var i_cheek: int = best.call(func(p: Vector3, n: Vector3) -> float: return n.z - absf(absf(p.x) - 0.3) * 2.0 - absf(p.y + 0.15) * 2.0)
	for id: String in accents(sk):
		var at := Vector3.INF
		var n := Vector3.FORWARD
		match id.get_slice("_", 1):
			"gilt", "gold", "silver", "copper", "kintsugi", "nacre", "glass", "agate", "opal", "pyrite", "geode":
				at = cr.v[i_skin]
				n = nr[i_skin]
			"grave", "ash":
				at = cr.v[i_cheek]
				n = nr[i_cheek]
			"crown", "bloom":
				if st.has("foot_pick"): at = (st.foot_pick as Callable).call()
				n = Vector3.UP
			"eyes":
				var sx := -1.0 if sk.eyes == "both" else float(sk.eye_side)
				at = Vector3(0.26 * sx, 0.06, 0.42)
			"fangs":
				at = (P.teeth_up as Geo).aabb().get_center() + Vector3(0, -0.02, 0.08)
			"broken", "chipped":
				at = cr.get_meta("hole") if cr.has_meta("hole") else cr.v[i_skin]
			"frost", "wax":
				if main: at = b.call("_mid", main, 0.6)
			"flies":
				var j: int = best.call(func(p: Vector3, nn: Vector3) -> float: return nn.y + p.y)
				at = cr.v[j] + Vector3(0, 0.12, 0)
				n = Vector3.UP
		if at != Vector3.INF:
			mk.append([id, at, n])

## the skull's genes as badges (ids sk_<gene>, named in SpecGenome.ACC_N or gene_name); from the genes alone, as the
## badges are made before the find is built
static func accents(sk: Dictionary) -> Array:
	var out := []
	match String(sk.skin):
		"gilt", "gold", "silver", "copper", "kintsugi", "glass", "nacre", "agate", "opal", "pyrite", "geode": out.append("sk_" + String(sk.skin))
	if sk.get("coins", false): out.append("sk_coins")
	if sk.get("diadem", false): out.append("sk_diadem")
	if sk.get("lantern", false): out.append("sk_lantern")
	if int(sk.get("pile", 0)) > 0: out.append("sk_pile")
	if sk.skin != "glass":
		if sk.crown or sk.eyes == "none": out.append("sk_bloom" if sk.bloom else "sk_crown")
		if sk.eyes != "none": out.append("sk_eyes")
		if sk.fangs != "none": out.append("sk_fangs")
		if sk.milk != "clear": out.append("sk_" + String(sk.milk))
		if sk.dmg == "broken": out.append("sk_broken")
		elif sk.dmg == "worn": out.append("sk_chipped")
	if sk.tone in ["grave", "ash"] and sk.skin == "bone": out.append("sk_" + String(sk.tone))
	if sk.moss != "none": out.append("sk_moss")
	if int(sk.trees) > 0: out.append("sk_trees")
	if sk.stream and sk.skin in WET_SKINS: out.append("sk_stream")
	if sk.roots: out.append("sk_roots")
	if int(sk.flies) > 0: out.append("sk_flies")
	return out

## a badge's name, where it depends on the genes (the nacre's fire, the trees' crown, how much moss)
static func gene_name(id: String, sk: Dictionary) -> String:
	match id:
		"sk_nacre": return ["red", "green", "blue", "violet"][int(float(sk.skin_k) * 997.0) % 4] + " nacre"
		"sk_trees": return {moss = "bonsai trees", leaves = "little trees", blossom = "trees in blossom", autumn = "autumn trees", bare = "bare trees"}.get(String(sk.tree_kind), "trees")
		"sk_moss": return "moss cap" if sk.moss == "cap" else "moss"
		"sk_bloom": return ["crimson and gold", "white and lilac", "pink and cream", "blue and silver", "orange and yellow"][int(sk.bloom_pal) % 5] + " bouquet"
		"sk_eyes": return "crystal eyes" if sk.eyes == "both" else "crystal eye"
		"sk_stream": return "wine from the eye" if sk.get("wine", false) else "spring from the eye"
		"sk_fangs": return "crystal teeth" if sk.fangs == "all" else "crystal fangs"
	return ""

## the skull with its rock, lying as it fell: on a slab, sunk deep in a lump, at the foot of a boulder rising beside it,
## or perched on a pillar of stone. The rock is the find's rock now; the shared layer (moss, lichen, mushrooms) grows
## over both, and a few crystals of its kind break out of the rock round the skull.
static func _on_rock(b: RefCounted, st: Dictionary, sk: Dictionary, cr: Geo, body: PackedVector3Array, mine: Array, crystal: Callable, lean: Callable, use_rock: Callable) -> Transform3D:
	var rng: Rng32 = b.rng
	var root: Node3D = b.root
	var soil: Color = b.dt.col
	var sk_pick: Callable = st.pick
	var sk_nrm: Callable = st.nrm
	var sk_hol: Array = st.hollows
	var sk_foot: Callable = st.get("foot_pick", sk_pick)
	var kind: String = sk.rock_kind
	var before := root.get_children()
	use_rock.call({slab = "slab", buried = "chunk", boulder = "chunk", perched = "small"}[kind])
	b.dt.col = soil
	# the rock's own build for the way it holds the skull (its loose crumbs moved with it)
	var rg: Geo = st.rock_geo
	var sd := float(sk.side)
	var rs: Vector3 = {slab = Vector3.ONE, buried = Vector3(1.15, 1.0, 1.1), boulder = Vector3(1.65, 1.5, 1.0), perched = Vector3(0.75, 1.6, 0.75)}[kind]
	# (a boulder stands behind the skull, a little to one side: the skull lies at its foot, in front)
	var roff := Vector3(-sd * 0.08, 0, -0.3) if kind == "boulder" else Vector3.ZERO
	for i in rg.v.size():
		rg.v[i] = rg.v[i] * rs + roff
	# (a crumbling rock's loose crumbs: none here — round a skull they read as a fuzz of hair)
	for n: Node in root.get_children():
		if not n in before and n != st.rock:
			n.free()
	var rbb := rg.aabb()
	var rn := rg.normals()
	var rtop: Array[int] = []
	var rhol := []
	for i in rg.v.size():
		if rn[i].y > 0.3 and rg.v[i].y > rbb.position.y + rbb.size.y * 0.3:
			rtop.append(i)
		if rg.col[i].r < 0.58 and rg.v[i].y > rbb.position.y + rbb.size.y * 0.25 and i % 2 == 0:
			rhol.append([rg.v[i], rn[i]])
	var rk_pick := func() -> Vector3: return rg.v[rtop[int(floor(rng.next() * rtop.size()))]]
	var at_v := {}
	for i in rg.v.size():
		at_v[rg.v[i]] = i
	var rk_nrm := func(w: Vector3) -> Vector3:
		if at_v.has(w): return rn[int(at_v[w])]
		var best := 0
		var bd := INF
		for i in rg.v.size():
			var dd := rg.v[i].distance_squared_to(w)
			if dd < bd:
				bd = dd
				best = i
		return rn[best]
	# the skull's pose: how it lies (upright, tipped, on its side, face up, chin down) and turned
	var a: Array = sk.lie_a
	var s := 0.7 if kind == "perched" else 0.78
	var bas := Basis(Vector3.UP, float(a[0])) * Basis(Vector3.BACK, float(a[1])) * Basis(Vector3.RIGHT, float(a[2])) * Basis.from_scale(Vector3.ONE * s)
	var low := INF
	var high := -INF
	for p in body:
		var y := (bas * p).y
		low = minf(low, y)
		high = maxf(high, y)
	var h := high - low
	var y0: float
	var x0 := 0.0 if kind == "perched" else float(sk.lie_x)
	var z0 := 0.1 if kind == "boulder" else float(sk.lie_z)
	# the ground under the skull: the rock's upper surface round where it lies (not its highest bump)
	var gy := 0.0
	var gn := 0
	for i in rtop:
		if Vector2(rg.v[i].x - x0, rg.v[i].z - z0).length() < 0.3:
			gy += rg.v[i].y
			gn += 1
	var rt := gy / gn if gn else rbb.position.y + rbb.size.y * 0.85
	match kind:
		"slab": y0 = rt - h * (0.2 + float(sk.sink) * 0.15)
		"buried": y0 = rt - h * (0.45 + float(sk.sink) * 0.15)
		"perched": y0 = rt - h * (0.1 + float(sk.sink) * 0.08)
		_:
			y0 = 0.0
	var T := Transform3D(bas, Vector3(x0, y0 - low, z0))
	if kind == "boulder":
		# the skull comes out of the rock's face like a fossil from its matrix: the back of the head inside the stone
		var zlo := INF
		var zhi := -INF
		for p in body:
			var q := bas * p
			zlo = minf(zlo, q.z)
			zhi = maxf(zhi, q.z)
		var cy := rbb.position.y + rbb.size.y * 0.5
		var zf := -INF
		for i in rg.v.size():
			if absf(rg.v[i].x - x0) < 0.3 and absf(rg.v[i].y - cy) < 0.3:
				zf = maxf(zf, rg.v[i].z)
		if zf == -INF: zf = rbb.position.z + rbb.size.z
		T.origin = Vector3(x0, cy - (low + high) * 0.5, zf - (zhi - zlo) * (0.3 + float(sk.sink) * 0.15) - zlo)
	var pv := Node3D.new()
	root.add_child(pv)
	pv.transform = T
	for n: Node in mine:
		n.reparent(pv, false)
	# what grows from now on: on the skull or on the rock, never inside the skull
	var Ti := T.affine_inverse()
	var cbb := cr.aabb().grow(0.03)
	var in_skull := func(w: Vector3) -> bool: return cbb.has_point(Ti * w)
	st.pick = func() -> Vector3:
		if rng.next() < 0.45: return T * (sk_pick.call() as Vector3)
		for k in 8:
			var q: Vector3 = rk_pick.call()
			if not in_skull.call(q): return q
		return T * (sk_pick.call() as Vector3)
	st.nrm = func(w: Vector3) -> Vector3:
		if in_skull.call(w): return (T.basis * (sk_nrm.call(Ti * w) as Vector3)).normalized()
		return rk_nrm.call(w)
	st.foot_pick = func() -> Vector3: return T * (sk_foot.call() as Vector3)
	var hol := rhol.filter(func(hh: Array) -> bool: return not in_skull.call(hh[0]))
	for hh: Array in sk_hol:
		hol.append([T * (hh[0] as Vector3), (T.basis * (hh[1] as Vector3)).normalized()])
	st.hollows = hol
	# butterflies: no landing on bone sunk into the stone; a few spots on the stone round the skull too
	var inside := func(w: Vector3) -> bool:
		var bi := 0
		var bd := INF
		for i in rg.v.size():
			var dd := rg.v[i].distance_squared_to(w)
			if dd < bd:
				bd = dd
				bi = i
		return (w - rg.v[bi]).dot(rn[bi]) < 0.01
	var stone := []
	for k in 30:
		var i: int = rtop[int(rng.next() * rtop.size())]
		if rn[i].y > 0.6 and Vector2(rg.v[i].x - T.origin.x, rg.v[i].z - T.origin.z).length() < 0.7 and not in_skull.call(rg.v[i]):
			stone.append([Ti * rg.v[i], (Ti.basis * rn[i]).normalized()])
	for n: Node in mine:
		if n is SpecButterfly.Fly:
			var f := n as SpecButterfly.Fly
			f.perch = f.perch.filter(func(q: Array) -> bool: return not inside.call(T * (q[0] as Vector3)) and (T.basis * (q[1] as Vector3)).normalized().y > 0.3)
			f.perch.append_array(stone)
			if not f.start_fly and inside.call(T * f.start_at) and f.perch.size():
				f.start_at = f.perch[0][0]
				f.start_n = f.perch[0][1]
	# crystals of its kind out of the rock round the skull
	var foot := Vector2(T.origin.x, T.origin.z)
	for k in int(sk.rock_x):
		for t in 10:
			var q: Vector3 = rk_pick.call()
			var dd := Vector2(q.x, q.z).distance_to(foot)
			if in_skull.call(q) or dd > 0.7: continue
			var f := (0.15 + rng.next() * 0.45) * (1.0 - dd / 0.9)
			crystal.call(f, q, lean.call((rk_nrm.call(q) as Vector3).lerp(Vector3.UP, 0.4), 0.6))
			break

## the teeth left in the jaw (lost: tooth numbers, offset for the lower jaw)
## which teeth of a jaw (n of them) are gone: fallen out, or (crystal = true) the ones grown over in crystal;
## the bone mesh leaves out both
	_stream_on(b, sk, T, rg, rn)
	return T

static func _gone(sk: Dictionary, n: int, off: int, crystal: bool) -> Dictionary:
	var fell := {}
	for x: int in sk.lost:
		fell[(x + off) % n] = true
	var cry := {}
	if sk.fangs == "all":
		for t in n: cry[t] = true
	elif sk.fangs == "some":
		# the empty sockets fill with crystal, and a few teeth more crack and give way to it
		cry = fell.duplicate()
		var fr := Rng32.new(int(sk.fang_seed) + off)
		for k in 2 + int(fr.next() * 4):
			cry[int(fr.next() * n)] = true
	if crystal:
		return cry
	cry.merge(fell)
	return cry

## crystals in the sockets of the teeth: out of the gum line, down (upper jaw) or up (lower), leaning a little forward
static func _fangs(b: RefCounted, sk: Dictionary, each: Array, which: Dictionary, upper: bool, crystal: Callable, lean: Callable) -> void:
	var rng: Rng32 = b.rng
	for t: int in which:
		var tooth := _shape(_copy(each[t]), sk.shape)
		var bb := tooth.aabb()
		var c := bb.get_center()
		var root := Vector3(c.x, bb.position.y + bb.size.y * (0.85 if upper else 0.15), c.z)
		var out := Vector3(c.x * 0.4, -1.0 if upper else 1.0, 0.3).normalized()
		crystal.call(0.05 + rng.next() * 0.15, root, lean.call(out, 0.35), 0.35)

static func _teeth(each: Array, gone: Dictionary) -> Geo:
	var g := Geo.new()
	for t in each.size():
		if gone.has(t): continue
		var piece: Geo = each[t]
		var b0 := g.v.size()
		g.v.append_array(piece.v)
		g.col.append_array(piece.col)
		for i in piece.idx:
			g.idx.append(i + b0)
	return g

## knocks: chips broken off the ridges (brow, cheek, nose, the arches), and on a broken skull a hole in the vault;
## the triangles there are taken away (the dark inside of the head shows), the bone round the break a little darker.
## Marks the vertices left with a face (meta "alive"), so nothing grows or stands on the missing bone.
static func _damage(cr: Geo, sk: Dictionary) -> void:
	if sk.dmg == "none":
		return
	var r := Rng32.new(int(sk.dmg_seed))
	var fn := FastNoiseLite.new()
	fn.seed = int(sk.dmg_seed)
	fn.frequency = 14.0
	var cuts := []   # [centre, radius]
	var ridge: Array[int] = []
	for i in cr.v.size():
		if cr.col[i].g > 0.78 and cr.v[i].z > -0.2: ridge.append(i)
	var nchip := 1 + int(r.next() * 2) if sk.dmg == "worn" else 2 + int(r.next() * 3)
	for k in nchip:
		var i: int = ridge[int(r.next() * ridge.size())] if ridge.size() else int(r.next() * cr.v.size())
		cuts.append([cr.v[i], 0.05 + r.next() * 0.05])
	if sk.dmg == "broken":
		# the hole: on the upper half of the head, away from the face
		var bb := cr.aabb()
		for t in 20:
			var i := int(r.next() * cr.v.size())
			var p := cr.v[i]
			if p.y > bb.position.y + bb.size.y * 0.5 and p.z < 0.25:
				cuts.append([p, 0.13 + r.next() * 0.09])
				cr.set_meta("hole", p)
				break
	var cut_at := func(p: Vector3) -> float:
		var best := INF
		for c: Array in cuts:
			best = minf(best, p.distance_to(c[0]) / (float(c[1]) * (1.0 + fn.get_noise_3dv(p) * 0.4)))
		return best
	# the vault is coarse: split the triangles near a break (twice) so its edge can be ragged
	for lvl in 2:
		_refine(cr, func(p: Vector3) -> bool: return cut_at.call(p) < 1.9)
	var nrm0 := cr.normals()
	var keep := PackedInt32Array()
	for t in cr.idx.size() / 3:
		var a := cr.v[cr.idx[t * 3]]
		var b := cr.v[cr.idx[t * 3 + 1]]
		var c := cr.v[cr.idx[t * 3 + 2]]
		if cut_at.call((a + b + c) / 3.0) < 1.0: continue
		keep.append(cr.idx[t * 3])
		keep.append(cr.idx[t * 3 + 1])
		keep.append(cr.idx[t * 3 + 2])
	# the bone's thickness along the broken edge: a wall turned in from every edge the break left open, pale fresh bone
	var uses := {}
	for t in keep.size() / 3:
		for e in 3:
			var a := keep[t * 3 + e]
			var b := keep[t * 3 + (e + 1) % 3]
			var key := Vector2i(mini(a, b), maxi(a, b))
			uses[key] = int(uses.get(key, 0)) + 1
	var n0 := cr.v.size()
	var inner := {}
	var wall := func(i: int) -> int:
		if not inner.has(i):
			inner[i] = cr.v.size()
			cr.v.append(cr.v[i] - nrm0[i] * (0.025 + fn.get_noise_3dv(cr.v[i] * 3.0) * 0.01))
			cr.col.append(Color(0.75, 0.5, 0.15))
		return inner[i]
	for t in keep.size() / 3:
		for e in 3:
			var a := keep[t * 3 + e]
			var b := keep[t * 3 + (e + 1) % 3]
			if int(uses[Vector2i(mini(a, b), maxi(a, b))]) != 1: continue
			if cut_at.call((cr.v[a] + cr.v[b]) * 0.5) > 1.5: continue   # (the scan's own openings stay as they are)
			var a2: int = wall.call(a)
			var b2: int = wall.call(b)
			# (the face's winding runs a → b, so the wall b → a → a2, b → a2 → b2 faces into the hole)
			keep.append_array([b, a, a2, b, a2, b2])
	cr.idx = keep
	var alive := PackedByteArray()
	alive.resize(cr.v.size())
	for i in keep: alive[i] = 1
	for i: int in inner: alive[int(inner[i])] = 0
	cr.set_meta("alive", alive)
	# round the break: a little darker, some dirt in it
	for i in cr.v.size():
		if i >= n0: continue
		var d: float = cut_at.call(cr.v[i])
		if d < 1.6:
			var c := cr.col[i]
			var w := 1.0 - smoothstep(1.0, 1.6, d)
			c.r *= 1.0 - w * 0.25
			c.b = maxf(c.b, w * 0.25)
			cr.col[i] = c

## split every triangle whose middle passes the test into four (midpoints shared, so no cracks open; a neighbour that
## is not split keeps its edge whole, leaving a T-joint — fine for bone seen from outside)
static func _refine(g: Geo, test: Callable) -> void:
	var mids := {}
	var mid := func(a: int, b: int) -> int:
		var key := Vector2i(mini(a, b), maxi(a, b))
		if not mids.has(key):
			mids[key] = g.v.size()
			g.v.append((g.v[a] + g.v[b]) * 0.5)
			g.col.append(g.col[a].lerp(g.col[b], 0.5))
		return mids[key]
	var out := PackedInt32Array()
	for t in g.idx.size() / 3:
		var a := g.idx[t * 3]
		var b := g.idx[t * 3 + 1]
		var c := g.idx[t * 3 + 2]
		if not test.call((g.v[a] + g.v[b] + g.v[c]) / 3.0):
			out.append_array([a, b, c])
			continue
		var ab: int = mid.call(a, b)
		var bc: int = mid.call(b, c)
		var ca: int = mid.call(c, a)
		out.append_array([a, ab, ca, ab, b, bc, ca, bc, c, ab, bc, ca])
	g.idx = out

static func _alive(cr: Geo, i: int) -> bool:
	return not cr.has_meta("alive") or (cr.get_meta("alive") as PackedByteArray)[i] == 1

## moss on the head, as on the bone of an old grave: patches in the hollows and on the crown, or a cap over the whole
## vault and down one side (the face left bare but for the brow); little trees standing in it, their crowns green
## puffs of the same moss
static func _forest(b: RefCounted, sk: Dictionary, cr: Geo, nr: PackedVector3Array, gene: Dictionary) -> void:
	if sk.moss == "none":
		return
	var root: Node3D = b.root
	var r := Rng32.new(int(sk.moss_seed))
	var bb := cr.aabb()
	var ytop := bb.position.y + bb.size.y
	var cap: bool = sk.moss == "cap"
	var edge := FastNoiseLite.new()
	edge.seed = int(sk.moss_seed)
	edge.frequency = 4.0
	var tilt := (r.next() - 0.5) * 0.5
	var near := PackedByteArray()
	near.resize(cr.v.size())
	for i in cr.v.size():
		near[i] = 1 if _alive(cr, i) and nr[i].y > -0.3 else 0
	# where moss grows: the cap reaches down to the brow and over one side, ragged at its edge
	var where := func(p: Vector3) -> Vector2:
		var line := ytop - bb.size.y * (0.42 if cap else 0.2) + p.x * tilt + edge.get_noise_3dv(p) * 0.09
		if p.z > 0.3 and p.y < ytop - bb.size.y * 0.3: return Vector2(-1, 0)   # (not over the face)
		# (not over the gold leaf: moss keeps to the bare side of a gilt skull)
		if sk.skin == "gilt":
			var gd: Array = sk.gilt_dir
			if (p + Vector3(0, -0.1, 0)).normalized().dot(Vector3(float(gd[0]), float(gd[1]), float(gd[2])).normalized()) > 0.85 - float(sk.skin_k) * 0.7 - 0.3: return Vector2(-1, 0)
		return Vector2(p.y - line, 0)
	var pool := _sample(cr, nr, near, where, 1600, r)
	if pool.is_empty():
		return
	var pal: Dictionary = gene.get("palette", {})
	# (greener than the rock's moss: bright velvet, as on the references; now and then golden or rusty)
	var tint: Color = [Color(0.62, 1.05, 0.42), Color(0.5, 0.95, 0.4), Color(0.85, 1.0, 0.45), Color(1.05, 0.75, 0.4)][int(Stones.pick_w([[0, 4.0], [1, 3.0], [2, 2.0], [3, 0.6]], r))]
	var spots := []
	var moss_at := []
	var n := 14 + int(r.next() * 6) if cap else 2 + int(r.next() * 4)
	for k in n:
		var c0: Vector3 = (pool[int(r.next() * pool.size())] as Array)[0]
		var rad := (0.2 + r.next() * 0.1) if cap else (0.06 + r.next() * 0.07)
		var top := SpecPlants.cushion(root, r, pool, c0, rad, 0.02 + r.next() * 0.015, tint)
		var on: Array = top if top.size() > 8 else pool
		# (short and dense: a velvet carpet, not tufts)
		SpecPlants.scatter(root, r, on, c0, rad * 0.95, (500 + int(r.next() * 200)) if cap else 240, "moss", 0.9 + r.next() * 0.4, 0.15, tint)
		if r.next() < 0.4:
			SpecPlants.scatter(root, r, on, c0, rad * 0.6, 4 + int(r.next() * 10), "grass", 1.2 + r.next() * 0.8, 0.6, Color(0.9, 1.0, 0.8))
		spots.append([c0, rad])
		for q2 in range(0, on.size(), 8): moss_at.append(on[q2])
		if k == 0: (sk.marks as Array).append(["sk_moss", c0, Vector3.UP])
	# trees only where no crystals grow (a span clear of every crystal's foot, and of each other)
	var clear := func(p: Vector3) -> bool:
		for t: Array in sk.taken:
			if p.distance_to(t[0]) < 0.17: return false
		return true
	for k in int(sk.trees):
		var q: Array = pool[int(r.next() * pool.size())]
		for t in 30:
			if clear.call(q[0]): break
			q = pool[int(r.next() * pool.size())]
		if not clear.call(q[0]): continue
		(sk.taken as Array).append([q[0], q[1]])
		_tree(root, r, q[0], q[1], tint, String(sk.tree_kind))
		(sk.marks as Array).append(["sk_trees", (q[0] as Vector3) + (q[1] as Vector3) * 0.2, q[1]])
	# (the moss is taken only now: trees stand in it, a bone badge does not point into it)
	(sk.taken as Array).append_array(moss_at)

## a little tree: a gnarled trunk and branches (the generator's branching tube), each branch end a puff of moss for
## its crown — like the flocked trees of a model railway, grown out of the skull
static func _tree(root: Node3D, r: Rng32, at: Vector3, n: Vector3, tint: Color, kind := "moss") -> void:
	var h := 0.4 + r.next() * 0.25
	# a thin trunk, forking high up into a few branches (a tree on a rock, like a little pine on a cliff)
	var sk := SpecBranch.skeleton(r, {r0 = 0.013 + r.next() * 0.006, len0 = h * 0.7, levels = 2, kids = [2, 4], kids2 = [1, 2], kid_r = 0.6,
		kid_len = 0.45, spread = 0.95, gnarl = 0.5, up = 0.35, taper = 0.4})
	var hold := Node3D.new()
	root.add_child(hold)
	hold.transform = Transform3D(Basis(U.quat_to(Vector3.UP, n.lerp(Vector3.UP, 0.65).normalized())) * Basis(Vector3.UP, r.next() * TAU), at - n * 0.01)
	var bark := bark_mat(r)
	var to := {m = 7, sub = 2, lump = 0.0, ridge = 0.1, flat = 1.0, seed = int(r.next() * 1000)}
	for k in sk.size():
		U.mesh(SpecBranch.tube(sk[k], to, k == 0).fill_color(Color(1, 1, 1)), bark, hold)
	crown(hold, r, sk, kind, 1.0)
	# where it roots: a handful of earth and moss on the bone
	mound(root, r, at, n, 0.05)

## the bark: a scan from three sides, each tree its own wood (dark, grey, red-brown)
static func bark_mat(r: Rng32, kind := "sakura") -> ShaderMaterial:
	# scans (Poly Haven, CC0): smooth cherry bark with its bands of lenticels for the little trees, deep-furrowed oak
	# for the big tree and its roots
	var m := ShaderMaterial.new()
	m.shader = BARK
	var nm := "sakura_bark" if kind == "sakura" else "jolcham_oak_bark_01"
	m.set_shader_parameter("bark_diff", load("res://assets/textures/%s/%s_diff_1k.jpg" % [nm, nm]))
	m.set_shader_parameter("bark_disp", load("res://assets/textures/%s/%s_disp_1k.jpg" % [nm, nm]))
	m.set_shader_parameter("scale", 14.0 if kind == "sakura" else 6.0)
	m.set_shader_parameter("tint", Color(1, 1, 1).lerp(Color(0.85, 0.8, 0.75), r.next()))
	return m

## a handful of earth with a little moss on it, where a tree or a toadstool roots on the bone
static func mound(root: Node3D, r: Rng32, at: Vector3, n: Vector3, s: float) -> void:
	var earth := StandardMaterial3D.new()
	earth.albedo_color = Color(0.13, 0.095, 0.07)
	earth.roughness = 1.0
	var t := (n.cross(Vector3.RIGHT) if absf(n.x) < 0.9 else n.cross(Vector3.FORWARD)).normalized()
	var bt := n.cross(t)
	for k in 9 + int(r.next() * 6):
		var a := r.next() * TAU
		var d := sqrt(r.next()) * s
		var g := s * (0.25 + r.next() * 0.4) * (1.0 - d / s * 0.5)
		var p := at + (t * cos(a) + bt * sin(a)) * d + n * g * 0.15
		U.mesh(RockKit.crumble(r, g, Vector3(1.3, 0.55, 1.0)), earth, root, p, Basis(U.quat_to(Vector3.UP, n)) * Basis(Vector3.UP, r.next() * 6.3))
	# moss creeping over the top of it
	var pool := []
	for k in 60:
		var a := r.next() * TAU
		var d := sqrt(r.next()) * s * 0.9
		pool.append([at + (t * cos(a) + bt * sin(a)) * d + n * s * 0.22 * (1.0 - d / s), n])
	SpecPlants.scatter(root, r, pool, at, s * 1.2, 70, "moss", 0.8, 0.2, Color(0.6, 1.0, 0.42))

## the crown of a tree on its branch ends, by kind: a flocked moss puff (as the reference's model trees), leaves,
## the crown of a tree on its branch ends: flocked puffs of the scanned moss (each a cloud of real moss sprigs, dense,
## nothing floating), tinted by kind — green leaves, autumn (puffs of orange, red and yellow), blossom (pale pink puffs
## with flowers and buds on their surface), moss (the yellow-green of the moss itself); bare has none
static func crown(hold: Node3D, r: Rng32, sk: Array, kind: String, size: float) -> void:
	if kind == "bare": return
	var autumn := [Color(1.4, 0.55, 0.15), Color(1.35, 0.25, 0.1), Color(1.3, 0.9, 0.2), Color(1.2, 0.4, 0.12)]
	var bt := SpecBloom.batch()
	var bloom_col: Color = [Color(0.95, 0.5, 0.65), Color(0.98, 0.9, 0.92), Color(0.85, 0.3, 0.5)][int(r.next() * 3.0)]
	for br: Dictionary in sk:
		if int(br.depth) < 1: continue
		var pts: Array = br.pts
		var tip: Vector3 = pts[pts.size() - 1]
		var rad := (0.045 + r.next() * 0.04) * size
		var puff := []
		for k in 140:
			var d := Vector3(r.next() - 0.5, (r.next() - 0.5) * 0.35, r.next() - 0.5).normalized()
			puff.append([tip + Vector3(d.x * rad * 1.4, d.y * rad * 0.6 + rad * 0.3, d.z * rad * 1.4), (d + Vector3.UP).normalized()])
		var tint: Color
		match kind:
			"leaves": tint = Color(0.55, 0.95, 0.4) * (0.75 + r.next() * 0.3)
			"autumn": tint = autumn[int(r.next() * 4.0)] * (0.85 + r.next() * 0.25)
			# (sakura: the puffs mostly blossom-pink, a few still green)
			"blossom": tint = Color(0.55, 0.9, 0.4) * (0.75 + r.next() * 0.25)
			_: tint = Color(0.6, 1.0, 0.42) * (0.85 + r.next() * 0.25)
		var n := int((260 + int(r.next() * 120)) * size)
		SpecPlants.scatter(hold, r, puff, tip, rad * 2.5, n, "moss", 1.8 + r.next() * 0.8, 0.5, tint)
		if kind == "blossom":
			# flowers and buds sitting on the puff's surface, facing out
			# (sakura: the green puff thick with flowers)
			for f in int((26 + int(r.next() * 14)) * size):
				var q: Array = puff[int(r.next() * puff.size())]
				var face: Vector3 = ((q[0] as Vector3) - tip).normalized().lerp(Vector3.UP, 0.4).normalized()
				var at: Vector3 = (q[0] as Vector3) + face * rad * 0.15
				SpecBloom.head(bt, r, "bud" if r.next() < 0.25 else "cosmos", at, face, rad * (0.55 + r.next() * 0.25), bloom_col * (0.9 + r.next() * 0.15), Color(0.95, 0.75, 0.3))
	if bt.size(): SpecBloom.flush(bt, hold)

static func _seg_d(p: Vector3, a: Vector3, b: Vector3) -> Vector2:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return Vector2(p.distance_to(a + ab * t), t)

## the breach: the bone gave way along a line (down one side toward the temple, or along the crest of the head) and
## small crystals crowd out of it in islands — dense along its spine, broken into patches toward the rim, a few strays
## beyond, bare bone between — soil at their feet. Returns the biggest crystal.
static func _breach(b: RefCounted, st: Dictionary, sk: Dictionary, cr: Geo, nr: PackedVector3Array, earth_m: Material, crystal: Callable, lean: Callable) -> MeshInstance3D:
	var rng: Rng32 = b.rng
	var bb := cr.aabb()
	var lo := bb.position
	var sz := bb.size
	var sd := float(sk.side)
	var mid := Vector3(0, lo.y + sz.y * 0.4, 0)
	var A: Vector3
	var B: Vector3
	var R0: float
	var R1: float
	if sk.breach == "crest":
		# a crest along the top of the head, front to back
		var z0 := lerpf(0.22, 0.05, float(sk.crown_at))
		A = Vector3(sd * 0.03, lo.y + sz.y, z0)
		B = Vector3(sd * 0.05, lo.y + sz.y * 0.86, z0 - 0.42)
		R0 = sz.x * 0.27
		R1 = sz.x * 0.21
	else:
		# from the top of the head down the side to the temple, above the eye
		A = Vector3(sd * sz.x * 0.16, lo.y + sz.y, lerpf(0.12, -0.12, float(sk.crown_at)))
		B = Vector3(sd * sz.x * 0.47, lo.y + sz.y * 0.42, 0.25)
		R0 = sz.x * 0.36
		R1 = sz.x * 0.17
	if sk.bloom:
		# a bouquet spills wider than a crown of crystals: over the crown and down the side
		R0 *= 1.35
		R1 *= 1.6
	var ia := _snap(cr, nr, A, mid)
	A = cr.v[ia]
	B = cr.v[_snap(cr, nr, B, mid)]
	var fn := FastNoiseLite.new()
	fn.seed = int(rng.next() * 100000)
	fn.frequency = 5.0
	# islands: crystals only where this noise allows, more of it toward the rim
	var isl := FastNoiseLite.new()
	isl.seed = int(rng.next() * 100000)
	isl.frequency = 9.0
	# a few strays: little clumps beyond the breach
	var strays := []
	for k in 2 + int(rng.next() * 4):
		var t := rng.next()
		var p := A.lerp(B, t) + Vector3(rng.next() - 0.5, rng.next() - 0.5, rng.next() - 0.5).normalized() * lerpf(R0, R1, t) * (1.2 + rng.next() * 0.6)
		strays.append([cr.v[_snap(cr, nr, p, mid)], 0.035 + rng.next() * 0.04])
	# the breach's weight at any point of the bone: 1 on its spine, 0 at its rim, holes between islands -1
	var wfn := func(p: Vector3) -> Vector2:
		var sg := _seg_d(p, A, B)
		var R := lerpf(R0, R1, sg.y) * (1.0 + fn.get_noise_3dv(p) * 0.3)
		var u := 1.0 - sg.x / R
		var w := u * lerpf(1.0, 0.7, sg.y)
		# broken into islands toward the rim (the spine stays crowded)
		if u > 0.0 and isl.get_noise_3dv(p) * 0.5 + 0.5 + u * 0.9 < 0.62:
			w = -1.0
		for s: Array in strays:
			var su := 1.0 - p.distance_to(s[0]) / float(s[1])
			if su > 0.0: w = maxf(w, su * 0.35)
		return Vector2(w, u)
	var near := PackedByteArray()
	near.resize(cr.v.size())
	for i in cr.v.size():
		var p := cr.v[i]
		if nr[i].dot(p - mid) < 0.0:
			continue
		var wu: Vector2 = wfn.call(p)
		near[i] = 1 if wu.y > -0.4 or wu.x > 0.0 else 0
		# soil follows the crystals, a little beyond them (none in the bare gaps between islands)
		var soil := smoothstep(-0.25, 0.15, wu.x) if wu.x > -0.9 else 0.0
		if soil > 0.0:
			var c := cr.col[i]
			c.b = maxf(c.b, soil * (0.7 + rng.next() * 0.3))
			cr.col[i] = c
	# the vault is a coarse mesh: crystals stand anywhere on its triangles, not only on their corners
	var pts := _sample(cr, nr, near, wfn, int(sk.crown_n) * 3, rng, sk.reserve)
	if pts.is_empty():
		return null
	(sk.taken as Array).append_array(pts)
	st.foot_pick = func() -> Vector3:
		var q: Array = pts[int(floor(rng.next() * pts.size()))]
		return (q[0] as Vector3) + (q[1] as Vector3) * 0.02
	b.dt.col = Color(0.11, 0.075, 0.05)   # the crystals' feet sit in soil, not in bone
	b.dt.local = true
	b.dt.h = 0.08 + rng.next() * 0.08
	b.dt.a = 0.3
	var main: MeshInstance3D = null
	var best := 0.0
	var spine := (B - A).normalized()
	for k in mini(int(sk.crown_n), pts.size()):
		var q: Array = pts[k]
		var p: Vector3 = q[0]
		var n: Vector3 = q[1]
		var w: float = q[2]
		var f := clampf(pow(w, 1.2) * (0.15 + rng.next() * 0.6), 0.0, 1.0) * 0.6
		# now and then a bigger point among the small ones
		if rng.next() < 0.03: f = 0.45 + rng.next() * 0.25
		var off := p - A - spine * spine.dot(p - A)
		var out := (n + off.normalized() * 0.2).normalized() if off.length() > 0.001 else n
		var cm: MeshInstance3D = crystal.call(f, p - n * 0.01, lean.call(out, 0.9))
		if f > best:
			best = f
			main = cm
	if sk.earth:
		_earth(b, pts, earth_m, 90 + int(rng.next() * 70))
	return main

## random points on the triangles touching the marked vertices, by area; each kept if wfn(p).x > 0: [point, normal, weight]
static func _sample(cr: Geo, nr: PackedVector3Array, near: PackedByteArray, wfn: Callable, n: int, rng: Rng32, reserve: Array = []) -> Array:
	var tris := PackedInt32Array()
	var acc := PackedFloat32Array()
	var tot := 0.0
	for t in cr.idx.size() / 3:
		var a := cr.idx[t * 3]
		var b := cr.idx[t * 3 + 1]
		var c := cr.idx[t * 3 + 2]
		if near[a] + near[b] + near[c] == 0: continue
		tot += (cr.v[b] - cr.v[a]).cross(cr.v[c] - cr.v[a]).length() * 0.5
		tris.append(t)
		acc.append(tot)
	var out := []
	if tris.is_empty(): return out
	for k in n * 4:
		if out.size() >= n: break
		var ti := tris[mini(acc.bsearch(rng.next() * tot), tris.size() - 1)]
		var r1 := sqrt(rng.next())
		var r2 := rng.next()
		var ia := cr.idx[ti * 3]
		var ib := cr.idx[ti * 3 + 1]
		var ic := cr.idx[ti * 3 + 2]
		var wa := 1.0 - r1
		var wb := r1 * (1.0 - r2)
		var wc := r1 * r2
		var p := cr.v[ia] * wa + cr.v[ib] * wb + cr.v[ic] * wc
		var w: float = (wfn.call(p) as Vector2).x
		if w <= 0.0: continue
		var kept := false
		for rv: Array in reserve:
			if p.distance_to(rv[0]) < float(rv[1]): kept = true
		if kept: continue
		out.append([p, (nr[ia] * wa + nr[ib] * wb + nr[ic] * wc).normalized(), w])
	return out

## crystals growing out of the eye sockets: a druse lining the socket, points reaching out of it toward the viewer,
## the biggest at the bottom of the socket where the soil gathered
static func _eyes(b: RefCounted, st: Dictionary, sk: Dictionary, cr: Geo, nr: PackedVector3Array, earth_m: Material, crystal: Callable, lean: Callable) -> MeshInstance3D:
	var rng: Rng32 = b.rng
	var main: MeshInstance3D = null
	var best := 0.0
	var which: Array = [-1.0, 1.0] if sk.eyes == "both" else [float(sk.eye_side)]
	for sx: float in which:
		var cen := Vector3(sx * 0.26, 0.06, 0.36)
		var spot: Array[int] = []
		for i in cr.v.size():
			var p := cr.v[i]
			var d := Vector2((p.x - cen.x) / 0.11, (p.y - cen.y) / 0.1)
			# inside the socket: within its outline, behind the rim, on the walls (not their back side)
			if d.length() < 1.0 and p.z > 0.14 and p.z < 0.44 and cr.col[i].r < 0.92 and nr[i].dot(cen - p) > -0.2 and _alive(cr, i):
				spot.append(i)
		if spot.is_empty(): continue
		# (with no breach, the shared layer's little pyrite cubes sit in the socket)
		if not st.has("foot_pick"):
			st.foot_pick = func() -> Vector3:
				var j: int = spot[int(floor(rng.next() * spot.size()))]
				return cr.v[j] + nr[j] * 0.01
		for i in spot:
			var c := cr.col[i]
			c.b = maxf(c.b, 0.5 + rng.next() * 0.4)
			cr.col[i] = c
		var n := int(float(sk.eye_n) * (0.75 + rng.next() * 0.5))
		# anywhere on the socket's walls, not only on its corners
		var near := PackedByteArray()
		near.resize(cr.v.size())
		for i in spot: near[i] = 1
		var inside := func(p: Vector3) -> Vector2:
			var d := Vector2((p.x - cen.x) / 0.11, (p.y - cen.y) / 0.1).length()
			return Vector2(1.0 - d if p.z > 0.12 and p.z < 0.4 else -1.0, 0.0)
		var pts := _sample(cr, nr, near, inside, n, rng, sk.reserve)
		(sk.taken as Array).append_array(pts)
		for q: Array in pts:
			var p: Vector3 = q[0]
			var nn: Vector3 = q[1]
			# lower in the socket, bigger; all reach out of it
			var low := clampf((cen.y + 0.1 - p.y) / 0.2, 0.0, 1.0)
			var f := clampf((0.22 + low * 0.3) * (0.6 + rng.next() * 0.5), 0.0, 0.6)
			# splayed like a bouquet out of the socket: away from a point deep behind it
			var out := ((p - (cen + Vector3(0, -0.02, -0.22))).normalized() * 0.75 + nn * 0.25).normalized()
			var cm: MeshInstance3D = crystal.call(f, p - nn * 0.005, lean.call(out, 0.7))
			if f > best:
				best = f
				main = cm
		if sk.earth and pts.size():
			_earth(b, pts, earth_m, 20 + int(rng.next() * 20))
	return main

## loose earth at the feet of the crystals
## (at: [point, normal, ...])
static func _earth(b: RefCounted, at: Array, earth_m: Material, n: int) -> void:
	var rng: Rng32 = b.rng
	for k in n:
		var q: Array = at[int(rng.next() * at.size())]
		var p: Vector3 = q[0]
		var nn: Vector3 = q[1]
		var g := 0.01 + pow(rng.next(), 2.0) * 0.04
		# (cut as finely, in pixels, as the biggest crumb at 16: a small one needs fewer triangles to look the same)
		var dt := CRUMB_DETAIL if CRUMB_DETAIL > 0 else 16 if not SpecUtil.fast else clampi(ceili(16.0 * g / 0.05), 5, 16)
		if not SpecUtil.fast:
			U.mesh(RockKit.crumble(rng, g, Vector3(1.3, 0.6, 1.0), dt), earth_m, b.root, p + nn * g * 0.2, Basis(U.quat_to(Vector3.UP, nn)) * Basis(Vector3.UP, rng.next() * 6.3))
			continue
		# straight into one heap (as SpecUtil.batch would glue them, without a mesh of its own for each crumb first)
		var src := RockKit.crumb_shape(rng, Vector3(1.3, 0.6, 1.0), dt)
		var t := Transform3D(Basis(U.quat_to(Vector3.UP, nn)) * Basis(Vector3.UP, rng.next() * 6.3), p + nn * g * 0.2)
		# (not SurfaceTool.append_from: it reads the crumb's mesh back, which on the build thread waits for the renderer)
		var heap: Geo = earth_m.get_meta("heap") if earth_m.has_meta("heap") else Geo.new()
		earth_m.set_meta("heap", heap)
		var base := heap.v.size()
		heap.v.append_array(t.scaled_local(Vector3(g, g, g)) * src.v)
		heap.own_n.append_array(Transform3D(t.basis) * src.own_n)
		heap.col.append_array(src.col)
		var at_i := heap.idx.size()
		heap.idx.append_array(src.idx)
		for j in range(at_i, heap.idx.size()): heap.idx[j] += base

## the earth heaped by _earth, as one mesh
static func _earth_done(b: RefCounted, earth_m: Material) -> void:
	if not earth_m.has_meta("heap"): return
	var heap: Geo = earth_m.get_meta("heap")
	earth_m.remove_meta("heap")
	var mi := U.mesh(heap, earth_m, b.root)
	mi.set_meta("box", heap.aabb())

## the bone's vertex nearest a point, on the outside of the head
static func _snap(cr: Geo, nr: PackedVector3Array, w: Vector3, mid: Vector3) -> int:
	var bi := 0
	var bd := INF
	for i in cr.v.size():
		var dd := cr.v[i].distance_squared_to(w)
		if dd < bd and nr[i].dot(w - mid) > 0.0 and _alive(cr, i):
			bd = dd
			bi = i
	return bi

## held up to the viewer: the face toward the camera (the card sways it about its front), the top of the head tipped
## forward so the crown shows
static func lean(b: RefCounted, gene: Dictionary) -> void:
	var sk := genes(int(gene.get("shroom_seed", 1)), gene.get("skull", {}))
	var root: Node3D = b.root
	root.set_meta("face", true)
	var pv := Node3D.new()
	var kids := root.get_children()
	root.add_child(pv)
	pv.basis = lean_basis(sk)
	for k: Node in kids:
		k.reparent(pv, false)
	var grown: Dictionary = b.grown
	for id: String in grown:
		for m: Array in grown[id]:
			m[0] = pv.basis * (m[0] as Vector3)
			m[1] = pv.basis * (m[1] as Vector3)

## a tapering tube along points (r0 at the first, r1 at the last), m sides; vertex colour white
static func _taper(pts: Array, r0: float, r1: float, m := 6) -> Geo:
	var g := Geo.new()
	var n := pts.size()
	var nrm := Vector3.UP
	for k in n:
		var a: Vector3 = pts[maxi(k - 1, 0)]
		var b: Vector3 = pts[mini(k + 1, n - 1)]
		var tg := (b - a).normalized()
		nrm = (nrm - tg * nrm.dot(tg)).normalized()
		if nrm.length_squared() < 0.5: nrm = tg.cross(Vector3.RIGHT).normalized()
		var bi := tg.cross(nrm)
		var r := lerpf(r0, r1, float(k) / maxf(1.0, n - 1.0))
		for j in m + 1:
			var w := float(j) / m * TAU
			g.v.append((pts[k] as Vector3) + (nrm * cos(w) + bi * sin(w)) * r)
	for k in n - 1:
		for j in m:
			var a2 := k * (m + 1) + j
			var b2 := a2 + m + 1
			g.idx.append_array([a2, b2, a2 + 1, b2, b2 + 1, a2 + 1])
	g.fill_color(Color(1, 1, 1))
	return g

## the nearest live vertex of any of the bones to a point: [index of the bone, vertex]
static func _near(bones: Array, nrs: Array, w: Vector3) -> Array:
	var bi := 0
	var vi := 0
	var bd := INF
	for k in bones.size():
		var g: Geo = bones[k]
		for i in range(0, g.v.size(), 2):
			var dd := g.v[i].distance_squared_to(w)
			if dd < bd and _alive(g, i):
				bd = dd
				bi = k
				vi = i
	return [(bones[bi] as Geo).v[vi], (nrs[bi] as PackedVector3Array)[vi]]

## which way is down for the skull once it is posed (on its rock, held up to the viewer): drips and water run that way
static func down_of(sk: Dictionary) -> Vector3:
	var bas := lean_basis(sk)
	if sk.show == "rock":
		var a: Array = sk.lie_a
		bas = bas * Basis(Vector3.UP, float(a[0])) * Basis(Vector3.BACK, float(a[1])) * Basis(Vector3.RIGHT, float(a[2]))
	return (bas.inverse() * Vector3.DOWN).normalized()

## molten metal poured over the head and set: a few broad tongues from high on it (the crown's sides, the brow) run down
## over the bone (SpecSurf: on its real surface), thickening as they go, some merging, each ending in a heavy lobe — or,
## where it reached an edge, a tear hanging from it. They read against the skull cast in the same metal by being thick
## (they cast their own shading), polished and a touch brighter (shaders/metal_run.gdshader). A rare one (its own draw)
## is not cold yet: the tongues' feet glow, and a drop now and then falls slowly from a hanging tear.
static func _drips(b: RefCounted, sk: Dictionary, bones: Array, nrs: Array) -> void:
	var r := Rng32.new(int(sk.skin_seed) + 3)
	var down := down_of(sk)
	var mt: Array = METALS[String(sk.skin)]
	var mcol: Color = mt[0]
	var hot := Rng32.new(int(sk.skin_seed) * 5 + 77).next() < 0.15
	var surf := SpecSurf.new()
	for k in bones.size(): surf.add(bones[k], nrs[k])
	var mat := ShaderMaterial.new()
	mat.shader = METAL_RUN
	mat.set_shader_parameter("col", Vector3(mcol.r, mcol.g, mcol.b))
	mat.set_shader_parameter("rough", 0.14)
	mat.set_shader_parameter("hot", 1.0 if hot else 0.0)
	mat.set_shader_parameter("phase", r.next() * 10.0)
	# where they start: high on the head, facing up, spread apart
	var g0: Geo = bones[0]
	var nr0: PackedVector3Array = nrs[0]
	var top := -INF
	var bot := INF
	for i in range(0, g0.v.size(), 5):
		var hgt := -g0.v[i].dot(down)
		top = maxf(top, hgt)
		bot = minf(bot, hgt)
	# (facing the viewer once the skull is posed: a skull turned aside keeps its runs on the side we see)
	var bas := pose_basis(sk)
	var cand := []
	for i in range(0, g0.v.size(), 3):
		var hgt := -g0.v[i].dot(down)
		# (the forehead, the temples, the brow: below the crown, which a bouquet or crystals often cover, and on the side
		# the viewer sees)
		if hgt < top - (top - bot) * 0.12 and hgt > top - (top - bot) * 0.55 and (bas * nr0[i]).z > 0.15 and nr0[i].dot(down) < 0.2 and _alive(g0, i):
			cand.append(g0.v[i])
	if cand.is_empty(): return
	var starts := []
	var want := 5 + int(r.next() * 4)
	for t in 60:
		if starts.size() >= want: break
		var q: Vector3 = cand[int(r.next() * cand.size())]
		var ok := true
		for sp: Vector3 in starts:
			if sp.distance_to(q) < 0.12: ok = false
		if ok: starts.append(q)
	var hold := Node3D.new()
	b.root.add_child(hold)
	var tears := 0
	var hung := []
	for k in starts.size():
		var res := surf.run(starts[k], down, 0.014, 0.25 + pow(r.next(), 0.7) * 0.55, Vector3.ZERO, 0.6)
		if res.is_empty(): continue
		var rr: Array = (res.runs as Array)[0]
		if (rr[0] as Array).size() < 5: continue
		var sm := _smooth_run(rr[0], rr[1], 0.006)
		var pts := []
		var ns := []
		for q: Vector3 in sm[0]:
			var cp := surf.closest(q)
			pts.append(cp[0] if cp.size() else q)
			ns.append(cp[1] if cp.size() else -down)
		var w0 := 0.022 + r.next() * 0.012
		var w1 := w0 * (1.7 + r.next() * 0.7)
		_tongue(hold, pts, ns, w0, w1, surf, mat, r.next() * 5.0)
		var e: Vector3 = pts[pts.size() - 1]
		var en: Vector3 = ns[ns.size() - 1]
		# (one tear to an edge: runs reaching the same edge close together gather into one, not a bunch)
		var near_tear := false
		for hp: Vector3 in hung:
			if hp.distance_to(e) < w1 * 3.0: near_tear = true
		if ((res.drops as Array).size() or res.pour) and not near_tear and hung.size() < 4:
			hung.append(e)
			# it reached an edge: a tear hanging from it, its neck still joined to the run
			var tl := w1 * (2.0 + r.next() * 1.5)
			var drop := MeshInstance3D.new()
			var dm := SphereMesh.new()
			dm.radius = 0.5
			dm.height = 1.0
			dm.radial_segments = 16
			dm.rings = 10
			drop.mesh = dm
			drop.material_override = mat
			drop.transform = Transform3D(Basis(U.quat_to(Vector3.UP, -down)) * Basis.from_scale(Vector3(w1 * 1.7, tl, w1 * 1.7)), e + down * tl * 0.38 + en * w1 * 0.3)
			hold.add_child(drop)
			if hot and tears < 2:
				tears += 1
				var dr := Drip.new()
				dr.setup(Rng32.new(int(sk.skin_seed) + 50 + k), down, w1 * 1.2, true, mat)
				dr.position = e + down * tl * 0.85
				hold.add_child(dr)

## a tongue of set metal along a run on the surface (pressed onto it): thick and domed, its head rounded, widening to
## a heavy lobe at its foot. UV.x across, UV.y along; COLOR.r 0 at its head .. 1 at its foot (shaders/metal_run.gdshader)
static func _tongue(parent: Node3D, path: Array, ns: Array, w0: float, w1: float, surf: SpecSurf, mat: Material, v0: float) -> void:
	var m := 10
	var v := PackedVector3Array()
	var nm := PackedVector3Array()
	var uv := PackedVector2Array()
	var cl := PackedColorArray()
	var idx := PackedInt32Array()
	var n := path.size()
	var total := 0.0
	for k in range(1, n): total += (path[k] as Vector3).distance_to(path[k - 1])
	var d := 0.0
	for k in n:
		if k: d += (path[k] as Vector3).distance_to(path[k - 1])
		var f := d / maxf(total, 0.001)
		var a: Vector3 = path[maxi(k - 1, 0)]
		var c: Vector3 = path[mini(k + 1, n - 1)]
		var tg := (c - a).normalized()
		var out: Vector3 = ns[k]
		var side := tg.cross(out).normalized()
		if side.length_squared() < 0.5: side = Vector3.RIGHT
		# the profile: a rounded head, swelling down its length, the lobe at the foot rounded off
		var wd := lerpf(w0, w1, pow(f, 1.5)) * (1.0 + 0.12 * sin(d * 60.0 + v0))
		wd *= sqrt(smoothstep(0.0, 0.06, f))
		if f > 0.86: wd *= sqrt(maxf(0.0, 1.0 - pow((f - 0.86) / 0.14, 2.0))) * 1.15
		var lift := wd * (0.7 + f * 0.35)
		for j in m + 1:
			var s := float(j) / m * 2.0 - 1.0
			var dome := sqrt(maxf(0.0, 1.0 - s * s))
			var at := (path[k] as Vector3) + side * wd * s
			var on := out
			var cp := surf.closest(at)
			if cp.size():
				at = cp[0]
				on = cp[1]
			v.append(at + on * (0.0015 + dome * lift))
			nm.append((on * (0.25 + dome) + side * s * 0.9).normalized())
			uv.append(Vector2(0.5 + s * 0.5, d + v0))
			cl.append(Color(f, 0, 0, 1))
	for k in n - 1:
		for j in m:
			var a2 := k * (m + 1) + j
			idx.append_array([a2, a2 + m + 1, a2 + 1, a2 + 1, a2 + m + 1, a2 + m + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nm
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_COLOR] = cl
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)

## a smooth run: the coarse steps of a flow resampled into a fine, even curve (no corners), its normals smoothed too
static func _smooth_run(path: Array, ns: Array, step: float) -> Array:
	var raw := path.duplicate()
	var rn := ns.duplicate()
	for it in 3:
		for k in range(1, raw.size() - 1):
			raw[k] = ((raw[k - 1] as Vector3) + (raw[k] as Vector3) * 2.0 + (raw[k + 1] as Vector3)) * 0.25
			rn[k] = ((rn[k - 1] as Vector3) + (rn[k] as Vector3) * 2.0 + (rn[k + 1] as Vector3)).normalized()
	var out := []
	var on := []
	for k in raw.size() - 1:
		var a: Vector3 = raw[k]
		var c: Vector3 = raw[k + 1]
		var n := maxi(1, int(ceil(a.distance_to(c) / step)))
		for j in n:
			var f := float(j) / n
			var p0: Vector3 = raw[maxi(k - 1, 0)]
			var p3: Vector3 = raw[mini(k + 2, raw.size() - 1)]
			out.append(a.cubic_interpolate(c, p0, p3, f))
			on.append((rn[k] as Vector3).lerp(rn[k + 1], f).normalized())
	out.append(raw[raw.size() - 1])
	on.append(rn[rn.size() - 1])
	return [out, on]

## the water's sheet along a run: domed across (its middle a thin lens of water, its edges on the surface), 9 strips
## wide, fine along — no facets; UV.x across 0..1, UV.y along in units (continuing from `v0`)
## surf: the sheet is pressed onto it point by point (its edges follow the real surface, not the run's tangent plane)
static func _sheet(path: Array, ns: Array, w0: float, w1: float, v0: float, mat: Material, parent: Node3D, surf: SpecSurf = null) -> float:
	var m := 8
	var v := PackedVector3Array()
	var nm := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var n := path.size()
	var vlen := v0
	# (the run's length, so its ends can narrow: water creeps out at its head and gathers to a bead at its tail)
	var total := 0.0
	for k in range(1, n): total += (path[k] as Vector3).distance_to(path[k - 1])
	var run_d := 0.0
	for k in n:
		var a: Vector3 = path[maxi(k - 1, 0)]
		var c: Vector3 = path[mini(k + 1, n - 1)]
		var tg := (c - a).normalized()
		var out: Vector3 = ns[k]
		var side := tg.cross(out).normalized()
		if side.length_squared() < 0.5: side = Vector3.RIGHT
		var f := float(k) / maxf(1.0, n - 1.0)
		if k:
			var dk := (path[k] as Vector3).distance_to(path[k - 1])
			vlen += dk
			run_d += dk
		var wd := lerpf(w0, w1, smoothstep(0.0, 0.5, f)) * (1.0 + 0.14 * sin(float(k) * 0.35 + v0 * 7.0) + 0.08 * sin(float(k) * 0.93 + v0 * 3.0))
		wd *= sqrt(smoothstep(0.0, 0.03, run_d)) * lerpf(0.3, 1.0, sqrt(smoothstep(0.0, 0.025, total - run_d)))
		for j in m + 1:
			var s := float(j) / m * 2.0 - 1.0
			var dome := sqrt(maxf(0.0, 1.0 - s * s))
			var at := (path[k] as Vector3) + side * wd * s
			var on := out
			if surf:
				var cp := surf.closest(at)
				if cp.size():
					at = cp[0]
					on = cp[1]
			v.append(at + on * (0.0025 + dome * wd * 0.15))
			nm.append((on * (0.3 + dome) + side * s * 0.8).normalized())
			uv.append(Vector2(0.5 + s * 0.5, vlen))
	for k in n - 1:
		for j in m:
			var a2 := k * (m + 1) + j
			idx.append_array([a2, a2 + m + 1, a2 + 1, a2 + 1, a2 + m + 1, a2 + m + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nm
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)
	return vlen

## the falling-water material (shaders/skull_fall.gdshader); waver: how much the sheet wavers (low where it lies on bone)
## the colour of the water being laid (set by _stream / _stream_on for the skull being built): clear, or wine
static var wine := false
const WINE_DEEP := Vector3(0.28, 0.0, 0.03)
const WINE_LIGHT := Vector3(0.55, 0.02, 0.05)

static func fall_mat(waver: float) -> ShaderMaterial:
	var fm := ShaderMaterial.new()
	fm.shader = FALL
	fm.render_priority = 3
	fm.set_shader_parameter("waver", waver)
	if wine:
		fm.set_shader_parameter("deep", WINE_DEEP)
		fm.set_shader_parameter("white", WINE_LIGHT)
		fm.set_shader_parameter("glow", 0.15)
		fm.set_shader_parameter("body_a", 0.72)
		fm.set_shader_parameter("spec", 0.18)
	return fm

## a drop's material (Drip): clear water, or wine
static func drop_mat() -> StandardMaterial3D:
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.45, 0.02, 0.05, 0.75) if wine else Color(0.06, 0.08, 0.09, 0.3)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.roughness = 0.02
	dm.metallic_specular = 1.0
	dm.rim_enabled = true
	dm.rim = 0.8
	dm.rim_tint = 0.2
	return dm

## the skull's pose: its own space to the find's (held up to the viewer, lying on its rock) — the viewer looks along -Z
static func pose_basis(sk: Dictionary) -> Basis:
	var bas := lean_basis(sk)
	if sk.show == "rock":
		var a: Array = sk.lie_a
		bas = bas * Basis(Vector3.UP, float(a[0])) * Basis(Vector3.BACK, float(a[1])) * Basis(Vector3.RIGHT, float(a[2]))
	return bas

## a little waterfall out of an eye: it wells over the lowest point of the socket's rim (outside it, never inside) and
## runs down over the bone as a broad sheet of racing water (shaders/skull_fall.gdshader), pressed onto the real
## surface (SpecSurf); where the bone turns in under itself it drops straight down onto what is below, white where it
## lands, and runs on. It comes out of the eye the viewer sees; a skull lying face down or face up has none (it would
## run unseen, or fill the eyes). What happens at its end: on a skull on its rock the rock takes it on (_stream_on),
## else it pours off into the air, or (ending on the bone) drips.
static func _stream(b: RefCounted, sk: Dictionary, bones: Array, nrs: Array) -> void:
	wine = bool(sk.get("wine", false))
	var down := down_of(sk)
	if absf(down.dot(Vector3.BACK)) > 0.6: return
	var surf := SpecSurf.new()
	for k in bones.size(): surf.add(bones[k], nrs[k])
	var bas := pose_basis(sk)
	var lip := []
	var score := -INF
	for sx: float in [-1.0, 1.0]:
		var l := _lip(surf, sx, down)
		if l.is_empty(): continue
		var vis := (bas * (l[1] as Vector3)).z + (0.25 if sx == float(sk.stream_side) else 0.0)
		if vis > score:
			score = vis
			lip = l
	if lip.is_empty() or score < -0.15: return
	var sx: float = lip[3]
	# (water clings to bone a long way under an overhang before it lets go)
	var res := surf.run((lip[0] as Vector3) + (lip[2] as Vector3) * 0.012, down, 0.014, 0.85, Vector3.ZERO, 0.75)
	if res.is_empty(): return
	var laid := _lay(b, sk, surf, res, down, Vector3(-sx, 0.0, 0.0), FALL_W[0], FALL_W[1], 0.0, 47)
	var path: Array = laid[0]
	var e: Vector3 = (res.end as Array)[0]
	var en: Vector3 = (res.end as Array)[1]
	var n := path.size()
	if n < 3: return
	# (the gene's callout points at the spring itself: the eye's rim it wells over)
	(sk.marks as Array).append(["sk_stream", lip[0], lip[1]])
	(sk.taken as Array).append_array(range(0, n, 6).map(func(i: int) -> Array: return [path[i], Vector3.UP]))
	# the wet bone along every run (vertex alpha), fading out a little to the sides
	for k in bones.size():
		var g: Geo = bones[k]
		if g.col.size() < g.v.size(): continue
		for i in g.v.size():
			var dmin := INF
			for jj in range(0, n, 3):
				dmin = minf(dmin, g.v[i].distance_squared_to(path[jj]))
			var w := 1.0 - smoothstep(0.0012, 0.005, dmin)
			if w > 0.0:
				var c := g.col[i]
				c.a = minf(c.a, 1.0 - w)
				g.col[i] = c
	var dr: Drip = null
	if res.pour and sk.show != "rock":
		# pouring off into the air below
		var fp := []
		for k in 12: fp.append(e + en * 0.004 + down * 0.3 * float(k) / 11.0)
		_curtain(b, fp, en - down * down.dot(en), true, fall_mat(1.0))
	elif not res.pour:
		dr = Drip.new()
		dr.setup(Rng32.new(int(sk.skin_seed) + 41), down, 0.02, false, drop_mat())
		dr.position = e + down * 0.008
		b.root.add_child(dr)
	sk.stream_end = [e, en, float(laid[1]), dr, bool(res.pour)]
	sk.stream_bones = [bones, nrs]

## where water wells out of an eye (side sx), found on the skull itself (proportions differ from skull to skull): rays
## straight at the face (skull space, face toward +Z) fall deep into the socket's opening and stop short on the bone
## round it; the opening's middle is the middle of the deep hits, its rim — along each of 32 ways out from there — the
## first ray that stops on the bone in front. The lip is the rim's lowest point (the nose's corner kept out of it).
## Returns [point, normal, outward (away from the opening), sx] or []
static func _lip(surf: SpecSurf, sx: float, down: Vector3) -> Array:
	var hits := []
	var zf := -INF
	for yi in 16:
		for xi in 16:
			var q := Vector3(sx * (0.03 + xi * 0.02), -0.12 + yi * 0.022, 1.5)
			var h := surf.ray(q, Vector3.FORWARD, 3.0)
			if h.is_empty(): continue
			var hz: float = (h[0] as Vector3).z
			zf = maxf(zf, hz)
			hits.append(Vector3(q.x, q.y, hz))
	if hits.size() < 20: return []
	var c := Vector2.ZERO
	var zd := 0.0
	var nd := 0
	for hv: Vector3 in hits:
		if hv.z < zf - 0.15:
			c += Vector2(hv.x, hv.y)
			zd += hv.z
			nd += 1
	if nd < 4: return []
	c /= nd
	zd /= nd
	var front := zd + (zf - zd) * 0.6
	var best := []
	var bs := -INF
	for k in 32:
		var a := TAU * k / 32.0
		var dv := Vector2(cos(a), sin(a))
		# (the nose's side of the rim — its inner lower corner — left out)
		if dv.x * sx < -0.5 and dv.y < 0.3: continue
		var r := 0.02
		while r < 0.22:
			var h := surf.ray(Vector3(c.x + dv.x * r, c.y + dv.y * r, 1.5), Vector3.FORWARD, 3.0)
			if h.size() and (h[0] as Vector3).z > front:
				var pt: Vector3 = h[0]
				var sc := pt.dot(down)
				if sc > bs:
					bs = sc
					best = [pt, h[1], Vector3(dv.x, dv.y, 0.0), sx]
				break
			r += 0.006
	return best

## lays what a run of water did (SpecSurf.run): a sheet over each stretch (its middle moved toward `toward` by a third
## of its width), a short drop with a splash where it fell between them. Returns [all its points, its length]
static func _lay(b: RefCounted, sk: Dictionary, surf: SpecSurf, res: Dictionary, down: Vector3, toward: Vector3, w0: float, w1: float, v0: float, seed_add: int) -> Array:
	var path := []
	var vlen := v0
	var runs: Array = res.runs
	var drops: Array = res.drops
	var fm := fall_mat(0.2)
	for ri in runs.size():
		var rr: Array = runs[ri]
		if (rr[0] as Array).size() >= 3:
			var sm := _smooth_run(rr[0], rr[1], 0.008)
			var mid := []
			var mn := []
			for k in (sm[0] as Array).size():
				var nk: Vector3 = (sm[1] as Array)[k]
				var q: Vector3 = (sm[0] as Array)[k]
				if toward != Vector3.ZERO: q += (toward - nk * toward.dot(nk)) * w0 * 0.15
				var cp := surf.closest(q)
				mid.append(cp[0] if cp.size() else q)
				mn.append(cp[1] if cp.size() else nk)
			vlen = _sheet(mid, mn, w0 * (0.75 if ri == 0 else 1.0), w1, vlen, fm, b.root, surf)
			path.append_array(mid)
		if ri < drops.size():
			var dd: Array = drops[ri]
			var f0: Vector3 = dd[0]
			var t0: Vector3 = dd[1]
			var tn: Vector3 = dd[2]
			var dp := []
			for k in 9: dp.append(f0.lerp(t0, float(k) / 8.0))
			var c0 := surf.closest(f0)
			var on: Vector3 = c0[1] if c0.size() else Vector3.BACK
			_curtain(b, dp, on - down * down.dot(on), false, fall_mat(1.0))
			var spl := Splash.new()
			spl.setup(Rng32.new(int(sk.skin_seed) + seed_add + ri), tn, down, w1)
			spl.position = t0 + tn * 0.004
			b.root.add_child(spl)
	return [path, vlen]

## falling water along `pts` (shaders/skull_fall.gdshader, its `tube` mode): a flattened tube — wide across `fwd` (the
## way it faces), half as deep — so it has a body from any side (a flat ribbon thinned to a line seen edge on),
## narrowing as it speeds up; clear_end: it falls clear of everything, the end fades out. UV.x round the tube, UV.y along
static func _curtain(b: RefCounted, pts: Array, fwd: Vector3, clear_end: bool, mat: Material) -> void:
	if pts.size() < 2: return
	fwd = fwd.normalized() if fwd.length() > 0.05 else Vector3.BACK
	var m := 12
	var vv := PackedVector3Array()
	var nm := PackedVector3Array()
	var uv := PackedVector2Array()
	var cl := PackedColorArray()
	var idx := PackedInt32Array()
	var n := pts.size()
	var len_ := 0.0
	var total := 0.0
	for k in range(1, n): total += (pts[k] as Vector3).distance_to(pts[k - 1])
	for k in n:
		var a: Vector3 = pts[maxi(k - 1, 0)]
		var c: Vector3 = pts[mini(k + 1, n - 1)]
		var tg := (c - a).normalized()
		var side := tg.cross(fwd).normalized()
		if side.length_squared() < 0.5: side = Vector3.RIGHT
		var face := side.cross(tg).normalized()
		if k: len_ += (pts[k] as Vector3).distance_to(pts[k - 1])
		var f := len_ / maxf(total, 0.001)
		var wd := lerpf(FALL_W[0], FALL_W[1], sqrt(f)) * (1.0 + 0.1 * sin(float(k) * 0.8))
		var dp := wd * 0.5
		var fade := 1.0 - smoothstep(0.5, 1.0, f) if clear_end else 1.0
		for j in m + 1:
			var an := TAU * float(j) / m
			var ca := cos(an)
			var sa := sin(an)
			vv.append((pts[k] as Vector3) + side * wd * ca + face * dp * sa)
			nm.append((side * ca / wd + face * sa / dp).normalized())
			uv.append(Vector2(float(j) / m, len_))
			cl.append(Color(1, 1, 1, fade))
	for k in n - 1:
		for j in m:
			var a2 := k * (m + 1) + j
			idx.append_array([a2, a2 + m + 1, a2 + 1, a2 + 1, a2 + m + 1, a2 + m + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vv
	arr[Mesh.ARRAY_NORMAL] = nm
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_COLOR] = cl
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	(mat as ShaderMaterial).set_shader_parameter("tube", true)   # (each fall has its own material: fall_mat)
	mi.material_override = mat
	b.root.add_child(mi)

## where a fall lands: a patch of white water, pulsing, and droplets jumping out of it and falling back, one after
## another
class Splash extends Node3D:
	var drops := []
	var r: Rng32
	var up := Vector3.UP
	var down := Vector3.DOWN
	var foam: MeshInstance3D
	var fb := Basis.IDENTITY
	var t := 0.0

	func setup(rng: Rng32, n: Vector3, d: Vector3, size: float) -> void:
		r = rng
		up = n
		down = d
		var wm := StandardMaterial3D.new()
		wm.albedo_color = Color(0.85, 0.25, 0.3, 0.45) if SpecSkull.wine else Color(0.9, 0.96, 1.0, 0.35)
		wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wm.roughness = 0.3
		wm.emission_enabled = true
		wm.emission = Color(0.4, 0.08, 0.1) if SpecSkull.wine else Color(0.5, 0.55, 0.6)
		foam = MeshInstance3D.new()
		var fs := SphereMesh.new()
		fs.radius = 0.5
		fs.height = 1.0
		fs.radial_segments = 16
		fs.rings = 8
		foam.mesh = fs
		foam.material_override = wm
		fb = Basis(U.quat_to(Vector3.UP, up)) * Basis.from_scale(Vector3(size * 1.1, size * 0.18, size * 0.9))
		foam.basis = fb
		add_child(foam)
		var dm := StandardMaterial3D.new()
		dm.albedo_color = Color(0.7, 0.08, 0.12, 0.8) if SpecSkull.wine else Color(0.8, 0.9, 1.0, 0.75)
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.roughness = 0.05
		dm.emission_enabled = true
		dm.emission = Color(0.3, 0.03, 0.05) if SpecSkull.wine else Color(0.4, 0.45, 0.5)
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 8
		sm.rings = 4
		for k in 9:
			var m := MeshInstance3D.new()
			m.mesh = sm
			m.material_override = dm
			m.visible = false
			add_child(m)
			drops.append({m = m, v = Vector3.ZERO, t = -r.next() * 0.6, life = 0.4, s = size * (0.12 + r.next() * 0.12)})

	func _process(dt: float) -> void:
		dt = minf(dt, 0.05)
		t += dt
		var fs := 1.0 + 0.12 * sin(t * 13.0) + 0.06 * sin(t * 29.0)
		foam.basis = fb * Basis(Vector3.UP, t * 0.7) * Basis.from_scale(Vector3(fs, 1.0, fs * 0.9))
		for d: Dictionary in drops:
			var m: MeshInstance3D = d.m
			d.t += dt
			if d.t < 0.0: continue
			if d.t > float(d.life) or not m.visible:
				# out again: up off the foam and a little to a side
				var side := Vector3(r.next() - 0.5, r.next() - 0.5, r.next() - 0.5)
				side -= up * side.dot(up)
				d.v = up * (0.18 + r.next() * 0.22) + side.normalized() * (0.06 + r.next() * 0.12) - down * 0.05
				d.life = 0.25 + r.next() * 0.3
				d.t = 0.0
				m.position = Vector3.ZERO
				m.visible = true
			d.v += down * 2.6 * dt
			m.position += (d.v as Vector3) * dt
			var k := 1.0 - float(d.t) / float(d.life)
			m.scale = Vector3.ONE * float(d.s) * (0.4 + 0.6 * k)


## the stream on its rock: from where it left the skull — pouring off it, straight down onto the stone; or still on the
## bone, running off it — over the rock's surface and flank, splitting into a rivulet or two, each dripping (or
## pouring) off the stone at its end. rock: [geo, normals] in the root's space, T: the skull's place on it
static func _stream_on(b: RefCounted, sk: Dictionary, T: Transform3D, rock: Geo, rn: PackedVector3Array) -> void:
	if not sk.has("stream_end"): return
	wine = bool(sk.get("wine", false))
	var se: Array = sk.stream_end
	var down := (lean_basis(sk).inverse() * Vector3.DOWN).normalized()
	var surf := SpecSurf.new()
	surf.add(rock, rn)
	var sb: Array = sk.stream_bones
	for k in (sb[0] as Array).size(): surf.add(sb[0][k], sb[1][k], T)
	var start := T * (se[0] as Vector3)
	var sn := (T.basis * (se[1] as Vector3)).normalized()
	var old: Drip = se[3]
	if old:
		if old.get_parent(): old.get_parent().remove_child(old)
		old.free()
	var p := start
	if se[4]:
		var h := surf.ray(start + sn * 0.003, down, 0.9)
		if h.is_empty(): return
		var dp := []
		for k in 12: dp.append(start.lerp(h[0], float(k) / 11.0))
		_curtain(b, dp, sn - down * down.dot(sn), false, fall_mat(1.0))
		var spl := Splash.new()
		spl.setup(Rng32.new(int(sk.skin_seed) + 70), h[1], down, FALL_W[1])
		spl.position = (h[0] as Vector3) + (h[1] as Vector3) * 0.004
		b.root.add_child(spl)
		p = h[0]
	var r := Rng32.new(int(sk.skin_seed) + 71)
	var res := surf.run(p, down, 0.016, 0.8)
	if res.is_empty(): return
	var laid := _lay(b, sk, surf, res, down, Vector3.ZERO, FALL_W[1], FALL_W[1] * 0.8, float(se[2]), 72)
	_end_of(b, sk, res, down, 80)
	# a rivulet or two splitting off and finding their own way down the stone
	var main: Array = laid[0]
	if main.size() > 10:
		for k in 1 + int(r.next() * 2):
			var at: Vector3 = main[int(main.size() * (0.3 + r.next() * 0.35))]
			var cp := surf.closest(at)
			if cp.is_empty(): continue
			var nn: Vector3 = cp[1]
			var side := down.cross(nn).normalized() * (1.0 if r.next() < 0.5 else -1.0)
			var r2 := surf.run(at + side * 0.02, down, 0.016, 0.25 + r.next() * 0.2, side * 1.5)
			if r2.is_empty(): continue
			_lay(b, sk, surf, r2, down, Vector3.ZERO, FALL_W[1] * 0.5, FALL_W[1] * 0.35, r.next() * 3.0, 90 + k * 10)
			_end_of(b, sk, r2, down, 81 + k)

## the end of a run on the rock: pouring off its edge into the air, or a drip where it gives out
static func _end_of(b: RefCounted, sk: Dictionary, res: Dictionary, down: Vector3, sd: int) -> void:
	var e: Vector3 = (res.end as Array)[0]
	var en: Vector3 = (res.end as Array)[1]
	if res.pour:
		var fp := []
		for k in 10: fp.append(e + en * 0.004 + down * 0.25 * float(k) / 9.0)
		_curtain(b, fp, en - down * down.dot(en), true, fall_mat(1.0))
	else:
		var d := Drip.new()
		d.setup(Rng32.new(int(sk.skin_seed) + sd), down, 0.014, false, drop_mat())
		d.position = e + down * 0.008
		b.root.add_child(d)

## a drop gathering at the end of a stream (or of a run of metal), swelling, stretching and letting go, falling and
## gone; then a pause, sometimes two drops close together. Water quick and light, metal slow and heavy.
class Drip extends Node3D:
	var down := Vector3.DOWN
	var r: Rng32
	var size := 0.016
	var heavy := false
	var t := 0.0
	var phase := 0      # 0 gathering, 1 falling, 2 pause
	var dur := 1.0
	var drop: MeshInstance3D
	var fall := Vector3.ZERO
	var vel := 0.0

	func setup(rng: Rng32, d: Vector3, s: float, metal: bool, mat: Material = null) -> void:
		r = rng
		down = d
		size = s
		heavy = metal
		drop = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 16
		sm.rings = 10
		drop.mesh = sm
		if mat: drop.material_override = mat
		else:
			# (clear: dark see-through with a bright glint and a lit rim, as the stream — a pale one read as a pearl)
			var dm := StandardMaterial3D.new()
			dm.albedo_color = Color(0.06, 0.08, 0.09, 0.3)
			dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			dm.roughness = 0.02
			dm.metallic_specular = 1.0
			dm.rim_enabled = true
			dm.rim = 0.8
			dm.rim_tint = 0.2
			drop.material_override = dm
		# (hidden and drop-sized from the start: a still picture — the collection's preview — is taken before the first
		# _process, and a unit sphere then hung off the skull like a great bubble)
		drop.visible = false
		drop.scale = Vector3.ONE * size
		add_child(drop)
		phase = 2
		dur = r.next() * 1.5

	func _process(dt: float) -> void:
		dt = minf(dt, 0.05)
		t += dt
		match phase:
			0:
				# gathering: swelling from nothing, then stretching downward as it gets heavy
				var f := clampf(t / dur, 0.0, 1.0)
				var s := size * (0.3 + 0.9 * f)
				var stretch := 1.0 + smoothstep(0.7, 1.0, f) * 0.6
				drop.visible = true
				drop.basis = Basis(SpecUtil.quat_to(Vector3.UP, -down)) * Basis.from_scale(Vector3(s, s * stretch, s))
				drop.position = down * s * 0.5 * stretch
				if f >= 1.0:
					phase = 1
					t = 0.0
					fall = drop.position
					vel = 0.0
			1:
				vel += dt * (2.2 if heavy else 3.2)
				fall += down * vel * dt
				var s := size * 1.1
				drop.basis = Basis(SpecUtil.quat_to(Vector3.UP, -down)) * Basis.from_scale(Vector3(s * 0.85, s * (1.0 + vel * 0.6), s * 0.85))
				drop.position = fall
				if t > (1.2 if heavy else 0.75):
					phase = 2
					t = 0.0
					drop.visible = false
					# the rhythm: usually a pause, now and then the next comes quickly
					dur = (2.5 + r.next() * 3.0) if heavy else (0.25 if r.next() < 0.3 else 0.8 + r.next() * 1.4)
			_:
				if t > dur:
					phase = 0
					t = 0.0
					dur = (2.0 + r.next() * 1.5) if heavy else (0.5 + r.next() * 0.6)

## a tree grown on the skull: a gnarled trunk out of the crown, its roots creeping down over the bone into the eye
## sockets and the mouth, splitting and thinning as they go
static func _roots(b: RefCounted, sk: Dictionary, bones: Array, nrs: Array, cr: Geo) -> void:
	var r := Rng32.new(int(sk.skin_seed) + 11)
	var bark := bark_mat(r, "oak")
	var bb := cr.aabb()
	var crown: Array = _near(bones, nrs, Vector3((r.next() - 0.5) * 0.15, bb.position.y + bb.size.y + 0.05, (r.next() - 0.3) * 0.2))
	var top: Vector3 = crown[0]
	(sk.marks as Array).append(["sk_roots", top + Vector3(0, 0.15, 0), Vector3.UP])
	var hold := Node3D.new()
	b.root.add_child(hold)
	# the trunk and a few bare limbs
	var tk := SpecBranch.skeleton(r, {r0 = 0.08, len0 = 0.75, levels = 2, kids = [2, 3], kids2 = [1, 2], kid_r = 0.6, kid_len = 0.6,
		spread = 1.0, gnarl = 0.9, up = 0.25, taper = 0.45})
	var th := Node3D.new()
	hold.add_child(th)
	th.position = top - (crown[1] as Vector3) * 0.02
	for k in tk.size():
		U.mesh(SpecBranch.tube(tk[k], {m = 9, sub = 2, lump = 0.15, ridge = 0.2, flat = 1.0, seed = int(r.next() * 1000)}, k == 0).fill_color(Color(1, 1, 1)), bark, th)
	crown(th, r, tk, String(sk.tree_kind) if sk.tree_kind != "moss" else "leaves", 2.2)
	# the roots: walking down the bone's surface, wandering, branching
	var walk := func(fn: Callable, p0: Vector3, d0: Vector3, r0: float, steps: int, depth: int) -> void:
		var pts := [p0]
		var p := p0
		var d := d0
		for k in steps:
			var q: Array = _near(bones, nrs, p)
			var nn: Vector3 = q[1]
			d = (d + Vector3(r.next() - 0.5, -0.9, r.next() - 0.5) * 0.35).normalized()
			d = (d - nn * d.dot(nn)).normalized()
			p = (q[0] as Vector3) + nn * r0 * 0.9 + d * 0.045
			pts.append(p)
			if depth < 2 and r.next() < 0.12:
				fn.call(fn, p, (d + nn.cross(d) * (1.0 if r.next() < 0.5 else -1.0)).normalized(), r0 * 0.6, int(steps * 0.5), depth + 1)
			if p.y < bb.position.y + 0.05: break
		if pts.size() > 2:
			U.mesh(_taper(pts, r0, r0 * 0.3, 8), bark, hold)
	for k in 11 + int(r.next() * 6):
		var a := (float(k) + r.next() * 0.7) / 14.0 * TAU
		var d := Vector3(cos(a), -0.3, sin(a)).normalized()
		walk.call(walk, top + Vector3(cos(a), 0, sin(a)) * 0.05, d, 0.04 + r.next() * 0.022, 26 + int(r.next() * 20), 0)

## a glass skull: the bones in clear glass, a bunch of wild flowers growing inside the head, seen through it
static func _glass_flowers(b: RefCounted, sk: Dictionary) -> void:
	var r := Rng32.new(int(sk.skin_seed) + 21)
	var spots := []
	while spots.size() < 280:
		var u := Vector3(r.next() - 0.5, r.next() - 0.5, r.next() - 0.5) * 2.0
		if u.length() > 1.0: continue
		var p := Vector3(u.x * 0.26, 0.2 + u.y * 0.24, -0.05 + u.z * 0.34)
		spots.append([p, (Vector3.UP + Vector3(u.x, 0, u.z) * 0.8).normalized()])
	var root: Node3D = b.root
	var cols := [Color(0.62, 0.45, 0.9), Color(0.98, 0.82, 0.15), Color(0.97, 0.97, 0.95), Color(0.85, 0.35, 0.55), Color(0.55, 0.4, 0.95)]
	SpecAccents.fronds(root, r, spots.slice(0, 40), 26, 0.22, SpecAccents.FROND[1])
	for k in 5:
		var near := spots.slice(40 + k * 40, 80 + k * 40)
		SpecAccents.flowers(root, r, near, 6 + int(r.next() * 5), 0.16 + r.next() * 0.06, cols[k % cols.size()])

## how the find is held up to the viewer (lean): on its rock tipped a little, a loose one tipping its head too (half the
## pose: it floats, nothing holds it on its side)
static func lean_basis(sk: Dictionary) -> Basis:
	if sk.show == "rock":
		return Basis(Vector3.RIGHT, 0.18)
	var la: Array = sk.lie_a
	return Basis(Vector3.RIGHT, 0.3) * Basis(Vector3.BACK, float(la[1]) * 0.5) * Basis(Vector3.RIGHT, float(la[2]) * 0.4)

## one flower of the bouquet at a spot of the breach: chrysanthemums (some in gold), hydrangea balls, cosmos, buds and
## gold wires with beads, bigger in the middle of the breach (f), on a short stem leaning out of it
static func _flower(bt: Dictionary, r: Rng32, sk: Dictionary, f: float, at: Vector3, dir: Vector3) -> void:
	if r.next() < 0.08: return
	var pal: Array = SpecBloom.PALETTES[int(sk.bloom_pal) % SpecBloom.PALETTES.size()]
	var s := 0.24 + f * 0.3 + r.next() * 0.1
	var kind: String = Stones.pick_w([["mum", 3.0], ["hydrangea", 3.0], ["cosmos", 2.0], ["bud", 1.0], ["sprig", 0.6]], r)
	var tip := at + dir * s * (0.05 + r.next() * 0.2)
	SpecBloom.stem(bt, r, at, tip, s * 0.03)
	var face := (dir + Vector3(r.next() - 0.5, r.next() - 0.5, r.next() - 0.5) * 0.5).normalized()
	match kind:
		"mum":
			var gold := r.next() < 0.45
			SpecBloom.head(bt, r, "mum", tip, face, s, pal[2] if gold else pal[1], pal[3], gold and int(sk.bloom_pal) % 5 in [0, 2])
		"hydrangea": SpecBloom.head(bt, r, "hydrangea", tip, face, s * 1.15, pal[0], pal[2])
		"cosmos": SpecBloom.head(bt, r, "cosmos", tip, face, s, pal[1], pal[3])
		"bud": SpecBloom.head(bt, r, "bud", tip, face, s * 0.8, pal[0], pal[3])
		_: SpecBloom.head(bt, r, "sprig", tip, face, s * 0.7, pal[0], pal[2], true)
