extends Control
## Paid but not there: every gene a find rolls (its traits, what grows on it, its living effect) is priced (Worth) and
## named on the card only if the builder marks it grown. This builds a sample of finds — every mine's, human skulls,
## animal skulls — and counts for each gene how often it was rolled and how often it really grew; the misses with the
## species and form, so the cause can be found. Out: user://grow_audit.txt (+ .jsonl, one line a find).
##   godot --path godot --resolution 400x400 res://tests/grow_audit.tscn -- [n=25] [skulls=40] [beasts=3] [legend=5] [only=areas|skulls|beasts]
##   sp=wulfenite,bismuth n=12: only those species (in a pool or not), their kinds as the game rolls them

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var n := int(args.get("n", "25"))
	var only := String(args.get("only", ""))
	var finds := []
	var rng := Rng32.new(int(args.get("base", "11")))
	if args.has("sp"):
		only = "sp"
		var k := 0
		for sid: String in String(args.sp).split(","):
			for i in n:
				var sd := 400000 + k * 7919
				var s := Stones.roll(sd, 0, 1.5, int(rng.next() * 6))
				s.sid = sid
				s.kind = "nugget" if sid in Data.NUGGETY else "fossil" if Data.HABIT.get(sid, "") == "fossil" else String(Stones.pick_w(SpecLooks.kinds(sid), Rng32.new(sd * 977)))
				var nv := SpecLooks.never(sid)
				s.traits = (s.traits as Array).filter(func(t: String) -> bool: return not t in nv)
				s.legend = i % int(args.get("legend", "4")) == 0
				for e in ["fx", "form", "skin", "beast"]: s.erase(e)
				finds.append(s)
				k += 1
	if only in ["", "areas"]:
		for area in Data.AREAS.size():
			for i in n:
				var dl := int(rng.next() * 9)
				var s := Stones.roll(300000 + area * 70001 + i * 7919, area, 1.5, dl)
				if i % int(args.get("legend", "5")) == 0: s.legend = true
				finds.append(s)
	if only in ["", "skulls"]:
		for i in int(args.get("skulls", "40")):
			var s := Stones.roll(500000 + i * 7919, 6, 1.5, 8)
			s.sid = Stones.SKULL_SP[i % Stones.SKULL_SP.size()]
			s.kind = "druse"
			s.form = "skull"
			s.skin = Stones.SKULL_SKINS[i % Stones.SKULL_SKINS.size()]
			s.legend = i % 4 == 0
			finds.append(s)
	if only in ["", "beasts"]:
		var k := 0
		for b: String in SpecSkull.BEASTS:
			for j in int(args.get("beasts", "3")):
				var s := Stones.roll(600000 + k * 7919, 6, 1.5, 8)
				s.sid = Stones.SKULL_SP[k % Stones.SKULL_SP.size()]
				s.kind = "druse"
				s.form = "skull"
				s.beast = b
				s.skin = String(Stones.BEAST_SKIN[k % Stones.BEAST_SKIN.size()][0])
				s.legend = k % 4 == 1
				finds.append(s)
				k += 1
	var v := SpecView.new(int(args.get("px", "200")))
	v.size = Vector2(200, 200)
	v.still = true
	v.zoomable = false
	add_child(v)
	var rolled := {}
	var grown := {}
	var miss := {}
	var log := FileAccess.open("user://grow_audit.jsonl", FileAccess.WRITE)
	var t0 := Time.get_ticks_msec()
	for fi in finds.size():
		var s: Dictionary = finds[fi]
		var o := Spec.of_stone(s)
		var g := SpecGenome.of(o)
		# (a find made here — a skull or legendary forced after the roll — drops what its body cannot show, as Stones.roll does)
		if s.kind != "fossil" and (g.lost as Array).size():
			s.traits = (s.traits as Array).filter(func(t: String) -> bool: return not t in g.lost)
			o = Spec.of_stone(s)
			g = SpecGenome.of(o)
		var want: Array = (s.traits as Array).duplicate()
		for a: String in g.accents:
			if not a in want: want.append(a)
		if String(g.fx) != "": want.append("fx:" + String(g.fx))
		await v.show_spec(o)
		var got: Dictionary = v.live.get_meta("grown", {}) if v.live else {}
		var what := "%s/%s%s" % [s.sid, String(g.form), ("/" + String(s.get("beast", s.get("skin", "")))) if s.get("form", "") == "skull" else ""]
		var lost := []
		for id: String in want:
			var key := "fx" if id.begins_with("fx:") else id
			rolled[id] = int(rolled.get(id, 0)) + 1
			if got.has(key): grown[id] = int(grown.get(id, 0)) + 1
			else:
				lost.append(id)
				if not miss.has(id): miss[id] = {}
				miss[id][what] = int((miss[id] as Dictionary).get(what, 0)) + 1
		log.store_line(JSON.stringify({i = fi, what = what, want = want, lost = lost, pts = Worth.gene_points(s.traits, g)}))
		log.flush()
		if fi % 20 == 0: print("GROW ", fi, "/", finds.size(), "  ", (Time.get_ticks_msec() - t0) / 1000, " s")
	var ids: Array = rolled.keys()
	ids.sort_custom(func(x, y): return float(grown.get(x, 0)) / float(rolled[x]) < float(grown.get(y, 0)) / float(rolled[y]))
	var lines := PackedStringArray(["gene                 grew/rolled   lost on (species/form[/skin or beast])"])
	for id: String in ids:
		var r := int(rolled[id])
		var gr := int(grown.get(id, 0))
		if gr == r: continue
		var m: Dictionary = miss.get(id, {})
		var where: Array = m.keys()
		where.sort_custom(func(x, y): return int(m[x]) > int(m[y]))
		var ws := PackedStringArray()
		for w: String in where.slice(0, 8): ws.append("%s×%d" % [w, int(m[w])])
		lines.append("%-20s %3d/%-3d %4d%%  %s" % [id, gr, r, roundi(100.0 * gr / r), ", ".join(ws)])
	lines.append("all grew: " + ", ".join(PackedStringArray(ids.filter(func(x): return int(grown.get(x, 0)) == int(rolled[x])))))
	var txt := "\n".join(lines)
	print(txt)
	FileAccess.open("user://grow_audit.txt", FileAccess.WRITE).store_string(txt)
	get_tree().quit()
