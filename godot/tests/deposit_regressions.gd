extends Node
## Headless checks for four-hit extraction and persistent empty 2x2 shells.

var failed := false

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func specimen() -> BoardModel:
	var m := BoardModel.new()
	m.rng.seed = 47
	m.setup(22, [], 0, {}, 0)
	check(not m.find.is_empty(), "Test level must contain a specimen")
	return m

func touch_find(m: BoardModel, kind: String) -> void:
	# One area blast covering all four cells is one contact, not four.
	var events := []
	for d in BoardModel.QUAD:
		events.append({r = m.find.r + d.x, c = m.find.c + d.y, t = 0.0, kind = kind})
	m.run_blast(events)

func _ready() -> void:
	for level_n in [1, 22, 120]:
		for depth in [0, 4]:
			var m := BoardModel.new()
			m.setup(level_n, [], depth, {}, 0)
			if not m.find.is_empty(): check(m.find.hp == 4, "Every specimen must need at most four contacts")
	for rough_count in range(5):
		var m := specimen()
		for i in 4:
			touch_find(m, "fx" if i < rough_count else "adj")
			check(m.find.hp == 3 - i, "A four-cell blast must remove one layer")
			check(m.find.done == (i == 3), "Extraction must complete exactly on contact four")
		check(m.find.integ == 100 - rough_count * 25, "Each direct booster must damage integrity by 25")
		check(m.find.ruined == (rough_count == 4), "Only four direct boosters must destroy the specimen")
		var gi := m.goal_index("find")
		check(m.goals[gi].left == 0, "Both extraction and destruction must resolve the target")
		for d in BoardModel.QUAD:
			var r: int = m.find.r + d.x
			var c: int = m.find.c + d.y
			check(m.open(r, c) == (rough_count < 4), "Only a destroyed specimen must keep blocking its four cells")
		check(m.extracted_stone().is_empty() == (rough_count == 4), "Destroyed specimens must never become collection rewards")
		m.collapse()
		for d in BoardModel.QUAD:
			var gem: BoardModel.Gem = m.G[m.find.r + d.x][m.find.c + d.y]
			check((gem == null) == (rough_count == 4), "Gravity must fill released cells and leave the shell empty")
		touch_find(m, "fx")
		check(m.find.hp == 0 and m.goals[gi].left == 0, "Resolved specimens must ignore further hits")
	var pick := specimen()
	touch_find(pick, "pick")
	check(pick.find.integ == 75, "A directly applied pick booster must also damage the specimen")
	var m := BoardModel.new()
	m.setup(1, [], 0, {}, 0, false)
	m.geos = [{r = 3, c = 3, hp = 4}]
	m.goals = [{k = "geo", t = -1, left = 1}]
	var ev := []
	for d in BoardModel.QUAD:
		m.G[3 + d.x][3 + d.y] = null
		m.GEOC[3 + d.x][3 + d.y] = 0
		ev.append({r = 3 + d.x, c = 3 + d.y, t = 0.0, kind = "fx"})
	m.run_blast([{r = 2, c = 3, t = 0.0, kind = "fx"}])
	check(m.geos[0].hp == 4, "A booster hitting only a neighboring cell must not hit the geode")
	for i in 4: m.run_blast(ev)
	check(m.geos[0].hp == 0 and m.goals[0].left == 0, "Four boosters must open the geode without spoiling its reward")
	check(m.bonus.size() == 1, "Geodes must award exactly one undamaged reward")
	m.collapse()
	for d in BoardModel.QUAD:
		check(not m.open(3 + d.x, 3 + d.y) and m.G[3 + d.x][3 + d.y] == null, "The collected geode must remain an occupied shell")
	m.run_blast(ev)
	check(m.geos[0].hp == 0 and m.bonus.size() == 1, "Repeated hits must not collect a shell again")
	# With another geode outstanding, drills must ignore the completed shell.
	m.goals[0].left = 1
	for i in 20:
		var target := m.drill_target(0, 0)
		check(target.x < 0 or m.GEOC[target.x][target.y] < 0, "Drills must not target already collected shells")
	var view := BoardView.new()
	add_child(view)
	view.animate_deposit("mineral", 0, 3, -1)
	check(view.deposit_transitions.has("mineral:0"), "Successful extraction must keep its outgoing sprite during the transition")
	await get_tree().create_timer(BoardView.DEPOSIT_TRANSITION + 0.1).timeout
	check(view.deposit_transitions.is_empty(), "Completed transitions must remove their outgoing sprite")
	view.queue_free()
	print("DEPOSIT REGRESSIONS: ", "FAILED" if failed else "PASS")
	get_tree().quit(1 if failed else 0)
