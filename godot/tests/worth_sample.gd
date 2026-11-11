extends Node
## Prices of a sample of finds: per mine the mean, median and 90th percentile, the dearest and cheapest with their
## genes — to see that beauty, not the species name, makes a stone dear (Worth, Stones.roll).
##   godot --headless --path godot res://tests/worth_sample.tscn -- [n=200] [out=user://worth.txt]

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var n := int(args.get("n", "200"))
	var lines := PackedStringArray()
	for area in mini(5, Data.AREAS.size()):
		var all := []
		for i in n:
			var dl := i % 6
			var s := Stones.roll(700000 + area * 100003 + i * 7919, area, 0.4 + dl * 0.35, dl)
			var g := SpecGenome.of({seed = s.id, sid = s.sid, kind = s.kind, gi = s.gi, traits = s.traits, legend = s.legend,
				form = s.get("form", ""), skin = s.get("skin", "")} if s.has("skin") else {seed = s.id, sid = s.sid, kind = s.kind, gi = s.gi, traits = s.traits, legend = s.legend})
			var genes: Array = (s.traits as Array).duplicate()
			genes.append_array(g.accents)
			if String(g.fx) != "": genes.push_front("FX:" + String(g.fx))
			all.append([int(s.value), "%s/%s d%d %s" % [s.sid, s.kind, dl, ",".join(PackedStringArray(genes))]])
		all.sort_custom(func(x, y): return x[0] < y[0])
		var sum := 0
		for e in all: sum += int(e[0])
		lines.append("AREA %d  mean %d  median %d  p90 %d" % [area, sum / n, all[n / 2][0], all[n * 9 / 10][0]])
		lines.append("  dearest:")
		for e in all.slice(n - 8).duplicate(): lines.append("    %6d  %s" % [e[0], e[1]])
		lines.append("  cheapest:")
		for e in all.slice(0, 6): lines.append("    %6d  %s" % [e[0], e[1]])
		# a plain stone of the dearest species against a common one rich in genes
		var rich := all.filter(func(e): return String(e[1]).count(",") >= 3 and not String(e[1]).contains("FX:"))
		lines.append("  gene-rich (4+ genes, not legendary):")
		for e in rich.slice(0, 6): lines.append("    %6d  %s" % [e[0], e[1]])
	var txt := "\n".join(lines)
	print(txt)
	var f := FileAccess.open(String(args.get("out", "user://worth.txt")), FileAccess.WRITE)
	f.store_string(txt)
	get_tree().quit()
