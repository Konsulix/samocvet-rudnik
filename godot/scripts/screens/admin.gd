class_name Admin
extends RefCounted
## The tester's panel (Settings → Admin, or hold the gear → Diagnostics → Admin): jump into any depth of any mine, the boss fight
## or its hoard; hand out ore, coins, lives and gear; open the whole mine at once or start over. Not for players.

static func main() -> Node:
	return Engine.get_main_loop().current_scene

static func open() -> void:
	var a := Save.area()
	var v := Ov.card(360)
	v.add_child(UI.title("Admin", 20))
	v.add_child(Ov.text("%s · open to %d m · iron %d · %s %d · %s" % [Data.AREAS[a].n, Data.depth_m(a, int(Save.d.depth[a])),
		int(Save.d.fe), String(Data.ore(a).n).to_lower(), int(Save.d.ore), UI.coins(Save.d.coins)], 12))
	# the mine
	v.add_child(_head("Mine"))
	var mines := _row()
	for i in Data.AREAS.size():
		var k := i
		mines.add_child(_btn(String(Data.AREAS[i].n), i == a, func():
			if k != Save.area(): Save.open_mine(k)
			Save.persist()
			_reopen()))
	v.add_child(mines)
	# a level at any depth: the depth opens up to there
	v.add_child(_head("Play a level at"))
	var depths := _row()
	for k in Data.depths(a).size():
		var dl := k
		depths.add_child(_btn("%d m" % Data.depth_m(a, k), false, func(): _play(dl)))
	v.add_child(depths)
	var lv := _row()
	lv.add_child(_btn("Next is rich: %s" % ("yes" if Save.d.lrich else "no"), bool(Save.d.lrich), func():
		Save.d.lrich = not bool(Save.d.lrich)
		Save.persist()
		_reopen()))
	lv.add_child(_btn("Another level", false, func():
		Save.d.lseed = 1 + randi() % 999999
		Save.persist()
		Ov.toast("A new level is waiting")))
	v.add_child(lv)
	# the boss
	if Data.AREAS[a].has("boss"):
		var B: Dictionary = Data.AREAS[a].boss
		v.add_child(_head("Boss · %s" % B.n))
		var br := _row()
		br.add_child(_btn("Fight", false, func(): _play(Data.depths(a).size())))
		br.add_child(_btn("Open the hoard", false, func():
			Ov.close()
			var s := await Hoard.pick(Save.area())
			var rv := Reveal.new()
			rv.show_stone(s)))
		br.add_child(_btn("Beaten: %s" % ("yes" if Save.d.boss_won[a] else "no"), bool(Save.d.boss_won[a]), func():
			Save.d.boss_won[a] = not bool(Save.d.boss_won[a])
			Save.persist()
			_reopen()))
		v.add_child(br)
	# what to hand out
	v.add_child(_head("Give"))
	var give := _row()
	give.add_child(_btn("+100 iron", false, func(): _give("fe", 100)))
	give.add_child(_btn("+100 %s" % String(Data.ore(a).n).to_lower(), false, func(): _give("ore", 100)))
	give.add_child(_btn("+5000 coins", false, func(): _give("coins", 5000)))
	give.add_child(_btn("Full lives", false, func():
		Save.d.lives = Save.MAX_LIVES
		Save.d.life_at = 0
		_saved()))
	give.add_child(_btn("Lens %d → %d" % [int(Save.d.eq.lens), (int(Save.d.eq.lens) + 1) % 5], false, func():
		Save.d.eq.lens = (int(Save.d.eq.lens) + 1) % 5
		_saved()))
	v.add_child(give)
	# the whole mine at once, or from the very start
	v.add_child(_head("Progress"))
	var pr := _row()
	pr.add_child(_btn("Open all depths and jobs", false, func():
		var A: Dictionary = Data.AREAS[Save.area()]
		Save.d.depth[Save.area()] = Data.depths(Save.area()).size() - 1
		Save.d.built[Save.area()] = A.tasks.map(func(t): return t[0])
		_saved()))
	pr.add_child(_btn("Start over", false, func():
		Ov.close()
		Ov.panel("Start over?", "The whole save is wiped: progress, coins, the collection.", [
			["Wipe it", "red", func():
				Save.reset()
				Ov.close()
				main().show_home()],
			["Keep it", "glass", func(): Ov.close()]])))
	v.add_child(pr)
	v.add_child(Ov.btn("Close", "glass", func():
		Ov.close()
		_refresh()))

## into a level at depth dl (one past the last: the boss), the depth opened as far as that
static func _play(dl: int) -> void:
	var a := Save.area()
	var last := Data.depths(a).size() - 1
	Save.d.depth[a] = maxi(int(Save.d.depth[a]), mini(dl, last))
	Save.d.depth_sel[a] = mini(dl, last)
	Save.persist()
	Ov.close()
	main().show_level(Save.d.level, [], dl, LevelGen.current(dl))

static func _give(key: String, n: int) -> void:
	Save.d[key] = int(Save.d[key]) + n
	_saved()

static func _saved() -> void:
	Save.persist()
	Ov.toast("Done")
	_reopen()

static func _reopen() -> void:
	_refresh()
	open()

## the screen under the panel shows the new numbers
static func _refresh() -> void:
	var m := main()
	if m.screen is Home: m.show_home()

static func _head(t: String) -> Label:
	return UI.label(t, 13, UI.body_bold, UI.GOLD)

static func _row() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 6)
	f.add_theme_constant_override("v_separation", 6)
	return f

static func _btn(t: String, on: bool, fn: Callable) -> Button:
	var b := UI.button(t, "gold" if on else "glass", 13)
	b.custom_minimum_size = Vector2(0, 36)
	b.pressed.connect(fn)
	return b
