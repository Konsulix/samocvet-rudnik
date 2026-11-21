extends Control
## Gene pairs (21.11): do two genes on one stone get in each other's way? Per species, one seed built bare, with each
## gene alone and with every pair of them (genes the species may carry: SpecLooks.never respected) — in the same still
## pose. For each pair it flags:
##   hidden   a gene that shows alone (its own change of the picture) but, beside the other, all but vanishes —
##            yet still grows (a chip and a price for something unseen)
##   lost     a gene that grows alone but not in the pair, with no rule saying so (SpecGenome.lost would say)
##   ruled    one the genome drops in the pair on purpose (lost) — fine, listed to read the rules over
##   layout   a gene that sets the layout alone, overridden in the pair by the other one's
##   spot     the two genes' callouts on the same spot of the stone
## Out: user://pairs/pairs_<species>.jsonl (a line a pair), and a strip for every flagged pair — bare, A, B, A+B
## (user://pairs/<sid>_<a>_<b>.png).
##   godot --path godot --resolution 240x240 res://tests/pair_audit.tscn -- [sp=quartz,amethyst] [seed=4321] [kind=druse]
##   [genes=twin,atypical,...] [px=200] [append] [all — a strip for every pair, flagged or not]

const TRAITS := ["irid", "aurora", "zoned", "phantom", "chlorite", "anomaly", "twin", "druzy", "bubbles", "enhydro",
	"rutile", "goldfleck", "floater", "scepter", "silver", "limonite", "moss", "coral", "atypical", "inkspots", "clouds"]
const ACCENTS := ["pompom", "straw", "lichen", "needles", "crust", "dust", "fronds", "flowers", "mushrooms"]
const CMP := 96          # the pictures are compared this small
const SEEN := 0.006      # a gene that changes less of the picture than this alone is not judged for hiding
const HIDDEN := 0.25     # beside the other, under this share of its own change: hidden

var view: SpecView
var px := 200

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	px = int(args.get("px", "200"))
	var species: Array = Array(String(args.get("sp", "quartz,amethyst,fluorite,calcite,garnet")).split(","))
	var sd := int(args.get("seed", "4321"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://pairs"))
	var log := FileAccess.open("user://pairs/pairs_%s.jsonl" % "_".join(species), FileAccess.WRITE if not args.has("append") else FileAccess.READ_WRITE)
	if args.has("append"): log.seek_end()
	view = SpecView.new(px)
	view.size = Vector2(px, px)
	view.still = true
	view.zoomable = false
	add_child(view)
	for sid: String in species:
		var kind := String(args.get("kind", String(Stones.pick_w(SpecLooks.kinds(sid), Rng32.new(sd * 977)))))
		var nv := SpecLooks.never(sid)
		var genes: Array = (Array(String(args.genes).split(",")) if args.has("genes") else TRAITS + ACCENTS).filter(
			func(g: String) -> bool: return not g in nv)
		var t0 := Time.get_ticks_msec()
		var bare := await _shot(_find(sid, sd, kind, []))
		var one := {}
		for g: String in genes:
			one[g] = await _shot(_find(sid, sd, kind, [g]))
		var flagged := 0
		for i in genes.size():
			for j in range(i + 1, genes.size()):
				var a: String = genes[i]
				var b: String = genes[j]
				var ab := await _shot(_find(sid, sd, kind, [a, b]))
				var A: Dictionary = one[a]
				var B: Dictionary = one[b]
				var row := {sid = sid, a = a, b = b, flags = []}
				for pr: Array in [[a, b, A, B], [b, a, B, A]]:
					var g: String = pr[0]
					var o: String = pr[1]
					var G: Dictionary = pr[2]
					var O: Dictionary = pr[3]
					var alone := _diff(bare.img, G.img)
					var beside := _diff(O.img, ab.img)
					if g in (ab.lost as Array):
						if not g in (G.lost as Array): row.flags.append("ruled:%s (beside %s)" % [g, o])
						continue
					if G.grown.has(g) and not ab.grown.has(g): row.flags.append("lost:%s (beside %s)" % [g, o])
					if ab.grown.has(g) and alone > SEEN and beside < alone * HIDDEN:
						row.flags.append("hidden:%s by %s (%.3f -> %.3f)" % [g, o, alone, beside])
					if G.form != bare.form and ab.form != G.form:
						row.flags.append("layout:%s %s -> %s (by %s)" % [g, G.form, ab.form, o])
				var pa: Array = ab.grown.get(a, [])
				var pb: Array = ab.grown.get(b, [])
				if pa.size() and pb.size():
					var d := ((pa[0] as Array)[0] as Vector3).distance_to((pb[0] as Array)[0] as Vector3)
					if d < ab.span * 0.025: row.flags.append("spot:%s,%s" % [a, b])
				if (row.flags as Array).size() or args.has("all"):
					if (row.flags as Array).size(): flagged += 1
					_strip([bare.img, A.img, B.img, ab.img]).save_png("user://pairs/%s_%s_%s.png" % [sid, a, b])
					print("PAIR ", sid, " ", a, "+", b, ": ", ", ".join(row.flags))
				log.store_line(JSON.stringify(row))
				log.flush()
		print("SPECIES %s: %d genes, %d pairs, %d flagged, %d s" % [sid, genes.size(), genes.size() * (genes.size() - 1) / 2, flagged, (Time.get_ticks_msec() - t0) / 1000])
	get_tree().quit()

func _find(sid: String, sd: int, kind: String, genes: Array) -> Dictionary:
	var o := {seed = sd, sid = sid, kind = kind, gi = 2, traits = [], accents = []}
	for g: String in genes:
		if g in ACCENTS: o.accents.append(g)
		else: o.traits.append(g)
	return o

## builds a find, waits, renders it once: its picture (small, for comparing), what grew, its layout, what the genome dropped
func _shot(o: Dictionary) -> Dictionary:
	await view.show_spec(o)
	for f in 4: await get_tree().process_frame
	view.studio.vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := view.studio.vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var g := SpecGenome.of(o)
	var grown: Dictionary = view.live.get_meta("grown", {}) if view.live else {}
	var span := 1.0
	if view.live:
		var bb := AABB()
		var first := true
		for n in view.live.find_children("*", "MeshInstance3D", true, false):
			var ab: AABB = (n as MeshInstance3D).global_transform * (n as MeshInstance3D).get_aabb()
			bb = ab if first else bb.merge(ab)
			first = false
		span = bb.size.length()
	return {img = img, grown = grown, form = String(g.form), lost = g.get("lost", []), span = span}

## the share of the picture that changed (small copies, a pixel counts when a channel moved over 0.06)
func _diff(a: Image, b: Image) -> float:
	var x := a.duplicate() as Image
	var y := b.duplicate() as Image
	x.resize(CMP, CMP, Image.INTERPOLATE_BILINEAR)
	y.resize(CMP, CMP, Image.INTERPOLATE_BILINEAR)
	var da := x.get_data()
	var db := y.get_data()
	var n := 0
	for i in range(0, da.size(), 3):
		if absi(da[i] - db[i]) > 15 or absi(da[i + 1] - db[i + 1]) > 15 or absi(da[i + 2] - db[i + 2]) > 15: n += 1
	return float(n) / float(CMP * CMP)

func _strip(imgs: Array) -> Image:
	var w := (imgs[0] as Image).get_width()
	var h := (imgs[0] as Image).get_height()
	var out := Image.create(w * imgs.size() + 6 * (imgs.size() - 1), h, false, Image.FORMAT_RGB8)
	out.fill(Color(0.3, 0.3, 0.3))
	for i in imgs.size():
		out.blit_rect(imgs[i], Rect2i(0, 0, w, h), Vector2i(i * (w + 6), 0))
	return out
