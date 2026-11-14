class_name Admin
extends RefCounted
## The tester's panel (Settings → Admin, or hold the gear → Diagnostics → Admin): jump into any depth of any mine, the boss fight
## or its hoard; hand out ore, coins, lives and gear; put any kind of find into the collection; open the whole mine at
## once or start over. Not for players.

## the find to make: species ("" any), kind ("" as it falls), legendary effect ("" none, "?" any), rare traits
static var f_sid := ""
static var f_kind := ""
static var f_fx := ""
## (the traits: [] as they fall, ["?"] one to three at random, or the very ones to give)
static var f_traits: Array = []
## a tie between minerals (a paragenesis): "" as it falls, "assoc" another species grown beside it, "perch" a metal
## grown on its crystal, "pseudo" the species in another's crystals
static var f_tie := ""
const TIES := [["", "as it falls"], ["assoc", "with a partner"], ["perch", "metal on the crystal"], ["pseudo", "pseudomorph"]]
const KINDS := ["", "crystal", "druse", "geode", "skull"]
## the minerals that have no mine yet (docs/showy-minerals.md)
const SHOWY := ["wulfenite", "vanadinite", "crocoite", "cavansite", "dioptase", "erythrite", "smithsonite", "bismuth", "tourmaline"]
## the species list adds a find at every tap (instead of choosing the species), and how many it has added this visit
static var add_now := false
static var _added := {}
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
	# what to make: each opens a list of everything there is to choose from (no stepping through them one by one)
	var sp := _row()
	sp.add_child(_btn("Species: %s  ▸" % (Data.SP[f_sid].n if f_sid != "" else "any"), f_sid != "", func():
		_leave()
		_added = {}
		pick_species()))
	sp.add_child(_btn("Legend: %s  ▸" % ("no" if f_fx == "" else "any" if f_fx == "?" else String(SpecLegend.FX_N.get(f_fx, f_fx))), f_fx != "", func():
		_leave()
		pick_legend()))
	sp.add_child(_btn("Rare traits: %s  ▸" % _traits_word(), f_traits.size() > 0, func():
		_leave()
		pick_traits()))
	v.add_child(sp)
	var kd := _row()
	kd.add_child(_word("Kind"))
	for kn: String in KINDS:
		var kk := kn
		kd.add_child(_btn(kk if kk != "" else "any", f_kind == kk, func():
			f_kind = kk
			_reopen()))
	v.add_child(kd)
	var td := _row()
	td.add_child(_word("Ties"))
	for te: Array in TIES:
		var tk := String(te[0])
		td.add_child(_btn(String(te[1]), f_tie == tk, func():
			f_tie = tk
			_reopen()))
	v.add_child(td)
	var mk := _row()
	mk.add_child(_btn("+1 like this", false, func(): _finds(1)))
	mk.add_child(_btn("+5 like this", false, func(): _finds(5)))
	v.add_child(mk)
	# whole sets at once
	mk = _row()
	mk.add_child(_btn("+1 of each in %s" % Data.AREAS[a].n, false, func(): _each((Data.AREAS[a].get("pool", {}) as Dictionary).keys(), String(Data.AREAS[a].n))))
	mk.add_child(_btn("+1 of each showy mineral", false, func(): _each(SHOWY, "the showy minerals")))
	mk.add_child(_btn("+1 of each classic pair", false, func(): _pairs()))
	mk.add_child(_btn("+1 of each pseudomorph", false, func(): _pseudos()))
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
		var st := _find(1 + randi() % 999999, f_sid, f_fx) if f_tie == "" else _tie_find(f_sid, f_fx, f_tie)
		if st.is_empty(): continue
		_add(st)
		names.append(String(Data.SP[st.sid].n) + _tie_word(st) + (" · " + String(SpecLegend.FX_N.get(st.get("fx", ""), "legendary")) if st.legend else ""))
	Save.persist()
	Ov.toast("Added: " + ", ".join(names) if names.size() else "No such find: this species does not take that tie (try another species, kind or traits)")
	_reopen()

## A find with a tie between minerals. The tie is the seed's own (SpecLooks.assoc_of, pseudo_of — the genome takes
## no pin for it from a stone), so seeds are tried until one brings it. sid "": any species that can have it, of this
## mine first; mate: the very species wanted beside it or replaced ("" any). {} when no seed brings it
static func _tie_find(sid: String, fx: String, tie: String, mate := "") -> Dictionary:
	var hosts: Array = [sid] if sid != "" else tie_hosts(tie)
	if hosts.is_empty(): return {}
	var sd := 1 + randi() % 900000
	for k in 8000:
		sd += 1
		var s: String = hosts[randi() % hosts.size()]
		# (the seed's own streams first: cheap, and most seeds bring no tie)
		if tie == "pseudo":
			var was := SpecLooks.pseudo_of(sd, s, "crystal")
			if was == "" or (mate != "" and was != mate): continue
		elif SpecLooks.assoc_of(sd, s) == "": continue
		var st := _find(sd, s, fx)
		var g := SpecGenome.of(Spec.of_stone(st))
		var got := String(g.get("pseudo" if tie == "pseudo" else "assoc", ""))
		if got == "" or (mate != "" and got != mate): continue
		if tie == "perch" and not SpecLooks.perches(sd, got, String(g.form), String(g.lustre)): continue
		return st
	return {}

## the species that can have a tie: those of this mine, or of any when it has none
static func tie_hosts(tie: String) -> Array:
	var ok := func(s: String) -> bool:
		if tie == "pseudo": return SpecLooks.PSEUDO.has(s)
		if s in SpecLooks.ASSOC_LONE or String(Data.HABIT.get(s, "prism")) in ["fossil", "obsidian"]: return false
		var ms := SpecLooks.mates(s)
		return ms.any(func(m: String) -> bool: return m in SpecLooks.PERCH) if tie == "perch" else ms.size() > 0
	var out: Array = (Data.AREAS[Save.area()].get("pool", {}) as Dictionary).keys().filter(ok)
	if out.is_empty(): out = Data.minable().filter(ok) + SHOWY.filter(ok)
	return out

## " with pyrite" / ", azurite-shaped" for the toast
static func _tie_word(st: Dictionary) -> String:
	var g := SpecGenome.of(Spec.of_stone(st))
	if String(g.get("pseudo", "")) != "": return ", " + String(Data.SP[g.pseudo].n).to_lower() + "-shaped"
	if String(g.get("assoc", "")) != "": return " with " + String(Data.SP[g.assoc].n).to_lower()
	return ""

## one find of every classic pair (SpecLooks.PAIRS: gold on quartz, malachite beside azurite, galena with sphalerite…)
static func _pairs() -> void:
	var n := 0
	var none := []
	for host: String in SpecLooks.PAIRS:
		for mate: String in (SpecLooks.PAIRS[host] as Dictionary):
			if not mate in SpecLooks.mates(host): continue
			var st := _tie_find(host, "", "assoc", mate)
			if st.is_empty():
				none.append("%s + %s" % [host, mate])
				continue
			_add(st)
			n += 1
	Save.persist()
	Ov.toast("Added %d pairs" % n + ("; none found for " + ", ".join(none) if none.size() else ""))
	_reopen()

## one find of every pseudomorph (SpecLooks.PSEUDO: malachite after azurite, gold after pyrite…)
static func _pseudos() -> void:
	var n := 0
	for sid: String in SpecLooks.PSEUDO:
		for e: Array in (SpecLooks.PSEUDO[sid].after as Array):
			var st := _tie_find(sid, "", "pseudo", String(e[0]))
			if st.is_empty(): continue
			_add(st)
			n += 1
	Save.persist()
	Ov.toast("Added %d pseudomorphs" % n)
	_reopen()

static func _find(sd: int, sid: String, fx: String) -> Dictionary:
	var a := Save.area()
	var st := Stones.roll(sd, a, 1.5, 3)
	if sid != "":
		st.sid = sid
		# (its kind as the species itself grows — the roll's was another species')
		if sid in Data.NUGGETY: st.kind = "nugget"
		elif Data.HABIT.get(sid, "") == "fossil": st.kind = "fossil"
		else: st.kind = String(Stones.pick_w(SpecLooks.kinds(sid), Rng32.new(sd)))
	if f_kind == "skull":
		# a skull of Koschei's barrow: its genes come from the seed (SpecSkull.genes)
		if sid == "" or st.kind in ["nugget", "fossil"]: st.sid = SKULL_SP[randi() % SKULL_SP.size()]
		st.kind = "druse"
		st.form = "skull"
	elif f_kind != "" and not (st.kind in ["nugget", "fossil"]):
		st.kind = f_kind
	if f_traits == ["?"]:
		var pool: Array = Data.TRAITS.map(func(t: Dictionary) -> String: return t.id)
		pool.shuffle()
		st.traits = pool.slice(0, 1 + randi() % 3)
	elif f_traits.size():
		st.traits = f_traits.duplicate()
	if fx != "":
		st.legend = true
		if fx != "?": st.fx = fx
	st.tier = Stones.tier_of(st.sid, int(st.gi), bool(st.legend))
	st.area = a
	st.dl = randi() % Data.depths(a).size()
	st.test = true
	# made a skull or legendary after its roll: named and priced for what it now is
	if st.get("form", "") == "skull":
		st.skin = Stones.skin_of(st)
		st.tier = maxi(int(st.tier), int(Stones.SKULL_TIER.get(st.skin, 1)))
	st.value = Stones.price(st, a, int(st.dl))
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
		st.value = Stones.price(st, 0, 3)
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
		st.value = Stones.price(st, 0, 3)
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

# ---------------------------------------------------------------- the lists to choose from

## the panel is left for a list: it comes back where it stood
static func _leave() -> void:
	_keep = _sc.scroll_vertical if is_instance_valid(_sc) else 0

static func _word(t: String) -> Label:
	var l := UI.label(t, 13, UI.body_bold, Color("#cbbfa6"))
	l.custom_minimum_size = Vector2(0, 36)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

static func _traits_word() -> String:
	if f_traits.is_empty(): return "as they fall"
	if f_traits == ["?"]: return "1–3 at random"
	var names: Array = []
	for t: Dictionary in Data.TRAITS:
		if f_traits.has(String(t.id)): names.append(String(t.n))
	return ", ".join(names) if names.size() <= 2 else "%d chosen" % names.size()

## a list's card: the title with a ✕ back to the panel, a line of what a tap does, and a scroller (kept where it stood
## while the same list is rebuilt)
static var _psc: ScrollContainer
static func _picker(title_t: String, note: String) -> VBoxContainer:
	var at := _psc.scroll_vertical if is_instance_valid(_psc) and _psc.is_inside_tree() else 0
	var card := Ov.card(360)
	var head := HBoxContainer.new()
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(36, 0)
	head.add_child(pad)
	var title := UI.title(title_t, 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := Kit.icon_button("close", 36)
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	x.pressed.connect(open)
	head.add_child(x)
	card.add_child(head)
	if note != "": card.add_child(Ov.text(note, 12))
	var sc := UI.scroller()
	sc.custom_minimum_size = Vector2(0, maxf(300.0, card.get_viewport_rect().size.y - 330.0))
	card.add_child(sc)
	_psc = sc
	if at > 0: _scroll_back(sc, at)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	sc.add_child(v)
	card.add_child(Ov.btn("Back to Admin", "glass", open))
	return v

## every species there is, by the mine it is found in: [[title, [species ids]], ...]; those with no mine last
static func species_groups() -> Array:
	var out: Array = []
	var used := {}
	for a in Data.AREAS.size():
		var ids: Array = ((Data.AREAS[a].get("pool", {}) as Dictionary).keys() as Array).filter(func(id: String) -> bool: return Data.SP.has(id))
		for id: String in ids: used[id] = true
		out.append(["%d · %s" % [a + 1, Data.AREAS[a].n], ids])
	var rest: Array = (Data.SP.keys() as Array).filter(func(id: String) -> bool: return not used.has(id))
	if rest.size(): out.append(["No mine yet", rest])
	return out

## the species, all of them at once. Two ways to use it: choose one (for "+1 like this"), or add a find at every tap
static func pick_species() -> void:
	var v := _picker("Species", "A tap adds a find of that species, made as the panel says (kind, legend, traits)." if add_now
		else "A tap chooses the species for “+1 like this”.")
	var top := _row()
	top.add_child(_btn("Choose", not add_now, func():
		add_now = false
		pick_species()))
	top.add_child(_btn("Add at every tap", add_now, func():
		add_now = true
		pick_species()))
	if not add_now:
		top.add_child(_btn("Any species", f_sid == "", func():
			f_sid = ""
			open()))
	v.add_child(top)
	for grp: Array in species_groups():
		var ids: Array = grp[1]
		var gname := String(grp[0])
		var hr := HBoxContainer.new()
		var hl := _head(gname)
		hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hr.add_child(hl)
		if add_now:
			hr.add_child(_btn("+1 of each", false, func():
				for id: String in ids: _one(id)
				Save.persist()
				Ov.toast("Added %d: %s" % [ids.size(), gname])
				pick_species()))
		v.add_child(hr)
		var row := _row()
		for id: String in ids:
			var sid := id
			var nm := String(Data.SP[sid].n)
			if add_now and _added.has(sid): nm += " ×%d" % int(_added[sid])
			row.add_child(_btn(nm, (add_now and _added.has(sid)) or (not add_now and f_sid == sid), func():
				if add_now:
					_one(sid)
					Save.persist()
					Ov.toast("Added: " + String(Data.SP[sid].n))
					pick_species()
				else:
					f_sid = sid
					open()))
		v.add_child(row)

## one find of a species into the collection, as the panel says
static func _one(sid: String) -> void:
	_add(_find(1 + randi() % 999999, sid, f_fx))
	_added[sid] = int(_added.get(sid, 0)) + 1

## one of each of these species (a mine's eight, the showy nine)
static func _each(ids: Array, what: String) -> void:
	var n := 0
	for id: String in ids:
		if not Data.SP.has(id): continue
		_add(_find(1 + randi() % 999999, id, f_fx))
		n += 1
	Save.persist()
	Ov.toast("Added %d: one of each in %s" % [n, what])
	_reopen()

## the living effects, by what carries them (an effect the body cannot carry is swapped for one it can)
const FX_GROUPS := [
	["Any stone", ["lava", "heart", "fluor", "levitate", "chameleon", "lightning", "starry", "opal", "kintsugi", "jellyfish", "borealis", "frost"]],
	["Fossils and their kin", ["dragonfire", "discharge", "awaken", "hunter", "glow", "moon", "spring"]],
	["Skulls", ["yaga", "candle", "watching", "deathless", "flutter", "fireflies"]],
	["Skulls of beasts", ["blossom", "starhorn", "thunder", "foxfire", "wolfmoon", "breath", "phoenix", "raveneye", "lavaborn", "amberdrop", "ghost"]]]

static func pick_legend() -> void:
	var v := _picker("Legendary effect", "The effect the next finds are made with. One the body cannot carry is swapped for one it can.")
	var top := _row()
	top.add_child(_btn("Not legendary", f_fx == "", func():
		f_fx = ""
		open()))
	top.add_child(_btn("Any effect", f_fx == "?", func():
		f_fx = "?"
		open()))
	v.add_child(top)
	var listed := {}
	var groups: Array = FX_GROUPS.duplicate()
	for grp: Array in groups:
		for id: String in grp[1]: listed[id] = true
	var rest: Array = (SpecLegend.FX_N.keys() as Array).filter(func(id: String) -> bool: return not listed.has(id))
	if rest.size(): groups.append(["Other", rest])
	for grp: Array in groups:
		v.add_child(_head(String(grp[0])))
		var row := _row()
		for id: String in grp[1]:
			if not SpecLegend.FX_N.has(id): continue
			var fx := id
			row.add_child(_btn(String(SpecLegend.FX_N[fx]).capitalize(), f_fx == fx, func():
				f_fx = fx
				open()))
		v.add_child(row)

## the rare traits: as they fall, a few at random, or the very ones ticked here
static func pick_traits() -> void:
	var v := _picker("Rare traits", "Tick the traits the next finds are given; a species shows only those its body can.")
	var top := _row()
	top.add_child(_btn("As they fall", f_traits.is_empty(), func():
		f_traits = []
		open()))
	top.add_child(_btn("1–3 at random", f_traits == ["?"], func():
		f_traits = ["?"]
		open()))
	v.add_child(top)
	v.add_child(_head("These ones"))
	var row := _row()
	for t: Dictionary in Data.TRAITS:
		var id := String(t.id)
		row.add_child(_btn(String(t.n).capitalize(), f_traits.has(id), func():
			if f_traits == ["?"]: f_traits = []
			if f_traits.has(id): f_traits.erase(id)
			else: f_traits.append(id)
			pick_traits()))
	v.add_child(row)
