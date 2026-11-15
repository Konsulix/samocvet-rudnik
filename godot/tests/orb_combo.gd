extends Node
## A resonator swapped with a special turns a colour into specials and fires them all (BoardModel.orb_color):
## none of them may stay on the board — not the ones under timber, crust or ice either.
##   "$G" --headless --path godot res://tests/orb_combo.tscn -- [n=40]
## Prints, over n boards with locks on some stones of the resonator's colour, how many specials were left standing.

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var n := int(args.get("n", "40"))
	var left_tot := 0
	var boards_bad := 0
	for i in n:
		var m := BoardModel.new()
		m.rng.seed = 100 + i
		m.setup(1, [], 0, {}, 0, false)
		var r := m.R / 2
		var c := m.C / 2 - 1
		var other: String = ["rh", "rv", "bomb", "drill"][i % 4]
		var colour := -1
		# the resonator's colour is the board's commonest (most_color): lock some of its stones, as on a level
		var a: BoardModel.Gem = m.G[r][c]
		var b: BoardModel.Gem = m.G[r][c + 1]
		if a == null or b == null: continue
		a.sp = "orb"; a.t = -1
		b.sp = other; b.t = -1
		colour = m.most_color()
		var locked := 0
		for rr in m.R:
			for cc in m.C:
				if not args.has("nolock") and m.col(rr, cc) == colour and (rr + cc + i) % 3 == 0 and not m.LOCK[rr][cc]:
					m.LOCK[rr][cc] = [1, 2, 4, 6][(rr * 7 + cc) % 4]
					locked += 1
		var res: Variant = m.swap(r, c, r, c + 1)
		if res == null: continue
		m.run_blast(res.events)
		var left := 0
		for rr in m.R:
			for cc in m.C:
				var g: BoardModel.Gem = m.G[rr][cc]
				if g and g.alive() and g.sp != "" and g.convert_sp != "": left += 1
		left_tot += left
		if left: boards_bad += 1
	print("QA orb combos: %d boards, %d with specials left standing, %d left in all" % [n, boards_bad, left_tot])
	get_tree().quit()
