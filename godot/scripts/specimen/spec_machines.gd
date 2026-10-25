class_name SpecMachines
extends RefCounted
## Machines for the depot: painted steel, rubber, a little wood. Port of buildMachine.
## root meta "anim" lists [node, axis, speed] for the parts that keep moving.

const B := preload("res://scripts/specimen/spec_util.gd")

var root := Node3D.new()
var anim := []
var M := {}

static func build(id: String) -> Node3D:
	return SpecMachines.new()._build(id)

func put(geo: Geo, m: Material, at := Vector3.ZERO, rot := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	return B.mesh(geo, m, parent if parent else root, at, B.eul(rot.x, rot.y, rot.z))

func box(w: float, h: float, d: float, m: Material, at := Vector3.ZERO, rot := Vector3.ZERO, par: Node3D = null) -> MeshInstance3D:
	return put(Geo.box(w, h, d), m, at, rot, par)

func cyl(rt: float, rb: float, h: float, m: Material, at := Vector3.ZERO, rot := Vector3.ZERO, par: Node3D = null, seg := 24) -> MeshInstance3D:
	return put(Geo.cylinder(rt, rb, h, seg), m, at, rot, par)

## a straight member between two points
func beam(a: Vector3, b: Vector3, r: float, m: Material, par: Node3D = null) -> MeshInstance3D:
	var d := b - a
	var o := put(Geo.cylinder(r, r, d.length(), 8), m, (a + b) * 0.5, Vector3.ZERO, par)
	o.basis = Basis(B.quat_to(Vector3.UP, d.normalized()))
	return o

func track(len: float, z: float, y: float) -> void:
	box(len, 0.2, 0.26, M.rubber, Vector3(0, y, z))
	for k in 5:
		cyl(0.09, 0.09, 0.28, M.dark, Vector3(-len / 2 + 0.12 + k * (len - 0.24) / 4, y, z), Vector3(PI / 2, 0, 0))

func spinner(o: Node3D, ax: String, v: float) -> Node3D:
	anim.append([o, ax, v])
	return o

func mat(hex: int, rough: float, extra := {}) -> ShaderMaterial:
	var d := {col = SpecMat.lin(hex), rough = rough}
	d.merge(extra, true)
	return SpecMat.make(d)

func group(at := Vector3.ZERO) -> Node3D:
	var g := Node3D.new()
	g.position = at
	root.add_child(g)
	return g

func _build(id: String) -> Node3D:
	M = {
		paint = mat(0xf2b01e, 0.42, {metal = 0.25, coat = 0.5, coat_r = 0.3}),
		red = mat(0xc8341e, 0.45, {metal = 0.2, coat = 0.4}),
		steel = mat(0xa8b0b8, 0.3, {metal = 0.9, env = 1.4}),
		dark = mat(0x2a2e34, 0.5, {metal = 0.6}),
		rubber = mat(0x151515, 0.92),
		wood = mat(0x8a5a2c, 0.8),
		glass = mat(0x6a9ac8, 0.05, {metal = 0.1, coat = 1.0, transp = true, a = 0.6}),
		hot = mat(0xff7a20, 0.4, {emis = SpecMat.lin(0xff5a10) * 1.4}),
		lamp = mat(0xffe7a0, 0.5, {emis = SpecMat.lin(0xffd070) * 1.2}),
	}
	match id:
		"hammer":
			# jackhammer: body, T-handle with grips, chisel, hose
			cyl(0.16, 0.16, 0.7, M.paint, Vector3(0, 0.1, 0))
			cyl(0.19, 0.19, 0.08, M.dark, Vector3(0, 0.48, 0))
			for k in 4:
				put(Geo.torus(0.165, 0.015, 8, 32), M.dark, Vector3(0, -0.12 + k * 0.1, 0), Vector3(PI / 2, 0, 0))
			cyl(0.035, 0.035, 0.8, M.steel, Vector3(0, 0.64, 0), Vector3(0, 0, PI / 2))
			for x in [-0.32, 0.32]:
				cyl(0.05, 0.05, 0.2, M.rubber, Vector3(x, 0.64, 0), Vector3(0, 0, PI / 2))
			for x in [-0.11, 0.11]:
				cyl(0.03, 0.03, 0.16, M.steel, Vector3(x, 0.56, 0))
			cyl(0.1, 0.13, 0.16, M.steel, Vector3(0, -0.33, 0))
			var ch := cyl(0.04, 0.04, 0.5, M.steel, Vector3(0, -0.64, 0))
			put(Geo.cone(0.045, 0.14, 12), M.steel, Vector3(0, -0.95, 0), Vector3(PI, 0, 0))
			var hose := [Vector3(0.16, 0.3, 0), Vector3(0.42, 0.2, 0.1), Vector3(0.5, -0.4, 0.2), Vector3(0.25, -0.95, 0.25), Vector3(-0.3, -0.98, 0.2), Vector3(-0.45, -0.9, -0.2), Vector3(0.1, -0.95, -0.35)]
			put(Geo.tube(hose, 60, 0.035, 8), mat(0x151515, 0.92, {side = "double"}))
			put(Geo.cylinder(0.6, 0.6, 0.04, 40), mat(0x3a3228, 0.95), Vector3(0, -1.02, 0))
			spinner(ch, "y", 3)
		"rig":
			# crawler drill rig: tracks, chassis, cab, lattice mast, turning drill rod
			track(1.3, 0.36, -0.62)
			track(1.3, -0.36, -0.62)
			box(1.2, 0.24, 0.8, M.paint, Vector3(0, -0.42, 0))
			box(0.5, 0.44, 0.62, M.paint, Vector3(-0.32, -0.08, 0))
			box(0.3, 0.22, 0.64, M.glass, Vector3(-0.32, 0.02, 0))
			box(0.08, 0.1, 0.66, M.red, Vector3(-0.06, -0.26, 0))
			for z in [-0.12, 0.12]:
				box(0.06, 1.7, 0.06, M.paint, Vector3(0.38, 0.55, z))
			for k in 7:
				var y := -0.2 + k * 0.24
				beam(Vector3(0.38, y, -0.12), Vector3(0.38, y + 0.24, 0.12), 0.015, M.paint)
				box(0.06, 0.03, 0.3, M.paint, Vector3(0.38, y, 0))
			box(0.18, 0.14, 0.3, M.red, Vector3(0.38, 1.38, 0))
			var rod := cyl(0.035, 0.035, 1.6, M.steel, Vector3(0.38, 0.45, 0))
			put(Geo.cone(0.07, 0.18, 10), M.dark, Vector3(0.38, -0.42, 0), Vector3(PI, 0, 0))
			beam(Vector3(0.05, -0.28, 0), Vector3(0.36, 0.4, 0), 0.03, M.steel)
			spinner(rod, "y", 6)
		"tbm":
			# tunnel boring machine: shield, rotating cutter head with discs, trailing gantry, tracks
			cyl(0.46, 0.46, 1.3, M.paint, Vector3.ZERO, Vector3(0, 0, PI / 2), null, 40)
			for x in [-0.4, 0.2]:
				put(Geo.torus(0.465, 0.03, 8, 40), M.red, Vector3(x, 0, 0), Vector3(0, PI / 2, 0))
			var head := group(Vector3(0.72, 0, 0))
			cyl(0.5, 0.5, 0.12, M.steel, Vector3.ZERO, Vector3(0, 0, PI / 2), head, 40)
			for k in 6:
				box(0.06, 0.9, 0.08, M.dark, Vector3(0.07, 0, 0), Vector3(k / 6.0 * 6.283, 0, 0), head)
			for r in 3:
				var n := 4 + r * 4
				for k in n:
					var a := float(k) / n * 6.283 + r
					var rr := 0.12 + r * 0.14
					put(Geo.cone(0.035, 0.1, 8), M.steel, Vector3(0.11, cos(a) * rr, sin(a) * rr), Vector3(0, 0, -PI / 2), head)
			put(Geo.cone(0.06, 0.14, 10), M.red, Vector3(0.13, 0, 0), Vector3(0, 0, -PI / 2), head)
			spinner(head, "x", 1.6)
			box(0.6, 0.34, 0.5, M.dark, Vector3(-0.95, -0.12, 0))
			for z in [-0.18, 0.18]:
				beam(Vector3(-1.2, -0.3, z), Vector3(-1.2, 0.25, z), 0.025, M.paint)
			beam(Vector3(-1.2, 0.25, -0.18), Vector3(-0.6, 0.25, -0.18), 0.025, M.paint)
			beam(Vector3(-1.2, 0.25, 0.18), Vector3(-0.6, 0.25, 0.18), 0.025, M.paint)
			cyl(0.05, 0.05, 0.9, M.steel, Vector3(-0.8, 0.32, 0.1), Vector3(0, 0, PI / 2))
			track(1.4, 0.3, -0.52)
			track(1.4, -0.3, -0.52)
		"deep":
			# deep drill: a lattice derrick over a platform, drill string glowing hot below
			box(1.1, 0.12, 1.1, M.dark, Vector3(0, -0.85, 0))
			for xz in [[-0.5, -0.5], [0.5, -0.5], [-0.5, 0.5], [0.5, 0.5]]:
				cyl(0.04, 0.05, 0.35, M.steel, Vector3(xz[0], -1.06, xz[1]))
			var legs := []
			for xz in [[-0.42, -0.42], [0.42, -0.42], [0.42, 0.42], [-0.42, 0.42]]:
				legs.append([Vector3(xz[0], -0.79, xz[1]), Vector3(xz[0] * 0.2, 1.05, xz[1] * 0.2)])
			for l in legs:
				beam(l[0], l[1], 0.03, M.red)
			for k in range(1, 6):
				var t := k / 6.0
				var pts := []
				for l in legs:
					pts.append((l[0] as Vector3).lerp(l[1], t))
				for q in 4:
					beam(pts[q], pts[(q + 1) % 4], 0.014, M.steel)
					if k < 5:
						var nl: Array = legs[(q + 1) % 4]
						beam(pts[q], (nl[0] as Vector3).lerp(nl[1], (k + 1) / 6.0), 0.01, M.steel)
			box(0.24, 0.14, 0.24, M.paint, Vector3(0, 1.1, 0))
			var string_m := cyl(0.03, 0.03, 1.95, M.steel, Vector3(0, 0.02, 0))
			box(0.3, 0.1, 0.3, M.paint, Vector3(0, -0.74, 0))
			cyl(0.06, 0.03, 0.2, M.hot, Vector3(0, -1.08, 0))
			box(0.34, 0.26, 0.3, M.paint, Vector3(0.62, -0.66, 0.2))
			box(0.2, 0.14, 0.02, M.glass, Vector3(0.62, -0.62, 0.36))
			spinner(string_m, "y", 5)
			var glow := put(Geo.sphere(0.12, 16, 12), SpecMat.make({col = B.raw(0xff8a30), unshaded = true, transp = true, a = 0.35}), Vector3(0, -1.12, 0))
			glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"lift":
			# winch: skid, side frames, a drum wound with cable, motor, a sheave above
			box(1.1, 0.1, 0.7, M.dark, Vector3(0, -0.5, 0))
			for z in [-0.33, 0.33]:
				beam(Vector3(-0.32, -0.45, z), Vector3(0, -0.05, z), 0.035, M.paint)
				beam(Vector3(0.32, -0.45, z), Vector3(0, -0.05, z), 0.035, M.paint)
				beam(Vector3(-0.32, -0.45, z), Vector3(0.32, -0.45, z), 0.03, M.paint)
			var drum := group(Vector3(0, -0.05, 0))
			cyl(0.24, 0.24, 0.54, M.steel, Vector3.ZERO, Vector3(PI / 2, 0, 0), drum)
			for k in 9:
				put(Geo.torus(0.25, 0.018, 6, 32), M.dark, Vector3(0, 0, -0.24 + k * 0.06), Vector3.ZERO, drum)
			for z in [-0.28, 0.28]:
				cyl(0.32, 0.32, 0.03, M.red, Vector3(0, 0, z), Vector3(PI / 2, 0, 0), drum)
			cyl(0.14, 0.14, 0.4, M.paint, Vector3(0.48, -0.24, 0), Vector3(PI / 2, 0, 0))
			box(0.12, 0.12, 0.5, M.dark, Vector3(0.48, -0.38, 0))
			beam(Vector3(-0.2, 0.1, 0), Vector3(-0.35, 1, 0), 0.012, M.dark)
			for z in [-0.06, 0.06]:
				beam(Vector3(-0.5, -0.45, z), Vector3(-0.35, 1.05, z), 0.025, M.paint)
			cyl(0.1, 0.1, 0.05, M.steel, Vector3(-0.35, 1.05, 0), Vector3(PI / 2, 0, 0))
			spinner(drum, "z", 1.4)
		"crush":
			# jaw crusher: square hopper, body, flywheels, a conveyor carrying crushed stone
			put(Geo.cylinder(0.5, 0.26, 0.45, 4, 1, true), mat(0xf2b01e, 0.42, {metal = 0.25, coat = 0.5, coat_r = 0.3, side = "double"}), Vector3(0, 0.55, 0), Vector3(0, PI / 4, 0))
			box(0.6, 0.55, 0.5, M.paint, Vector3(0, 0.05, 0))
			box(0.62, 0.08, 0.52, M.red, Vector3(0, 0.32, 0))
			for z in [-0.33, 0.33]:
				var fw := group(Vector3(0, 0.05, z))
				cyl(0.32, 0.32, 0.06, M.dark, Vector3.ZERO, Vector3(PI / 2, 0, 0), fw)
				for k in 4:
					box(0.6, 0.05, 0.07, M.steel, Vector3.ZERO, Vector3(0, 0, k * PI / 4), fw)
				spinner(fw, "z", 2.2)
			var belt := group(Vector3(0.75, -0.35, 0))
			belt.rotation.z = 0.35
			box(1.1, 0.05, 0.3, M.rubber, Vector3.ZERO, Vector3.ZERO, belt)
			for k in 6:
				cyl(0.035, 0.035, 0.34, M.steel, Vector3(-0.5 + k * 0.2, -0.04, 0), Vector3(PI / 2, 0, 0), belt)
			for k in 9:
				put(Geo.dodeca(0.04 + (k % 3) * 0.015), M.dark, Vector3(-0.45 + k * 0.11, 0.06, (k % 3 - 1) * 0.07), Vector3(k, k * 2, 0), belt)
			for x in [-0.25, 0.25]:
				for z in [-0.2, 0.2]:
					box(0.06, 0.3, 0.06, M.dark, Vector3(x, -0.38, z))
			var stone_m := mat(0x6a6258, 0.9, {flat = true})
			for k in 5:
				put(Geo.dodeca(0.07 + k * 0.01), stone_m, Vector3((k - 2) * 0.09, 0.62, (k % 2 - 0.5) * 0.12), Vector3(k, k, 0))
		"food":
			# provisions: a wooden crate with a lantern and a canteen on top, a barrel and a sack beside
			box(0.7, 0.45, 0.5, M.wood, Vector3(0, -0.3, 0))
			var slat := mat(0x6a4220, 0.85)
			for y in [-0.42, -0.27, -0.12]:
				box(0.72, 0.03, 0.52, slat, Vector3(0, y, 0))
			var post := mat(0x5a3618, 0.85)
			for x in [-0.33, 0.33]:
				box(0.05, 0.47, 0.53, post, Vector3(x, -0.3, 0))
			box(0.74, 0.05, 0.54, M.wood, Vector3(0.04, -0.05, 0.02), Vector3(0, 0.08, -0.06))
			cyl(0.07, 0.08, 0.04, M.dark, Vector3(-0.15, 0.0, 0))
			cyl(0.06, 0.06, 0.16, M.glass, Vector3(-0.15, 0.1, 0))
			cyl(0.035, 0.035, 0.1, M.lamp, Vector3(-0.15, 0.1, 0))
			cyl(0.07, 0.05, 0.04, M.dark, Vector3(-0.15, 0.2, 0))
			put(Geo.torus(0.04, 0.008, 6, 16, PI), M.dark, Vector3(-0.15, 0.22, 0))
			cyl(0.1, 0.1, 0.05, mat(0x4a6a3a, 0.6), Vector3(0.15, 0.05, 0), Vector3(PI / 2, 0, 0))
			cyl(0.015, 0.015, 0.05, M.steel, Vector3(0.15, 0.17, 0))
			var pts := []
			for k in 11:
				var t := k / 10.0
				pts.append(Vector2(0.2 + sin(t * PI) * 0.05, -0.25 + t * 0.5))
			put(Geo.lathe(pts, 24), M.wood, Vector3(0.62, -0.27, 0.1))
			for y in [-0.4, -0.14]:
				put(Geo.torus(0.23, 0.012, 6, 32), M.dark, Vector3(0.62, y, 0.1), Vector3(PI / 2, 0, 0))
			var sack := put(Geo.sphere(0.22, 24, 16), mat(0xc8b088, 0.95), Vector3(-0.55, -0.38, 0.15))
			sack.scale = Vector3(1, 1.15, 0.9)
			cyl(0.06, 0.03, 0.1, mat(0xa88860, 0.95), Vector3(-0.55, -0.1, 0.15))
			var bread := put(Geo.sphere(0.12, 20, 12), mat(0xb87a3a, 0.7), Vector3(0.05, -0.47, 0.38))
			bread.scale = Vector3(1.4, 0.6, 0.8)
		"lens":
			# the geologist's lens: a brass loupe on a wooden handle, held over a split geode of amethyst
			var brass := mat(0xc99a3a, 0.3, {metal = 0.9, env = 1.3})
			var loupe := group(Vector3(0.05, 0.22, 0.1))
			loupe.rotation = Vector3(-0.35, 0.0, 0.25)
			put(Geo.torus(0.36, 0.045, 12, 48), brass, Vector3.ZERO, Vector3.ZERO, loupe)
			cyl(0.34, 0.34, 0.02, M.glass, Vector3.ZERO, Vector3(PI / 2, 0, 0), loupe, 40)
			cyl(0.05, 0.05, 0.12, brass, Vector3(0, -0.44, 0), Vector3.ZERO, loupe)
			cyl(0.055, 0.045, 0.5, M.wood, Vector3(0, -0.74, 0), Vector3.ZERO, loupe)
			var shell := put(Geo.sphere(0.34, 24, 12, 0.0, TAU, PI / 2, PI / 2), mat(0x7d6b58, 0.95, {side = "double"}), Vector3(-0.1, -0.55, -0.15))
			shell.scale = Vector3(1, 0.8, 1)
			cyl(0.32, 0.32, 0.02, mat(0x5a4a3c, 0.9), Vector3(-0.1, -0.55, -0.15), Vector3.ZERO, null, 32)
			var am := mat(0x9a5ad8, 0.15, {emis = SpecMat.lin(0x6a2aa8) * 0.4})
			for k in 9:
				var a := k / 9.0 * TAU
				var r := 0.08 + (k % 3) * 0.07
				put(Geo.cone(0.045, 0.16, 6), am, Vector3(-0.1 + cos(a) * r, -0.5, -0.15 + sin(a) * r), Vector3(0.25 * sin(a), 0, -0.25 * cos(a)))
		_:
			# ventilation fan: shroud, guard ring, spinning blades, stand and a duct behind
			put(Geo.cylinder(0.56, 0.56, 0.32, 48, 1, true), mat(0xf2b01e, 0.42, {metal = 0.25, coat = 0.5, coat_r = 0.3, side = "double"}), Vector3(0, 0.1, 0), Vector3(PI / 2, 0, 0))
			for z in [-0.16, 0.16]:
				put(Geo.torus(0.57, 0.035, 10, 48), M.dark, Vector3(0, 0.1, z))
			var fan := group(Vector3(0, 0.1, 0.02))
			cyl(0.1, 0.1, 0.14, M.red, Vector3.ZERO, Vector3(PI / 2, 0, 0), fan)
			for k in 6:
				var bl := B.mesh(Geo.box(0.42, 0.13, 0.02).translate(0.26, 0, 0), M.steel, fan, Vector3.ZERO, B.eul_zxy(0.45, 0, k / 6.0 * 6.283))
				bl.name = "blade%d" % k
			for k in 8:
				var a := k / 8.0 * 6.283
				beam(Vector3(0, 0.1, 0.18), Vector3(cos(a) * 0.55, 0.1 + sin(a) * 0.55, 0.18), 0.008, M.dark)
			put(Geo.torus(0.3, 0.008, 6, 40), M.dark, Vector3(0, 0.1, 0.18))
			for x in [-0.35, 0.35]:
				beam(Vector3(x * 1.4, -0.72, 0), Vector3(x * 0.9, -0.3, 0), 0.035, M.dark)
			box(1.1, 0.06, 0.4, M.dark, Vector3(0, -0.74, 0))
			cyl(0.5, 0.5, 0.7, mat(0x5a6068, 0.5, {metal = 0.6}), Vector3(0, 0.1, -0.6), Vector3(PI / 2, 0, 0), null, 40)
			for k in 3:
				put(Geo.torus(0.51, 0.02, 6, 40), M.dark, Vector3(0, 0.1, -0.4 - k * 0.2))
			spinner(fan, "z", 9)
	root.set_meta("anim", anim)
	root.set_meta("glow", B.raw(0xf2b01e))
	root.rotation.y = -1.0 if id == "tbm" else -0.5
	return root
