extends Node
## The Fire Maiden's rules (BoardModel.maiden_*, docs/fire-maiden.md): leaps gild the stone she lands on, the marks
## grow from 2 to 3, from the third phase her gold cools in two moves, five catches finish the goal; her gift is
## legendary gold. `res://tests/maiden_check.tscn`, prints RESULT PASS/FAIL
func _ready() -> void:
	await get_tree().process_frame
	var bad: Array = []
	var m := BoardModel.new()
	m.rng.seed = 7
	m.setup(1, [], 0, {}, 0, false, Level.MAIDEN)
	for r in m.R:
		for c in m.C:
			if m.G[r][c] and (m.G[r][c] as BoardModel.Gem).ore != "": bad.append("ore on the board at start")
	if (m.maiden.marks as Array).size() != 2: bad.append("marks at start %d" % (m.maiden.marks as Array).size())
	for i in 4:
		var h := m.maiden_hop()
		var to: Vector2i = h.to
		if to.x < 0: bad.append("no leap")
		elif (m.G[to.x][to.y] as BoardModel.Gem).ore != "ore": bad.append("leap %d: no gold" % i)
	# caught twice: three marks
	for i in 2:
		var at := Vector2i(int(m.maiden.r), int(m.maiden.c))
		if not m.maiden_catch([at + Vector2i(0, 1)]).is_empty(): bad.append("caught from beside her (only her stone counts)")
		if m.maiden_catch([at]).is_empty(): bad.append("catch %d gave no gold" % i)
	if (m.maiden.marks as Array).size() != 3: bad.append("marks after 2 catches %d" % (m.maiden.marks as Array).size())
	if not m.maiden_catch([Vector2i(-9, -9)]).is_empty(): bad.append("caught from afar")
	for i in 2: m.maiden_catch([Vector2i(int(m.maiden.r), int(m.maiden.c))])
	# phase 3: the gold of a leap cools after two moves
	var h3 := m.maiden_hop()
	var gid := int(h3.gold)
	var h4 := m.maiden_hop()
	var h5 := m.maiden_hop()
	if not (h4.cooled as Array).has(gid) and not (h5.cooled as Array).has(gid): bad.append("phase 3 gold did not cool")
	if m.goals_done(): bad.append("done at 4 catches")
	m.maiden_catch([Vector2i(int(m.maiden.r), int(m.maiden.c))])
	if not m.goals_done(): bad.append("not done at 5 catches")
	var s := Stones.maiden_gold(4242)
	if String(s.sid) != "gold" or not bool(s.legend) or String(s.get("fx", "")) != "lava": bad.append("gift %s" % s)
	print("gift value ", s.value, " tier ", s.tier)
	print("RESULT ", "PASS" if bad.is_empty() else "FAIL " + str(bad))
	get_tree().quit()
