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
const KINDS := ["", "crystal", "druse", "geode", "skull"]
## crystals a skull grows when the species is "any" or a nugget/fossil (SpecSkull, docs/skulls.md)
const SKULL_SP := ["amethyst", "venom", "morion", "cinnabar", "celestine", "smoky", "quartz", "fluorite"]

static func main() -> Node:
	return Engine.get_main_loop().current_scene

## the panel's scroller, and where it stood: a button reopens the panel, which then comes back to the same place
static var _sc: ScrollContainer
static var _keep := 0

static func open() -> void:
	var a := Save.area()
	var card := Ov.card(360)
	# the title with a ✕ (an empty slot on the left keeps it centred), the rest scrolls inside the screen
	var head := HBoxContainer.new()
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(36, 0)
	head.add_child(pad)
	var title := UI.title("Admin", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := Kit.icon_button("close", 36)
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	x.pressed.connect(func():
		Ov.close()
		_refresh())
	head.add_child(x)
	card.add_child(head)
	var sc := UI.scroller()
	sc.custom_minimum_size = Vector2(0, maxf(300.0, card.get_viewport_rect().size.y - 300.0))
	card.add_child(sc)
	_sc = sc
	if _keep > 0:
		# (after the content is laid out, or the scroller clamps it to 0)
		_scroll_back(sc, _keep)
		_keep = 0
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 12)
	sc.add_child(v)
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
	mk.add_child(_btn("+6 test skulls (same every time)", false, func(): _skull_set()))
	mk.add_child(_btn("+16 beast skulls, one each", false, func(): _beast_set()))
	# before / after on one install: the old bone shader and no batching of soil and moss (reopen the card to rebuild)
	mk.add_child(_btn("Skull speedups: %s" % ("on" if SpecUtil.fast else "OFF (old)"), not SpecUtil.fast, func():
		SpecUtil.fast = not SpecUtil.fast
		_reopen()))
	# on: the panel's finds count as found in a mine (genes, the atlas, achievements); off: only into the inventory
	var counts: bool = Save.d.get("adm_count", false)
	mk.add_child(_btn("Finds count for awards: %s" % ("yes" if counts else "no"), counts, func():
		Save.d.adm_count = not counts
		_saved()))
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
	# the mine screen with everything that moves on it: all jobs built, every depth open and lived in (crews come after
	# two wins), a stone on every pedestal; and its rare events on demand
	v.add_child(_head("Mine screen"))
	var ms := _row()
	ms.add_child(_btn("All animations on", false, func(): _alive()))
	var evs: Array = ["hole", "coil", "eyes", "bat", "lizard"]
	if a == 1: evs = ["lizard", "reflection", "window", "brine"]
	elif a == 2: evs = ["ink", "bubbles", "tip", "compass", "sulphur", "bolt_far", "bolt_near", "sheet", "bolt_rod", "elmo", "gull"]
	elif a == 5: evs = ["monk", "eyes", "thread", "skitter", "tug"]
	for ev in evs:
		ms.add_child(_btn("Event: " + ev, false, func():
			MineView.force_event = ev
			Ov.close()
			_refresh()))
	v.add_child(ms)
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
		_add(st)
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
	if f_kind == "skull":
		# a skull of Koschei's barrow: its genes come from the seed (SpecSkull.genes)
		if sid == "" or st.kind in ["nugget", "fossil"]: st.sid = SKULL_SP[randi() % SKULL_SP.size()]
		st.kind = "druse"
		st.form = "skull"
	elif f_kind != "" and not (st.kind in ["nugget", "fossil"]):
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

## six skulls that are the same on every install (fixed seeds, as `spec_gallery -- area=0 sp=amethyst form=skull
## base=500 skin=…` builds them), to measure a phone's frame before and after a change: three bone ones heavy with
## growth (trees and moss, a crystal crown, roots), cast gold, the stone mosaic, and glass — the light one
static func _skull_set() -> void:
	for e: Array in [[508, "bone"], [515, "bone"], [543, "bone"], [501, "gold"], [522, "kintsugi"], [529, "glass"]]:
		var st := Stones.roll(int(e[0]), 0, 1.5, 3)
		st.id = int(e[0])
		st.sid = "amethyst"
		st.kind = "druse"
		st.gi = 2
		st.traits = []
		st.legend = false
		st.erase("fx")
		st.form = "skull"
		st.skin = String(e[1])
		st.tier = Stones.tier_of(st.sid, int(st.gi), false)
		st.area = 0
		st.dl = 0
		st.test = true
		_add(st)
	if not "amethyst" in Save.d.seen: Save.d.seen.append("amethyst")
	Save.persist()
	Ov.toast("Added 6 test skulls: bone ×3, gold, mosaic, glass")
	_reopen()

## an animal's skull of every kind (SpecSkull.BEASTS), one each; the skins and crystals vary, so every new look shows
## (bone, lapis, feathers, sugar druse, rhodochrosite, gilt...), the open-mouthed ones with a druse in the maw
static func _beast_set() -> void:
	for st: Dictionary in beast_stones():
		_add(st)
		if not st.sid in Save.d.seen: Save.d.seen.append(st.sid)
	Save.persist()
	Ov.toast("Added 16 beast skulls, one of each")
	_reopen()

## the 16 beast skulls of the admin's button (also spec_gallery adm_beasts): one of each, coats and crystals varied
static func beast_stones() -> Array:
	var out := []
	var skins := ["bone", "lapis", "bone", "feathers", "sugar", "bone", "rhodo", "gilt", "bone", "kintsugi", "nacre", "bone", "gold", "agate", "bone", "opal"]
	var sps := ["amethyst", "venom", "celestine", "morion", "quartz", "fluorite", "cinnabar", "smoky"]
	for k in SpecSkull.BEASTS.size():
		var sd := 96000 + k * 17
		var st := Stones.roll(sd, 0, 1.5, 3)
		st.id = sd
		st.sid = sps[k % sps.size()]
		st.kind = "druse"
		st.gi = 2 + k % 3
		st.traits = []
		st.legend = false
		st.erase("fx")
		st.form = "skull"
		st.beast = SpecSkull.BEASTS[k]
		st.skin = skins[k % skins.size()]
		if st.beast in ["wolf", "alligator", "trex"]: st.maw = true
		st.tier = maxi(Stones.tier_of(st.sid, int(st.gi), false), int(Stones.SKULL_TIER.get(st.skin, 1)))
		st.value = roundi(float(Data.SP[st.sid].v) * Stones.VALUE_K * float(Stones.SKULL_V.get(st.skin, 1.6)) * 1.5)
		st.area = 0
		st.dl = 0
		st.test = true
		out.append(st)
	return out

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
		_add(_find(sd, "ammonite", fxs[k]))
		sd += 1
	Save.persist()
	Ov.toast("Added 8 ammonites")
	_reopen()

## the whole mine alive: every depth open, every job built, three wins on each depth (its people come), and a test
## find on each pedestal that has none (the boss is left unbeaten: the finale's door keeps breathing)
static func _alive() -> void:
	var a := Save.area()
	var n := Data.depths(a).size()
	Save.d.depth[a] = n - 1
	Save.d.built[a] = (Data.AREAS[a].tasks as Array).map(func(t): return t[0])
	for k in n:
		if k < Save.d.dwins.size(): Save.d.dwins[k] = maxi(int(Save.d.dwins[k]), 3)
	var has := {}
	for s in Save.d.coll:
		if int(s.get("area", -1)) == a and s.has("dl"): has[int(s.dl)] = true
	for k in n:
		if not has.has(k):
			var st := _find(1 + randi() % 999999, "", "")
			st.dl = k
			_add(st)
	# straight to the mine: the panel closes so the screen can be watched
	Save.persist()
	Ov.close()
	_refresh()
	Ov.toast("The whole mine is alive")

## a panel's find into the inventory; with "Finds count for awards" on, noted as a find in a mine too (Save.note_find:
## its genes, the atlas, the achievements a find brings)
static func _add(st: Dictionary) -> void:
	Save.d.coll.append(st)
	if Save.d.get("adm_count", false):
		Save.note_find(st, int(st.get("area", Save.area())), int(st.get("dl", 0)))

static func _give(key: String, n: int) -> void:
	Save.d[key] = int(Save.d[key]) + n
	_saved()

static func _saved() -> void:
	Save.persist()
	Ov.toast("Done")
	_reopen()

static func _scroll_back(sc: ScrollContainer, at: int) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for i in 2:
		await tree.process_frame
		if is_instance_valid(sc): sc.scroll_vertical = at

static func _reopen() -> void:
	_keep = _sc.scroll_vertical if is_instance_valid(_sc) else 0
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
