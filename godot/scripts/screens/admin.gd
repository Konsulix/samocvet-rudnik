class_name Admin
extends RefCounted
## The tester's panel (Settings → Admin, or hold the gear → Diagnostics → Admin): jump into any depth of any mine, the boss fight
## or its hoard; hand out ore, coins, lives and gear; put any kind of find into the collection; open the whole mine at
## once or start over. Not for players.

## the find to make: species ("" any), kind ("" as it falls), legendary effect ("" none, "?" any), rare traits
static var f_sid := ""
static var f_kind := ""
static var f_fx := ""
static var f_traits := false
const FX_LIST := ["", "?", "lava", "heart", "fluor", "levitate", "chameleon", "lightning", "starry", "opal", "kintsugi", "dragonfire", "jellyfish"]
const KINDS := ["", "crystal", "druse", "geode"]

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
	# finds into the collection, to look at them on the phone
	v.add_child(_head("Finds → collection"))
	var sp := _row()
	var sids: Array = [""] + Data.SP.keys()
	sp.add_child(_btn("Species: %s" % (Data.SP[f_sid].n if f_sid != "" else "any"), f_sid != "", func():
		f_sid = sids[(sids.find(f_sid) + 1) % sids.size()]
		_reopen()))
	sp.add_child(_btn("Kind: %s" % (f_kind if f_kind != "" else "any"), f_kind != "", func():
		f_kind = KINDS[(KINDS.find(f_kind) + 1) % KINDS.size()]
		_reopen()))
	sp.add_child(_btn("Legend: %s" % ("no" if f_fx == "" else "any" if f_fx == "?" else SpecLegend.FX_N.get(f_fx, f_fx)), f_fx != "", func():
		f_fx = FX_LIST[(FX_LIST.find(f_fx) + 1) % FX_LIST.size()]
		_reopen()))
	sp.add_child(_btn("Rare traits: %s" % ("yes" if f_traits else "as they fall"), f_traits, func():
		f_traits = not f_traits
		_reopen()))
	v.add_child(sp)
	var mk := _row()
	mk.add_child(_btn("+1 like this", false, func(): _finds(1)))
	mk.add_child(_btn("+5 like this", false, func(): _finds(5)))
	mk.add_child(_btn("+8 ammonites, every kind", false, func(): _ammonites()))
	mk.add_child(_btn("Remove test finds", false, func():
		Save.d.coll = Save.d.coll.filter(func(c: Dictionary) -> bool: return not c.get("test", false))
		_saved()))
	v.add_child(mk)
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

## n finds as the panel says, into the collection (marked as test finds, so they can be cleared at once)
static func _finds(n: int) -> void:
	var names := []
	for k in n:
		var st := _find(1 + randi() % 999999, f_sid, f_fx)
		Save.d.coll.append(st)
		names.append(String(Data.SP[st.sid].n) + (" · " + String(SpecLegend.FX_N.get(st.get("fx", ""), "legendary")) if st.legend else ""))
	Save.persist()
	Ov.toast("Added: " + ", ".join(names))
	_reopen()

static func _find(sd: int, sid: String, fx: String) -> Dictionary:
	var a := Save.area()
	var st := Stones.roll(sd, a, 1.5, 3)
	if sid != "":
		st.sid = sid
		if sid in Data.NUGGETY: st.kind = "nugget"
		elif Data.HABIT.get(sid, "") == "fossil": st.kind = "fossil"
		elif st.kind in ["nugget", "fossil"]: st.kind = "crystal"
	if f_kind != "" and not (st.kind in ["nugget", "fossil"]):
		st.kind = f_kind
	if f_traits:
		var pool: Array = Data.TRAITS.map(func(t: Dictionary) -> String: return t.id)
		pool.shuffle()
		st.traits = pool.slice(0, 1 + randi() % 3)
	if fx != "":
		st.legend = true
		if fx != "?": st.fx = fx
	st.tier = Stones.tier_of(st.sid, int(st.gi), bool(st.legend))
	st.area = a
	st.dl = randi() % Data.depths(a).size()
	st.test = true
	if not st.sid in Save.d.seen: Save.d.seen.append(st.sid)
	return st

## eight ammonites, one of each look: sawn, a matched pair, crystal-lined chambers, a brood, crushed in shale, a
## heteromorph, dragon fire, jellyfish — seeds found that grow each
static func _ammonites() -> void:
	var want := [
		func(g: Dictionary) -> bool: return g.show == "split" and not g.pair and float(g.hollow) == 0.0,
		func(g: Dictionary) -> bool: return g.pair,
		func(g: Dictionary) -> bool: return float(g.hollow) > 0.0,
		func(g: Dictionary) -> bool: return int(g.brood) > 0,
		func(g: Dictionary) -> bool: return g.crushed,
		func(g: Dictionary) -> bool: return String(g.hetero) != "",
		func(g: Dictionary) -> bool: return g.show == "split",
		func(g: Dictionary) -> bool: return g.show != "split" and String(g.hetero) == ""]
	var fxs := ["", "", "", "", "", "", "dragonfire", "jellyfish"]
	var sd := 1 + randi() % 900000
	for k in want.size():
		while not (want[k] as Callable).call(SpecFossil.genes(sd, "ammonite", [])): sd += 1
		Save.d.coll.append(_find(sd, "ammonite", fxs[k]))
		sd += 1
	Save.persist()
	Ov.toast("Added 8 ammonites")
	_reopen()

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
