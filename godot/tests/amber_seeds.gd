extends Node
## Seeds whose amber holds an insect, of every group and every model (SpecFlower.BUGS), and every plant (SPRIGS) — for a look at them on a
## real find card:
##   "$G" --headless --path godot res://tests/amber_seeds.tscn -- [upto=6000] [all]
## then `-- reveal=<seed> sid=amber kind=fossil` (the stone as `reveal` rolls it). `all`: a seed for every model, not
## only for every group.

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var seen := {}
	var want := 0
	for gk: String in SpecFlower.BUGS: want += (SpecFlower.BUGS[gk] as Array).size() if args.has("all") else 1
	for gk: String in SpecFlower.SPRIGS: want += (SpecFlower.SPRIGS[gk] as Array).size()
	for sd in range(1, int(args.get("upto", "6000")) + 1):
		var st := Stones.roll(sd, Save.area(), 0.8, 1)
		st.sid = "amber"
		st.kind = "fossil"
		var f: Dictionary = SpecGenome.of(Spec.of_stone(st)).fossil
		if f.has("sprig"):
			if seen.has(f.sprig): continue
			seen[f.sprig] = sd
			print("amber ", f.content, " ", f.sprig, " (", SpecFlower.bug_name(String(f.sprig)), ", ", f.host, " ", f.tone, "): reveal=", sd)
			if seen.size() == want: break
			continue
		if f.content != "insect": continue
		var key := String(f.bug) if args.has("all") else String(f.insect)
		if seen.has(key): continue
		seen[key] = sd
		print("amber ", f.insect, " ", f.bug, " (", SpecFlower.bug_name(String(f.bug)), ", ", f.host, " ", f.tone, "): reveal=", sd)
		if seen.size() == want: break
	get_tree().quit()
