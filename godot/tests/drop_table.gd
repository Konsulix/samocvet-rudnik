extends Node
## What turns up where: per mine, a sample of finds rolled as the board rolls them (Stones.roll over its depths) —
## species, layouts, traits, what grows on them, butterflies, mushrooms, skulls — and, from the same finds made
## legendary, its living effects. Then what turns up nowhere. Out: user://drop_table.json
##   godot --headless --path godot res://tests/drop_table.tscn -- [n=3000] [leg=400]

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var n := int(args.get("n", "3000"))
	var nl := int(args.get("leg", "400"))
	var out := {areas = [], all = {}}
	var seen := {sp = {}, traits = {}, acc = {}, fx = {}, fly = {}, shroom = {}, skin = {}, beast = {}, form = {}, kind = {}, flora = {}, tie = {}, legend = {}}
	for area in Data.AREAS.size():
		var A: Dictionary = Data.AREAS[area]
		var last := maxi(1, Data.depths(area).size())
		var c := {sp = {}, traits = {}, acc = {}, fx = {}, fly = {}, shroom = {}, skin = {}, beast = {}, form = {}, kind = {}, flora = {}, tie = {}, legend = {}, value = []}
		for i in n + nl:
			var dl := i % last
			var s := Stones.roll(900000 + area * 1000003 + i * 7919, area, 0.2 + dl * 0.35, dl)
			var legend_run := i >= n
			if legend_run:
				s.legend = true
			var g := SpecGenome.of(Spec.of_stone(s))
			if legend_run:
				if String(g.fx) != "": _add(c.fx, String(g.fx))
				continue
			c.value.append(int(s.value))
			_add(c.sp, String(s.sid))
			_add(c.kind, String(s.kind))
			_add(c.form, String(g.form))
			for t: String in s.traits: _add(c.traits, t)
			for a2: String in g.accents:
				if a2.begins_with("fly_"): continue
				_add(c.acc, a2)
			for k: String in g.get("fly_kinds", []): _add(c.fly, k)
			if int(g.shroom) >= 0: _add(c.shroom, SpecFungi.NAMES[int(g.shroom)])
			if (g.accents as Array).has("flowers"): _add(c.flora, SpecFlora.NAMES[int(g.flora)])
			if String(g.get("pseudo", "")) != "": _add(c.tie, "%s after %s" % [s.sid, g.pseudo])
			if String(g.get("assoc", "")) != "": _add(c.tie, "%s with %s" % [s.sid, g.assoc])
			if s.legend: _add(c.legend, "legendary")
			if s.get("form", "") == "skull":
				_add(c.skin, String(s.skin))
				if s.has("beast"): _add(c.beast, String(s.beast))
			if s.legend and String(g.fx) != "": _add(c.fx, String(g.fx))
		for k: String in seen:
			for id: String in c[k]: seen[k][id] = true
		var vals: Array = c.value
		vals.sort()
		c.value = {mean = vals.reduce(func(x, y): return x + y, 0) / vals.size(), median = vals[vals.size() / 2], p90 = vals[vals.size() * 9 / 10]}
		out.areas.append({name = String(A.n), n = n, pool = A.get("pool", {}), c = c})
	# everything there is, to find what never turns up
	var every := {
		sp = Data.SP.keys(),
		traits = Data.TRAITS.map(func(t: Dictionary) -> String: return String(t.id)),
		acc = SpecGenome.ACC_N.keys().filter(func(k: String) -> bool: return not k.begins_with("fly_")),
		fx = SpecLegend.FX_N.keys(),
		fly = SpecButterfly.KINDS.keys(),
		shroom = Array(SpecFungi.NAMES),
		skin = Stones.SKULL_SKINS + Stones.BEAST_SKIN.map(func(e: Array) -> String: return String(e[0])),
		beast = Array(SpecSkull.BEASTS),
		form = SpecGenome.FORM_N.keys()}
	var never := {}
	for k: String in every:
		var lst := []
		for id in every[k]:
			if not seen[k].has(String(id)) and not String(id) in lst: lst.append(String(id))
		never[k] = lst
	out.never = never
	# the names the card shows, for a readable report
	var nm := {sp = {}, traits = {}, acc = SpecGenome.ACC_N, form = SpecGenome.FORM_N, fx = SpecLegend.FX_N, beast = SpecSkull.BEAST_N}
	for id: String in Data.SP: nm.sp[id] = String(Data.SP[id].n)
	for t: Dictionary in Data.TRAITS: nm.traits[String(t.id)] = String(t.n)
	out.names = nm
	FileAccess.open("user://drop_table.json", FileAccess.WRITE).store_string(JSON.stringify(out, " "))
	print("NEVER ", JSON.stringify(never))
	get_tree().quit()

func _add(d: Dictionary, id: String) -> void:
	d[id] = int(d.get(id, 0)) + 1
