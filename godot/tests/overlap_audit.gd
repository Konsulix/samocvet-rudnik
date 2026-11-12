extends Node
## What grows into the crystals. The builder keeps things off the crystals by their boxes, and mostly by the one
## point a thing is rooted at — a cap, a bush or a tuft can still reach into a crystal. This builds a sample of finds
## and measures it on the real geometry: for every thing on the find that is not rock or crystal (told by its gene,
## its mesh and its shader) a handful of its points are tried against every crystal's own triangles; the share of
## them inside is how deep it sits in the glass. Out: a table by gene (how many were looked at, how many are sunk —
## a quarter or more of them inside — and how many only touch), the worst finds with their seeds, in
## user://overlap_audit.txt.
##   "$G" --headless --path godot res://tests/overlap_audit.tscn -- [n=10] [areas=0,1,2] [sp=quartz,garnet] [force] [noclear]
## noclear: without the builder's own pass that takes such things away (SpecSolid.clear) — how it was before it.
## force: every find is given the whole living layer (lichen, fronds, flowers, needles, mushrooms of a kind by its
## seed, flowers of a kind by its seed) — the genes are rare, and a sample without it sees few of them.

const SUNK := 0.25
const TOUCH := 0.06
const PTS := 14

var _tri_cache := {}

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var n := int(args.get("n", "10"))
	var force := args.has("force")
	SpecSolid.on = not args.has("noclear")
	var finds := []
	if args.has("sp"):
		var k := 0
		for sid: String in String(args.sp).split(","):
			for i in n:
				var sd := 610000 + k * 7919
				var s := Stones.roll(sd, 0, 1.5, i % 6)
				s.sid = sid
				s.kind = "nugget" if sid in Data.NUGGETY else "fossil" if Data.HABIT.get(sid, "") == "fossil" else String(Stones.pick_w(SpecLooks.kinds(sid), Rng32.new(sd * 977)))
				var nv := SpecLooks.never(sid)
				s.traits = (s.traits as Array).filter(func(t: String) -> bool: return not t in nv)
				finds.append(s)
				k += 1
	else:
		var areas: Array = Array(String(args.get("areas", "0,1,2,3,4,5,6,7")).split(","))
		for a: String in areas:
			for i in n:
				finds.append(Stones.roll(620000 + int(a) * 1000 + i * 13, int(a), 1.5, i % 6))
	# one=<area>,<i> shot=user://x.png: that one find of the sample alone, shown and saved as a picture (not headless)
	if args.has("one"):
		var ai := String(args.one).split(",")
		finds = [Stones.roll(620000 + int(ai[0]) * 1000 + int(ai[1]) * 13, int(ai[0]), 1.5, int(ai[1]) % 6)]
	var stat := {}      # label -> [looked at, sunk, touching, sum of shares]
	var worst := []     # [share, label, text]
	var t0 := Time.get_ticks_msec()
	for fi in finds.size():
		var s: Dictionary = finds[fi]
		var o := Spec.of_stone(s)
		if force and String(s.kind) != "fossil":
			var sd := int(s.id)
			o.accents = ["lichen", "fronds", "flowers", "needles", "pompom", "straw", "mushrooms"]
			o.shroom = [0, 1, 2, 3, 5, 6, 7][sd % 7]
			o.flora = sd % SpecFlora.KINDS.size()
		var g := SpecGenome.of(o)
		var root := SpecimenBuilder.build(o)
		if root == null: continue
		var what := "%s/%s seed %d" % [s.sid, String(g.form), int(s.id)]
		_look(root, what, stat, worst)
		if args.has("one") and args.has("shot"):
			var v := SpecView.new(700)
			v.size = Vector2(700, 700)
			v.still = true
			add_child(v)
			await v.show_spec(o)
			await get_tree().create_timer(1.5).timeout
			get_viewport().get_texture().get_image().save_png(String(args.shot))
		root.free()
		if fi % 20 == 0: print("OVERLAP ", fi, "/", finds.size(), "  ", (Time.get_ticks_msec() - t0) / 1000, " s")
	var labels: Array = stat.keys()
	labels.sort_custom(func(x, y): return float(stat[x][1]) / float(stat[x][0]) > float(stat[y][1]) / float(stat[y][0]))
	var lines := PackedStringArray(["what (gene / mesh or shader)                    looked at   sunk   touching   mean inside"])
	for lb: String in labels:
		var st: Array = stat[lb]
		lines.append("%-48s %7d  %4.0f%%  %7.0f%%  %10.1f%%" % [lb, int(st[0]), 100.0 * float(st[1]) / float(st[0]), 100.0 * float(st[2]) / float(st[0]), 100.0 * float(st[3]) / float(st[0])])
	worst.sort_custom(func(x, y): return float(x[0]) > float(y[0]))
	lines.append("")
	lines.append("the worst:")
	for w: Array in worst.slice(0, 40):
		lines.append("  %3.0f%% inside  %-34s %s" % [100.0 * float(w[0]), w[1], w[2]])
	var txt := "\n".join(lines)
	var f := FileAccess.open("user://overlap_audit.txt", FileAccess.WRITE)
	f.store_string(txt)
	f.close()
	print(txt)
	get_tree().quit()

## one find: its crystals, then everything else on it
func _look(root: Node3D, what: String, stat: Dictionary, worst: Array) -> void:
	var crystals := []      # {inv, box, tris}
	var things := []
	for c: Node in root.find_children("*", "GeometryInstance3D", true, false):
		if c.get_meta("crystal", false):
			if c.has_meta("geo"):
				var geo: Geo = c.get_meta("geo")
				crystals.append({inv = SpecUtil.rel_xform(c as Node3D, root).affine_inverse(), box = geo.aabb(), geo = geo})
			continue
		if c.has_meta("base") or c.has_meta("rock") or c.has_meta("box") or c.has_meta("ground") or c.has_meta("sea_light"): continue
		if c.get_meta("gene", "") == "body": continue
		# (what lies inside a crystal on purpose — its inclusions, its clouds — is the crystal's own child)
		var inside_one := false
		var p := c.get_parent()
		while p and p != root:
			if p.get_meta("crystal", false): inside_one = true
			p = p.get_parent()
		if inside_one: continue
		things.append(c)
	if crystals.is_empty(): return
	for c: Node3D in things:
		var mesh: Mesh = (c as MultiMeshInstance3D).multimesh.mesh if c is MultiMeshInstance3D else (c as MeshInstance3D).mesh if c is MeshInstance3D else null
		if mesh == null: continue
		var pts := _points(c, mesh)
		if pts.is_empty(): continue
		var lb := _label(c, mesh)
		var base := SpecUtil.rel_xform(c, root)
		var xfs := []
		if c is MultiMeshInstance3D:
			# (its copies from the buffer the builder kept beside it: the renderer gives none back without a screen)
			var mm := (c as MultiMeshInstance3D).multimesh
			var key := "ibuf" if c.has_meta("ibuf") else "mmbuf" if c.has_meta("mmbuf") else ""
			if key == "": continue
			var buf: PackedFloat32Array = c.get_meta(key)
			var stride := 12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0)
			var count := buf.size() / stride
			var step := maxi(1, count / 120)
			for k in range(0, count, step):
				var i := k * stride
				xfs.append(base * Transform3D(Basis(Vector3(buf[i], buf[i + 4], buf[i + 8]), Vector3(buf[i + 1], buf[i + 5], buf[i + 9]), Vector3(buf[i + 2], buf[i + 6], buf[i + 10])),
					Vector3(buf[i + 3], buf[i + 7], buf[i + 11])))
		else:
			xfs.append(base)
		for xf: Transform3D in xfs:
			var hit := 0
			for q: Vector3 in pts:
				if _inside(xf * q, crystals): hit += 1
			var share := float(hit) / pts.size()
			if not stat.has(lb): stat[lb] = [0, 0, 0, 0.0]
			var st: Array = stat[lb]
			st[0] = int(st[0]) + 1
			if share >= SUNK: st[1] = int(st[1]) + 1
			elif share >= TOUCH: st[2] = int(st[2]) + 1
			st[3] = float(st[3]) + share
			if share >= SUNK: worst.append([share, lb, what])

## a handful of a mesh's own points, evenly through its list
func _points(c: Node3D, mesh: Mesh) -> Array:
	var src := PackedVector3Array()
	if c.has_meta("geo"):
		src = (c.get_meta("geo") as Geo).v
	else:
		if not _tri_cache.has(mesh): _tri_cache[mesh] = mesh.get_faces()
		src = _tri_cache[mesh]
	var out := []
	if src.is_empty(): return out
	var step := maxi(1, src.size() / PTS)
	for i in range(0, src.size(), step): out.append(src[i])
	return out

func _label(c: Node3D, mesh: Mesh) -> String:
	var gene := String(_gene_of(c))
	var mp := mesh.resource_path
	var kind := ""
	if "/fungi/" in mp: kind = "mushroom " + mp.get_file().get_basename()
	elif "/flora/" in mp: kind = "flower " + mp.get_file().get_basename()
	else:
		var m: Material = (c as GeometryInstance3D).material_override
		if m is ShaderMaterial and (m as ShaderMaterial).shader:
			kind = (m as ShaderMaterial).shader.resource_path.get_file().get_basename()
		if kind == "": kind = "mesh"
		if c is MultiMeshInstance3D: kind += " ×"
	return "%s / %s" % [gene, kind]

func _gene_of(c: Node) -> String:
	var p := c
	while p:
		if p.has_meta("gene"): return String(p.get_meta("gene"))
		p = p.get_parent()
	return "?"

## is the point (in the find's space) inside any crystal: by the crystal's own triangles, a ray counted through them
## (every triangle, not SpecSolid's grid of columns: the builder's pass is checked by another hand)
func _inside(p: Vector3, crystals: Array) -> bool:
	for cr: Dictionary in crystals:
		var q: Vector3 = (cr.inv as Transform3D) * p
		if not (cr.box as AABB).has_point(q): continue
		var geo: Geo = cr.geo
		# (up the crystal: many have no floor — it is in the rock — and a ray leaving through that hole miscounts)
		var d := Vector3(0.0031, 0.99999, 0.0017)
		var hits := 0
		var nt := geo.tri_count()
		for t in nt:
			var a: Vector3
			var b: Vector3
			var c3: Vector3
			if geo.indexed():
				a = geo.v[geo.idx[t * 3]]
				b = geo.v[geo.idx[t * 3 + 1]]
				c3 = geo.v[geo.idx[t * 3 + 2]]
			else:
				a = geo.v[t * 3]
				b = geo.v[t * 3 + 1]
				c3 = geo.v[t * 3 + 2]
			var e1 := b - a
			var e2 := c3 - a
			var h := d.cross(e2)
			var det := e1.dot(h)
			if absf(det) < 1e-12: continue
			var f := 1.0 / det
			var sv := q - a
			var u := f * sv.dot(h)
			if u < 0.0 or u > 1.0: continue
			var qv := sv.cross(e1)
			var v := f * d.dot(qv)
			if v < 0.0 or u + v > 1.0: continue
			if f * e2.dot(qv) > 1e-9: hits += 1
		if hits % 2 == 1: return true
	return false
