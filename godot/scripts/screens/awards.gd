class_name Awards
extends Control
## The achievements screen (docs/achievements.md §5–8), opened from the cups in the cabinet. PROTOTYPE: the list is the
## draft table of the doc; progress is real where the save already knows it (skulls and species in the atlas, bosses),
## made up (`got`) elsewhere. Pieces: art/ui_redesign/awards (gen_parts.sh → cut_parts.py → assets/awards/).
## A strip: the guide's parchment, the ink emblem, a rule, the name and under it the reward, and on the right a row
## of slate niches - the things collected (muted, like the stones in a mine's niches) or '?'. More than three: the edge
## of the fourth peeks out and the row slides sideways. Tap a strip: its sheet with every item and the teaser.

signal go(screen: String)

const DIR := "res://assets/awards/"
const FELL := "res://assets/fonts/IMFellEnglish.ttf"
const INK := Color("#2b2218")
const INK_SOFT := Color("#6a5238")
const SIDE := 10.0          # the screen's margin
const STRIP_H := 72.0
const ICON := 44.0
const CARD := 40.0
const GAP := 5.0
const PEEK := 12.0          # how much of the fourth card shows
const TABS := [["tales", "Tales", "t_tales"], ["coll", "Finds", "t_coll"], ["mines", "Mines", "t_mines"],
	["boss", "Bosses", "t_boss"], ["mastery", "Mastery", "t_mastery"], ["secrets", "Secrets", "t_secrets"]]

## the draft list. items: sp:<atlas id> (a find), i:<icon> (a drawing), kit:<kit icon>, res:<picture>; got: made-up
## progress for items the save does not know; one: no collection, the card is the reward; opens: opens a series
static var LIST := [
	{tab = "tales", icon = "three_skulls", n = "Three Kingdoms", t = "Copper, silver, gold. Every kingdom keeps its king's head.", r = "Copper Kingdom", opens = true,
		items = ["sp:skull_copper", "sp:skull_silver", "sp:skull_gold"]},
	{tab = "tales", icon = "fire_maiden", n = "Where She Danced", t = "Wherever she lands, the rock turns to gold.", r = "The Fire Maiden", opens = true,
		tags = ["gold:nugget", "gold:vein", "gold:dendrite"], names = ["Nugget", "Gold in quartz", "Gold tree"]},
	{tab = "tales", icon = "egg_needle", n = "Koschei's Secret", t = "The needle's in the egg, the egg's in the duck, the duck's in the hare…", r = "Koschei's Needle",
		items = ["i:casket", "i:egg_needle", "sp:needle", "i:moon", "i:crowned_skull"], evs = ["", "", "sp:needle", "", ""]},
	{tab = "tales", icon = "pyrite", n = "Fool's Gold", t = "Not everything that glitters. But some of it does.", r = "a workshop recipe",
		items = ["sp:pyrite", "sp:gold"]},
	{tab = "tales", icon = "casket", n = "The Mistress's Casket", t = "She gives only to those who don't grab.", r = "malachite board frame",
		items = ["sp:malachite", "sp:emerald"]},
	{tab = "tales", icon = "nested", n = "Matryoshka", t = "A stone inside a stone inside a stone.", r = "a geode", items = ["sp:fluorite"]},
	{tab = "tales", icon = "halves", n = "Reunited", t = "Split a hundred million years ago. Together again.", r = "a geode", items = ["i:halves"], one = true, ev = ""},
	{tab = "tales", icon = "footsteps", n = "Brother's Footsteps", t = "He was here before you. Every time.", r = "the brother's trail",
		items = ["i:scroll", "i:scroll", "i:scroll", "i:scroll"], evs = ["tut:s_notebook", "tut:s_poloz_after", "tut:s_proval_arrive", "tut:s_proval_gate"]},
	{tab = "tales", icon = "atlas_book", n = "The Scholar's Atlas", t = "She can't write as fast as you dig.", r = "Fifty species in the atlas", one = true, ev = "atlas50", give = {coins = 2500, geode = 1}, items = ["i:book"]},
	{tab = "tales", icon = "oyster_moon", n = "Moonlit Sea", t = "It waited four hundred million years for the moon.", r = "pearl gems", items = ["i:oyster_moon"], one = true, ev = "gene:fx:moon"},

	{tab = "coll", icon = "butterfly", n = "Pinned by Nature", t = "They landed on the stone and never left.", r = "butterfly board frame",
		tags = ["fly:morpho", "fly:apollo", "fly:monarch", "fly:deathshead", "fly:glasswing", "fly:comet", "fly:mourning", "fly:blue"],
		names = ["Morpho", "Apollo", "Monarch", "Death's-head", "Glasswing", "Comet moth", "Mourning cloak", "Common blue"]},
	{tab = "coll", icon = "mushrooms", n = "Fairy Ring", t = "Something grows down here. Several somethings.", r = "the mushroom world", opens = true,
		tags = ["shroom:0", "shroom:1", "shroom:2", "shroom:3", "shroom:4"], names = ["Fly agaric", "Chanterelle", "Porcini", "Glowing mycena", "Honey fungus"]},
	{tab = "coll", icon = "moss_stone", n = "A Rolling Stone", t = "Gathers no moss. Yours did.", r = "coins and a geode",
		tags = ["tr:moss", "acc:lichen", "acc:fronds", "acc:flowers"], names = ["Moss", "Lichen", "Fern fronds", "Tiny flowers"]},
	{tab = "coll", icon = "star_crystal", n = "Once in a Blue Moon", t = "Some stones are alive. Find every one of them.", r = "the Hall of Legends", opens = true, legends = true},
	{tab = "coll", icon = "trilobite", n = "Crystal Eyes", t = "They saw the world through stone lenses. Some of them are still staring.", r = "trilobite portrait",
		tags = ["genus:elrathia", "genus:phacops", "genus:asaphus", "genus:dicranurus", "genus:walliserops", "genus:isotelus"], names = ["Elrathia", "Phacops", "Asaphus", "Dicranurus", "Walliserops", "Isotelus"]},
	{tab = "coll", icon = "amber_fly", n = "Stuck in Time", t = "Came for the resin. Stayed forty million years.", r = "amber gems",
		tags = ["insect:ant", "insect:beetle", "insect:fly", "insect:mosquito", "insect:spider"], names = ["Ant", "Beetle", "Fly", "Mosquito", "Spider"]},
	{tab = "coll", icon = "obsidian", n = "Fifty Shades of Black", t = "Black is never just black.", r = "coins",
		tags = ["ob:black", "ob:snowflake", "ob:mahogany", "ob:rainbow", "ob:tears"], names = ["Jet black", "Snowflake", "Mahogany", "Rainbow", "Apache tears"]},
	{tab = "coll", icon = "flame", n = "Dragon's Palette", t = "Every shell burns with its own fire. One colour is only a rumour.", r = "a geode",
		tags = ["fire:red", "fire:green", "fire:blue", "fire:violet"], names = ["Red fire", "Green fire", "Blue fire", "Violet fire"]},
	{tab = "coll", icon = "flower_drop", n = "Frozen Bouquet", t = "Picked before the ice age. Still in bloom.", r = "quartz board frame",
		tags = ["bloom:star", "bloom:rose", "bloom:daisy", "bloom:bell", "bloom:blossom", "bloom:poppy"], names = ["Star", "Rose", "Daisy", "Bell", "Blossom", "Poppy"]},
	{tab = "coll", icon = "fern", n = "The Stone Herbarium", t = "Pressed by the weight of a mountain.", r = "coins",
		tags = ["plant:fern", "plant:ginkgo", "plant:redwood", "plant:horsetail", "plant:palm", "plant:annularia", "plant:lepido"], names = ["Tree fern", "Ginkgo", "Dawn redwood", "Horsetail", "Palm", "Annularia", "Lepidodendron"]},
	{tab = "coll", icon = "crowned_skull", n = "Alas, Poor Yorick", t = "I knew him well. In every skin he ever wore.", r = "the title Curator",
		items = ["sp:skull_bone", "sp:skull_nacre", "sp:skull_gilt", "sp:skull_kintsugi", "sp:skull_glass", "sp:skull_agate", "sp:skull_opal", "sp:skull_pyrite", "sp:skull_geode", "sp:skull_copper", "sp:skull_silver", "sp:skull_gold"]},
	{tab = "coll", icon = "pearls", n = "String of Pearls", t = "Every sea grows its own colour. Thread them on one string.", r = "a necklace recipe",
		tags = ["pearl:akoya", "pearl:south_sea", "pearl:golden", "pearl:tahitian"], names = ["Akoya", "South Sea", "Golden", "Tahitian"]},
	{tab = "coll", icon = "twin_peaks", n = "Twin Peaks", t = "Two stones, one recipe. The mountain repeats itself.", r = "Two finds of a kind with the same genes", one = true, ev = "twin_genes", give = {geode = 1}, items = ["i:twins"]},
	{tab = "coll", icon = "odd_one", n = "The Odd One", t = "A museum would sell its roof for this.", r = "A find with eight genes at once", one = true, ev = "five_genes", give = {coins = 1000}, items = ["kit:coin"]},
	{tab = "coll", icon = "own_rock", n = "Glass Half Full", t = "It grew from its own kind.", r = "A crystal on a rock of its own mineral", one = true, ev = "same_rock", give = {coins = 500}, items = ["i:crystal"]},
	{tab = "coll", icon = "moth", n = "Moth to a Flame", t = "They know better. They come anyway.", r = "Butterflies on a skull that burns", one = true, ev = "moth_flame", give = {geode = 1}, items = ["i:butterfly"]},
	{tab = "coll", icon = "overgrown", n = "Nature Takes Over", t = "Moss, mushrooms and flowers. Is there a stone under there?", r = "Moss, a mushroom and flowers on one find", one = true, ev = "overgrown", give = {coins = 600}, items = ["i:moss_stone"]},
	{tab = "coll", icon = "fluorite", n = "Rainbow in a Cube", t = "It can't decide what colour to be. Neither will you.", r = "coins",
		tags = ["pal:fluorite:0", "pal:fluorite:1", "pal:fluorite:2", "pal:fluorite:3", "pal:fluorite:4", "pal:fluorite:5"], names = ["Green", "Purple", "Blue", "Yellow", "Colourless", "Pink"]},

	{tab = "mines", icon = "adit", n = "Every Stone of the Hill", t = "The old man knows them all. Do you?", r = "an artifact stand", items = ["mine:0"]},
	{tab = "mines", icon = "serpent", n = "The Serpent Sleeps", t = "Gold doesn't come for free here.", r = "a trophy", one = true, boss = 0, items = ["i:serpent"]},
	{tab = "mines", icon = "glow_stone", n = "Legend of the Adit", t = "One stone here is not like the others.", r = "a rare geode", one = true, legend = 0, items = ["i:glow_stone"]},
	{tab = "mines", icon = "headframe", n = "Fully Rigged", t = "Every wheel turns, every lamp burns.", r = "coins", coins = 1500, one = true, ev = "rigged:0", items = ["kit:coin"]},
	{tab = "mines", icon = "scroll", n = "Notes from Below", t = "The guide wrote things down. Not everything was for you.", r = "the guide's story",
		items = ["i:scroll", "i:scroll", "i:scroll", "i:scroll", "i:scroll"], evs = ["tut:g_hello_0", "tut:g_ore", "tut:g_build", "tut:g_drill", "tut:g_deeper"]},
	{tab = "mines", icon = "eye", n = "Eye of the Miner", t = "The mine moves when you're not looking.", r = "a portrait frame",
		items = ["i:serpent", "i:serpent", "i:eye", "i:lizard"], evs = ["ev:0:hole", "ev:0:coil", "ev:0:eyes", "ev:0:lizard"]},

	{tab = "mines", icon = "glimpse", n = "Glimpses of the Deep", t = "The mines hide their masters. Sometimes they slip.", r = "a portrait frame",
		items = ["i:lizard", "i:tentacle", "i:lightning", "i:moon", "i:twins"], evs = ["ev:1:reflection", "ev:2:eel", "ev:3:shadow", "ev:4:dwarf", "ev:4:brother"]},
	{tab = "mines", icon = "night_watch", n = "Night Watch", t = "Sit still long enough and the mine forgets you're there.", r = "Watch a mine for three minutes", one = true, ev = "night_watch", give = {lives = 2}, items = ["kit:heart"]},

	{tab = "boss", icon = "serpent", n = "Snake Charmer", t = "He bit. You didn't flinch.", r = "Win against the Serpent first try", one = true, ev = "boss:0:first", give = {geode = 2}, items = ["kit:gold"]},
	{tab = "boss", icon = "lizard", n = "Keep Your Greens", t = "Not one stone for the lizards.", r = "No green stolen by the lizards", one = true, ev = "boss:1:greens", give = {geode = 2}, items = ["kit:copper"]},
	{tab = "boss", icon = "tentacle", n = "Hold Fast", t = "Nothing goes overboard.", r = "The tentacle drags no stone", one = true, ev = "boss:2:hold", give = {geode = 2}, items = ["kit:ammonite"]},
	{tab = "boss", icon = "lightning", n = "Thunderstruck", t = "Even a giant needs to sit down.", r = "Stun Brontes 3 times", one = true, ev = "boss:3:daze", need = 3, give = {geode = 2}, items = ["kit:sulphur"]},
	{tab = "boss", icon = "canary", n = "Sing, Little Bird", t = "She never stopped singing.", r = "The canary never falls silent", one = true, ev = "boss:7:song", give = {geode = 2}, items = ["kit:flint"]},
	{tab = "boss", icon = "snake_eyes", n = "Snake Eyes", t = "Look him in the eye. Then blow it up.", r = "Finish the Serpent with a special stone", one = true, ev = "boss:0:special", give = {boost = {pick = 2}}, items = ["i:serpent"]},
	{tab = "boss", icon = "kind_lizard", n = "The Kindly Mistress", t = "She likes a gift. Just the one.", r = "Let the lizards take exactly one green", one = true, ev = "boss:1:one", give = {geode = 1}, items = ["i:lizard"]},
	{tab = "boss", icon = "kraken_eye", n = "Eye to Eye", t = "Three times before it blinks.", r = "Hit the Kraken's eye three times in a row", one = true, ev = "boss:2:eye3", give = {geode = 1}, items = ["i:eye"]},
	{tab = "boss", icon = "lightning_rod", n = "Lightning Rod", t = "The bolt was aimed. It never came.", r = "Stun Brontes while his bolt is aimed", one = true, ev = "boss:3:rod", give = {geode = 1}, items = ["i:lightning"]},
	{tab = "boss", icon = "serpent", n = "The Serpent Returns", t = "Each time he wakes, he wakes angrier.", r = "Beat him three times, harder each time", give = {geode = 2}, items = ["i:serpent", "i:serpent", "i:serpent"], evs = ["tier:0:1", "tier:0:2", "tier:0:3"]},
	{tab = "boss", icon = "lizard", n = "Stone Heart", t = "She never forgives. She only waits.", r = "Beat her three times, harder each time", give = {geode = 2}, items = ["i:lizard", "i:lizard", "i:lizard"], evs = ["tier:1:1", "tier:1:2", "tier:1:3"]},
	{tab = "boss", icon = "tentacle", n = "Back to the Deep", t = "It sank. It always comes back up.", r = "Beat it three times, harder each time", give = {geode = 2}, items = ["i:tentacle", "i:tentacle", "i:tentacle"], evs = ["tier:2:1", "tier:2:2", "tier:2:3"]},
	{tab = "boss", icon = "lightning", n = "Forged Thrice", t = "Steel is struck three times.", r = "Beat him three times, harder each time", give = {geode = 2}, items = ["i:lightning", "i:lightning", "i:lightning"], evs = ["tier:3:1", "tier:3:2", "tier:3:3"]},
	{tab = "boss", icon = "lord_below", n = "Lord Below", t = "Every master of the deep, at its worst. Bowed.", r = "Every boss beaten at its hardest", give = {coins = 10000, geode = 2, unlock = "golden gems"}, lords = true, items = []},
	{tab = "boss", icon = "axe_crown", n = "Giant Slayer", t = "Every legend underground has met you.", r = "the title Slayer",
		items = ["i:serpent", "i:lizard", "i:tentacle", "i:lightning", "i:canary"], evs = ["won:0", "won:1", "won:2", "won:3", "won:7"]},

	{tab = "mastery", icon = "hourglass", n = "By a Hair", t = "Last move. Last chance. Done.", r = "Win on the last move", one = true, ev = "last_move", give = {boost = {pick = 3}}, items = ["res:res://assets/board/boosters/pick.png"]},
	{tab = "mastery", icon = "rockfall", n = "Avalanche", t = "One stone moved. Then all of them.", r = "A cascade of 8", one = true, ev = "cascade8", give = {boost = {bore_h = 2, bore_v = 2}}, items = ["res:res://assets/board/boosters/bore_h.png"]},
	{tab = "mastery", icon = "keg", n = "Powder Party", t = "Boom. Boom boom boom boom.", r = "Five kegs in one chain", one = true, ev = "kegs5", give = {coins = 800}, items = ["kit:coin"]},
	{tab = "mastery", icon = "domino", n = "Domino", t = "You lit one. They did the rest.", r = "Three kegs in one move", one = true, ev = "domino", give = {boost = {bore_h = 1, bore_v = 1}}, items = ["kit:coin"]},
	{tab = "mastery", icon = "lights_out", n = "Lights Out", t = "Darkness, gone in a single breath.", r = "Light six dark cells in one move", one = true, ev = "lights_out", give = {coins = 600}, items = ["kit:coin"]},
	{tab = "mastery", icon = "conveyor", n = "Conveyor Chef", t = "Sit back. The belt is cooking.", r = "Three matches made by a belt in one turn", one = true, ev = "belt3", give = {coins = 600}, items = ["kit:coin"]},
	{tab = "mastery", icon = "overkill", n = "Overkill", t = "It was already beaten. You made sure.", r = "Win with two special stones together", one = true, ev = "overkill", give = {boost = {pan = 2}}, items = ["res:res://assets/board/boosters/pan.png"]},
	{tab = "mastery", icon = "lazy", n = "Lazy Miner", t = "The bottom of the board? Never heard of it.", r = "Win without a move in the lower half", one = true, ev = "lazy", give = {lives = 2}, items = ["kit:heart"]},
	{tab = "mastery", icon = "flask", n = "Mad Alchemist", t = "What happens if you mix these two?", r = "new gems look",
		items = ["i:flask", "i:flask", "i:flask", "i:flask", "i:flask", "i:flask", "i:flask", "i:flask", "i:flask", "i:flask"],
		evs = ["mix:rocket+rocket", "mix:bomb+rocket", "mix:orb+rocket", "mix:drill+rocket", "mix:bomb+bomb", "mix:bomb+orb", "mix:bomb+drill", "mix:orb+orb", "mix:drill+orb", "mix:drill+drill"]},
	{tab = "mastery", icon = "hands", n = "Bare Hands", t = "Who needs tools?", r = "A hard level without boosters", one = true, ev = "bare_hands", give = {lives = 3}, items = ["kit:heart"]},
	{tab = "mastery", icon = "bonfire", n = "On Fire", t = "Ten in a row. The mine is listening.", r = "Ten wins in a row", one = true, ev = "streak10", give = {boost = {pan = 3}}, items = ["res:res://assets/board/boosters/pan.png"]},
	{tab = "mastery", icon = "crystal", n = "Not a Scratch", t = "Out of the rock in one piece.", r = "A find without a single chip", one = true, ev = "clean_find", give = {geode = 1}, items = ["i:crystal"]},
	{tab = "mastery", icon = "scales", n = "Jackpot", t = "Someone will pay a fortune for that.", r = "A stone worth 10 000", one = true, ev = "jackpot", give = {coins = 2000}, items = ["kit:coin"]},

	{tab = "secrets", icon = "broken_heart", n = "What Have You Done", t = "Someone will buy it. Someone always does.", r = "Sold a legendary stone", one = true, hide = true, ev = "sold_legend", give = {coins = 500}, items = ["kit:coin"]},
	{tab = "secrets", icon = "cracked", n = "Butterfingers", t = "It was a nice stone. It was.", r = "A find dug out in pieces", one = true, hide = true, ev = "broken_find", give = {coins = 300}, items = ["i:cracked"]},
	{tab = "secrets", icon = "cage", n = "Don't Poke the Bird", t = "She's working. Let her work.", r = "Ten taps on the canary's cage", one = true, hide = true, ev = "poke_bird", give = {coins = 300}, items = ["i:canary"]},
	{tab = "secrets", icon = "moon", n = "Night Shift", t = "Miners don't sleep. Apparently, neither do you.", r = "Played between midnight and four", one = true, hide = true, ev = "night", give = {lives = 2}, items = ["i:moon"]},
	{tab = "secrets", icon = "unlucky", n = "Unlucky Charm", t = "Legendary. Shattered. Legendarily shattered.", r = "A legendary find dug out Damaged", one = true, hide = true, ev = "unlucky", give = {geode = 1}, items = ["i:cracked"]},
	{tab = "secrets", icon = "old_gold", n = "Old Man's Gold", t = "He gave it to you. You sold it. He knows.", r = "Sold the old man's gift", one = true, hide = true, ev = "sold_gift", give = {coins = 100}, items = ["i:pyrite"]},
	{tab = "secrets", icon = "pet_rock", n = "Pet Rock", t = "You two have something special.", r = "Kept one single stone for thirty days", one = true, hide = true, ev = "pet_rock", give = {geode = 2}, items = ["i:crystal"]},
	{tab = "secrets", icon = "hoarder", n = "Hoarder", t = "Every drawer, every chest, every pocket.", r = "A hundred stones kept at once", one = true, hide = true, ev = "hoarder", give = {coins = 3000}, items = ["kit:coin"]},
	{tab = "secrets", icon = "second", n = "Second Thoughts", t = "Sold it. Missed it. Dug it up again.", r = "Find a species a minute after selling one", one = true, hide = true, ev = "second", give = {coins = 300}, items = ["kit:coin"]},
	{tab = "secrets", icon = "hourglass", n = "Patience", t = "It was worth the look.", r = "Look at a find for two minutes", one = true, hide = true, ev = "patience", give = {coins = 300}, items = ["kit:coin"]},
	{tab = "secrets", icon = "twins", n = "Déjà Vu", t = "Haven't we met?", r = "The same species twice in a row", one = true, hide = true, ev = "twins", give = {coins = 300}, items = ["i:twins"]},
]

## the scholar's word on the big ones, once she is met (StoryScene: [mood, line]); claimed, she says it
const SAY := {
	"Three Kingdoms": ["shock", "Copper, silver, gold - a crown for each. Someone ruled down there. Three someones."],
	"Where She Danced": ["curious", "Gold where every step landed. Grandmothers told of a girl of fire. I wrote it off as a fairy tale."],
	"Koschei's Secret": ["worry", "The needle. If the tale is right, his death is in your pocket. Don't drop it."],
	"Fool's Gold": ["smile", "Now you can tell them apart. Most miners never learn."],
	"The Mistress's Casket": ["calm", "Malachite and emerald from the same mountain. She keeps what she likes best for herself."],
	"Matryoshka": ["curious", "A stone grown around a stone grown around a stone. Patience is a mineral too."],
	"Pinned by Nature": ["smile", "Every wing on the bones. I'd pin them in a case, but they're already in one."],
	"Fairy Ring": ["worry", "They grow in a ring where no light reaches. Something feeds them. I'd rather not know what."],
	"A Rolling Stone": ["smile", "Moss, lichen, fronds, flowers. A garden that never saw the sun."],
	"Once in a Blue Moon": ["shock", "Every living stone. They shouldn't exist - and here they are, on my table."],
	"Crystal Eyes": ["curious", "Calcite lenses. They looked at the sea through stone before anything had eyes like ours."],
	"Stuck in Time": ["calm", "Every one of them came for a drop of resin. Bad luck lasts forty million years."],
	"Fifty Shades of Black": ["smile", "Volcanic glass in every mood. My brother called it all just 'black'."],
	"Dragon's Palette": ["shock", "Violet ammolite. I'd have bet my atlas it was a rumour."],
	"Frozen Bouquet": ["sad", "Flowers nobody will ever smell. Still, they're the prettiest thing in my atlas."],
	"The Stone Herbarium": ["calm", "A forest older than the dinosaurs, pressed flat between two pages of slate."],
	"Alas, Poor Yorick": ["worry", "Twelve kinds of skull. I'm not sure the barrow wanted them dug up."],
	"String of Pearls": ["smile", "Each sea paints its own. Now you have them all on one thread."],
	"Rainbow in a Cube": ["curious", "One mineral, every colour. Fluorite never makes up its mind."],
	"Every Stone of the Hill": ["resolve", "Every kind the hill gives up. The old man's list is finished - mine isn't."],
	"Giant Slayer": ["resolve", "All of them. And still no sign of him. Keep digging."],
}

static var tab := "tales"

var scroll: ScrollContainer
var list: VBoxContainer
var sticky: Control
var tabs_at := 0.0

## the genes a find carries, as the achievements count them: "fx:lava", "shroom:2", "fly:morpho", "genus:phacops",
## "ob:snowflake", "fire:blue", "insect:ant", "bloom:rose", "plant:ginkgo", "pearl:golden", "pal:fluorite:3",
## "tr:moss", "acc:lichen"... Read from the genome alone (no meshes): cheap enough for every find
static func genes_of(s: Dictionary) -> Array:
	var o := Spec.of_stone(s)
	var g := SpecGenome.of(o)
	var out: Array = []
	var seed_v := maxi(1, int(o.get("seed", 1)))
	var sid := String(o.get("sid", ""))
	if String(g.fx) != "": out.append("fx:" + String(g.fx))
	if int(g.shroom) >= 0: out.append("shroom:%d" % int(g.shroom))
	for t in s.get("traits", []): out.append("tr:" + String(t))
	for a in g.accents: out.append("acc:" + String(a))
	var f: Dictionary = g.fossil
	match sid:
		"trilobite":
			out.append("genus:" + String(f.genus))
			for p in f.get("pearls", []): out.append("pearl:" + String(p.body))
		"obsidian": out.append("ob:" + String(f.kind))
		"ammonite":
			if float(f.get("nacre", 0.0)) > 0.0: out.append("fire:" + String(f.fire))
		"amber", "simetite", "flower_quartz":
			if String(f.get("content", "")) == "insect": out.append("insect:" + String(f.insect))
			if String(f.get("content", "")) == "flower": out.append("bloom:" + String(f.bloom))
		"fern": out.append("plant:" + String(f.plant))
		"petrified_wood":
			if f.get("fungi", false): out.append("shroom:4")    # honey fungus grows only on the wood
	if sid == "gold": out.append("gold:" + String(g.form))     # the Fire Maiden's gold: nugget, vein, tree
	if String(g.form) == "skull":
		var sk := SpecSkull.genes(seed_v, g.skull)
		for k in sk.fly_kinds: out.append("fly:" + String(k))
	var look := SpecLooks.of(sid)
	if look.has("palette"):
		var pal: Array = look.palette
		var ws: Array = []
		for i in pal.size(): ws.append([i, float(pal[i][2])])
		out.append("pal:%s:%d" % [sid, int(Stones.pick_w(ws, Rng32.new((seed_v * 1597334677 + 31) % 4294967296)))])
	return out

## the achievements a find brings by itself (Save.note_find): eight genes, a crystal on its own rock, butterflies on a
## burning skull, a find overgrown — read from its genes and genome, no meshes
const OWN_ROCK := {selenite = "gypsum", calcite = "limestone", quartz = "quartzite", amethyst = "quartzite", smoky = "quartzite"}
static func find_marks(s: Dictionary, gs: Array) -> Array:
	var out: Array = []
	if gs.filter(func(t: String) -> bool: return not t.begins_with("pal:")).size() >= 8: out.append("five_genes")
	var sid := String(s.get("sid", ""))
	if OWN_ROCK.has(sid) and String(SpecGenome.of(Spec.of_stone(s)).rock) == String(OWN_ROCK[sid]): out.append("same_rock")
	if gs.has("fx:yaga") and gs.any(func(t: String) -> bool: return t.begins_with("fly:")): out.append("moth_flame")
	var moss := gs.has("tr:moss") or gs.has("acc:moss") or gs.has("acc:lichen")
	if moss and gs.any(func(t: String) -> bool: return t.begins_with("shroom:")) and gs.has("acc:flowers"): out.append("overgrown")
	return out

## what is kept of a find to show it again (the same fields as the atlas's best): enough to build it and to tell
## whether it is still in the inventory (id)
static func summary(s: Dictionary, a: int, dl: int) -> Dictionary:
	var b := {id = s.id, sid = s.sid, kind = s.get("kind", "crystal"), gi = s.gi, traits = s.get("traits", []), legend = s.get("legend", false),
		g = s.g, value = s.value, tier = s.tier, area = a, dl = dl}
	for k in ["fx", "shroom", "form", "skin", "moss", "tree_kind", "stream", "wine", "flies", "fly_kind"]:
		if s.has(k): b[k] = s[k]
	return b

## for each gene, the finest stone that shows it among those kept now (tag -> the stone); built once a render
static var _kept: Dictionary = {}

static func kept_best() -> Dictionary:
	if _kept.is_empty():
		_kept = {none = true}
		for s in Save.d.coll:
			for t in genes_of(s):
				if not _kept.has(t) or int(s.value) > int(_kept[t].value): _kept[t] = s
	return _kept

## the stone a found item is shown by: [summary, kept now]. A gene: the finest kept stone that shows it, else the
## last one with it that was sold (grey, as the atlas greys a species whose best stone was sold); a species: the atlas's best
func _shown(item: String) -> Array:
	if item.begins_with("g:"):
		var tag := item.trim_prefix("g:")
		var k: Dictionary = kept_best()
		if k.has(tag):
			var s: Dictionary = k[tag]
			return [summary(s, int(s.get("area", 0)), int(s.get("dl", 0))), true]
		return [(Save.d.get("gfirst", {}) as Dictionary).get(tag, {}), false]
	if item.begins_with("sp:"):
		var id := item.trim_prefix("sp:")
		return [(Save.d.atlas.get(id, {}) as Dictionary).get("best", {}), Atlas.best_kept(id)]
	return [{}, true]

## the genes of every find kept before the achievements came: read once (gver 3: the first finds as summaries,
## so a tap can open their card)
static func backfill() -> void:
	if int(Save.d.get("gver", 0)) >= 5: return
	var seen: Array = Save.d.get("genes", [])
	var first: Dictionary = Save.d.get("gfirst", {})
	for s in Save.d.coll:
		for t in genes_of(s):
			if not seen.has(t): seen.append(t)
			if not first.has(t) or not (first[t] as Dictionary).has("value"):
				first[t] = summary(s, int(s.get("area", 0)), int(s.get("dl", 0)))
	Save.d.genes = seen
	Save.d.gfirst = first
	Save.d.gver = 5
	Save.persist()

func _ready() -> void:
	size = get_viewport_rect().size
	for a in OS.get_cmdline_user_args():
		if a.begins_with("atab="): tab = a.substr(5)    # for a look: `-- screen=awards atab=coll`
	backfill()
	var bg := Bg.new()
	bg.size = size
	bg.name = "Bg"
	add_child(bg)
	render()

func render() -> void:
	_kept = {}
	var keep := scroll.scroll_vertical if scroll else 0
	for ch in get_children():
		if ch.name != "Bg": ch.queue_free()
	var root := VBoxContainer.new()
	root.size = size
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	var pad := MarginContainer.new()
	for side in ["left", "right"]: pad.add_theme_constant_override("margin_" + side, 12)
	pad.add_theme_constant_override("margin_top", 10 + int(UI.safe_top()))
	pad.add_theme_constant_override("margin_bottom", 6)
	pad.z_index = 1
	pad.add_child(Chrome.top_bar())
	root.add_child(pad)
	var area := Control.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.clip_contents = true
	root.add_child(area)
	root.add_child(Chrome.nav_bar("museum", func(id: String): go.emit(id)))
	scroll = UI.scroller()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	area.add_child(scroll)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]: m.add_theme_constant_override("margin_" + side, int(SIDE))
	m.add_theme_constant_override("margin_bottom", 18)
	scroll.add_child(m)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	m.add_child(list)
	var w := size.x - SIDE * 2
	list.add_child(_head())
	# no "almost there" block (it fought the title and the tabs, 8.11): inside a tab the strips go ready first, then
	# the nearest to done, the sealed ones at the end; an opened pass is played from its sheet
	var tb := _tabs(w)
	list.add_child(tb)
	var rows: Array = []
	for e in LIST:
		if String(e.tab) != tab: continue
		var c := _count(e)
		var k: float = {ready = 3.0, open = 1.0 + float(c.x) / maxf(1.0, c.y), hidden = 0.5, done = 0.0}[_state(e)]
		rows.append([k, rows.size(), e])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]) or (float(a[0]) == float(b[0]) and int(a[1]) < int(b[1])))
	for r in rows: list.add_child(_strip(r[2], w))
	# the tabs stick to the top once they would scroll away
	sticky = _tabs(w)
	sticky.position = Vector2(SIDE, 0)
	sticky.visible = false
	area.add_child(sticky)
	scroll.get_v_scroll_bar().value_changed.connect(func(_v: float): sticky.visible = scroll.scroll_vertical > tb.position.y)
	await get_tree().process_frame
	scroll.scroll_vertical = keep

## the title row: back to the cabinet, the plate, the count
func _head() -> Control:
	var h := Control.new()
	h.custom_minimum_size = Vector2(0, 50)
	var back := Kit.button("", "sq_dark", 16, 2.0)
	back.size = Vector2(34, 34)
	back.position = Vector2(0, 6)
	var chev := Control.new()
	chev.set_anchors_preset(Control.PRESET_FULL_RECT)
	chev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chev.draw.connect(func():
		var c := chev.size / 2.0 + Vector2(-1, 0)
		chev.draw_polyline(PackedVector2Array([c + Vector2(4, -8), c + Vector2(-4, 0), c + Vector2(4, 8)]), Kit.CREAM, 3.0, true))
	back.add_child(chev)
	back.pressed.connect(func():
		Sfx.play("tab")
		go.emit("museum"))
	h.add_child(back)
	var pl := Kit.title_plate("Awards")
	var done := 0
	for e in LIST: if _state(e) in ["done", "ready"]: done += 1
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 0)
	c.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	c.offset_left = -100
	c.offset_right = 100
	c.offset_top = 2
	c.alignment = BoxContainer.ALIGNMENT_BEGIN
	c.add_child(pl)
	var n := Kit.label("%d of %d" % [done, LIST.size()], 11, UI.body_bold, Color(Kit.AMBER, 0.8))
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(n)
	h.add_child(c)
	return h

func _label(t: String) -> Control:
	var c := CenterContainer.new()
	c.custom_minimum_size = Vector2(0, 30)
	c.add_child(Kit.title_plate(t))
	return c

# ---------------------------------------------------------------- progress

## how many of the items are in hand. Where the save itself knows (genes, the atlas, bosses beaten) it is read from
## there; the rest are events the game marks as they happen (Awards.mark: the board, the fights, the mine screens)
static func _got(e: Dictionary) -> Array:
	# a collection of genes: seen on any find ever kept (Save.d.genes, filled by Save.note_find)
	if e.has("tags") or e.get("legends", false):
		var tags: Array = e.tags if e.has("tags") else SpecLegend.FX_N.keys().map(func(k: String) -> String: return "fx:" + k)
		var names: Array = e.names if e.has("names") else SpecLegend.FX_N.values().map(func(v: String) -> String: return v.capitalize())
		var seen: Array = Save.d.get("genes", [])
		var out: Array = []
		for i in tags.size():
			out.append(["g:" + String(tags[i]), seen.has(tags[i]), String(e.icon), String(names[i])])
		return out
	var items: Array = e.items
	if e.get("lords", false):
		# every boss that exists, beaten at its worst
		var out: Array = []
		for a in Data.AREAS.size():
			if (Data.AREAS[a].get("boss", {}) as Dictionary).is_empty(): continue
			out.append(["i:" + String(BOSS_ICON.get(String(Data.AREAS[a].boss.get("id", "")), "axe_crown")), tier_of(a) >= TIERS])
		return out
	if items.size() == 1 and String(items[0]).begins_with("mine:"):
		var a := int(String(items[0]).trim_prefix("mine:"))
		items = []
		for id in Data.AREAS[a].pool: items.append("sp:" + String(id))
	var has: Array = []
	for i in items.size():
		var s := String(items[i])
		var ok := false
		if e.get("one", false):
			if e.has("boss"): ok = _won(int(e.boss))
			elif e.has("legend"):
				for id in Data.AREAS[int(e.legend)].pool:
					if Save.d.atlas.has(id) and bool(Save.d.atlas[id].get("legend", false)): ok = true
			else: ok = n(String(e.get("ev", ""))) >= int(e.get("need", 1))
		elif e.has("evs"):
			ok = n(String(e.evs[i])) > 0
		elif s.begins_with("sp:"):
			ok = Save.d.atlas.has(s.trim_prefix("sp:"))
		has.append([s, ok])
	return has

static func _count(e: Dictionary) -> Vector2i:
	var g := _got(e)
	var k := 0
	for x in g: if bool(x[1]): k += 1
	return Vector2i(k, g.size())

## hidden · open · ready (all in hand, not claimed) · done (claimed: sealed)
static func _state(e: Dictionary) -> String:
	var c := _count(e)
	if c.x >= c.y and c.y > 0: return "done" if (Save.d.aw_got as Array).has(String(e.n)) else "ready"
	if e.get("hide", false): return "hidden"
	return "open"

## a boss fought again gets harder: the first win is tier 1, each replay won the next, up to TIERS
const TIERS := 3
const TIER_N := ["", "", "Furious", "Undying"]
const BOSS_ICON := {poloz = "serpent", mistress = "lizard", kraken = "tentacle", brontes = "lightning", shubin = "canary", koschei = "crowned_skull"}

static func tier_of(a: int) -> int:
	var t: Array = Save.d.get("boss_tier", [])
	var k: int = int(t[a]) if a < t.size() else 0
	return maxi(k, 1 if _won(a) else 0)

static func _won(a: int) -> bool:
	return a < Save.d.boss_won.size() and bool(Save.d.boss_won[a])

# ---------------------------------------------------------------- events, notices, rewards

## how far an event has come: a count the game keeps (Save.d.aw_ev), or read straight from the save —
## "tut:<id>" a guide's line told, "sp:<id>" a species in the atlas, "gene:<tag>" a gene seen, "won:<mine>" a boss beaten
static func n(ev: String) -> int:
	if ev == "": return 0
	if ev.begins_with("tut:"): return 1 if Save.told(ev.substr(4)) else 0
	if ev.begins_with("sp:"): return 1 if Save.d.atlas.has(ev.substr(3)) else 0
	if ev.begins_with("gene:"): return 1 if (Save.d.genes as Array).has(ev.substr(5)) else 0
	if ev.begins_with("won:"): return 1 if _won(int(ev.substr(4))) else 0
	if ev.begins_with("tier:"): return 1 if tier_of(int(ev.get_slice(":", 1))) >= int(ev.get_slice(":", 2)) else 0
	return int((Save.d.aw_ev as Dictionary).get(ev, 0))

## the game tells that something happened (by: how many times); kept at once, noticed on the next check
static func mark(ev: String, by := 1) -> void:
	Save.d.aw_ev[ev] = int((Save.d.aw_ev as Dictionary).get(ev, 0)) + by
	Save.persist()

## once only: set, never counted up again
static func once(ev: String) -> void:
	if n(ev) == 0: mark(ev)

## what the save shows by itself, latched as events (a streak ends, an achievement doesn't)
static func _latch() -> void:
	if int(Save.d.streak) >= 10: once("streak10")
	for id in Save.d.atlas:
		if int(Save.d.atlas[id].get("max_v", 0)) >= 10000: once("jackpot")
	var h := Time.get_datetime_dict_from_system().hour as int
	if h < 4: once("night")
	if Save.d.atlas.size() >= 50: once("atlas50")
	var coll: Array = Save.d.coll
	if coll.size() >= 100: once("hoarder")
	# one single stone kept for thirty days (the day it became the only one, by its id)
	var day := int(Time.get_unix_time_from_system() / 86400.0)
	if coll.size() == 1:
		var id := int(coll[0].id)
		if n("pet_id") != id:
			Save.d.aw_ev.pet_id = id
			Save.d.aw_ev.pet_day = day
		elif day - n("pet_day") >= 30: once("pet_rock")
	elif n("pet_id") != 0: Save.d.aw_ev.pet_id = 0
	# every job of Old Adit built to its last step
	var jobs: Array = Data.AREAS[0].get("tasks", [])
	if jobs.size() and jobs.all(func(t: Array) -> bool: return (Save.d.built[0] as Array).has(t[0])): once("rigged:0")

## the achievements just completed: noticed once each (a toast now; the strip waits on the screen to be claimed).
## quiet: noticed without a word (the save's first look, so the old ones don't all speak at once)
static func check(quiet := false) -> Array:
	backfill()
	_latch()
	var fresh: Array = []
	for e in LIST:
		var c := _count(e)
		if c.y == 0 or c.x < c.y or (Save.d.aw_seen as Array).has(String(e.n)): continue
		Save.d.aw_seen.append(String(e.n))
		fresh.append(e)
	if fresh.size():
		Save.persist()
		if not quiet:
			Sfx.play("reveal_2")
			var e: Dictionary = fresh[0]
			var head := "Secret award" if e.get("hide", false) else "Award"
			Ov.toast("%s: %s" % [head, e.n] if fresh.size() == 1 else "%d new awards — see the cabinet" % fresh.size())
	return fresh

## how many wait to be claimed (the cups in the cabinet light up)
static func waiting() -> int:
	_latch()
	var k := 0
	for e in LIST:
		if _state(e) == "ready": k += 1
	return k

## what an achievement gives: {coins, geode (0 plain, 1 good, 2 rare), boost {id: n}, lives, unlock (a name: a series,
## a frame, a title — kept for when it exists)}. Spelt out in `give`, else read from the reward's words
static func give_of(e: Dictionary) -> Dictionary:
	if e.has("give"): return e.give
	var r := String(e.r)
	var out := {}
	if r.begins_with("coins"): out.coins = int(e.get("coins", 100 * maxi(3, _count(e).y)))
	if r.ends_with("geode"): out.geode = 2 if r.contains("rare") else 1
	if out.is_empty(): out.unlock = r
	return out

## the reward handed over: kept in the save at once (so a crash halfway never pays twice), then the geode opened
static func claim(e: Dictionary) -> void:
	if _state(e) != "ready": return
	var gv := give_of(e)
	Save.d.aw_got.append(String(e.n))
	Save.d.coins += int(gv.get("coins", 0))
	Save.d.lives += int(gv.get("lives", 0))
	var bo: Dictionary = gv.get("boost", {})
	for id in bo: Save.d.boost[id] = int(Save.d.boost.get(id, 0)) + int(bo[id])
	if gv.has("unlock") and not (Save.d.unlocks as Array).has(String(gv.unlock)): Save.d.unlocks.append(String(gv.unlock))
	var st := {}
	if gv.has("geode"):
		# a geode of the mine you're in, from its deepest open depth: the better the reward, the luckier
		var dl := int(Save.d.depth[Save.area()])
		st = Stones.roll(Save.next_uid(), Save.area(), [0.6, 1.2, 2.2][clampi(int(gv.geode), 0, 2)], dl)
	Save.persist()
	if gv.has("coins"): Sfx.play("coin")
	if not st.is_empty(): await GeodeOpen.run([st], {title = String(e.n), short = true})
	elif gv.has("unlock"): Ov.toast("%s · %s — on its way in an update" % [e.n, gv.unlock])
	else: Ov.toast("%s · claimed" % e.n)

## the strips nearest to done (and an opened pass on top)
func _near() -> Array:
	var out: Array = []
	for e in LIST:
		if e.get("opens", false) and _state(e) == "done": out.append(e)
	var best: Array = []
	for e in LIST:
		if e.get("one", false) or _state(e) in ["done", "hidden"]: continue
		var c := _count(e)
		if c.y < 2: continue
		best.append([float(c.x) / c.y + (1.0 if _state(e) == "ready" else 0.0), e])
	best.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	for i in mini(2, best.size()): out.append(best[i][1])
	return out

# ---------------------------------------------------------------- pieces

func _tex(name: String) -> Texture2D:
	return Kit.tex_at(DIR + name + ".png")

func _pic(name: String, sz: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = _tex(name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size = Vector2(sz, sz)
	t.custom_minimum_size = Vector2(sz, sz)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return t

func _parchment(hidden: bool) -> Control:
	if hidden:
		var np := NinePatchRect.new()
		np.texture = _tex("strip_hidden")
		for s in [SIDE_LEFT, SIDE_RIGHT]: np.set_patch_margin(s, 40)
		for s in [SIDE_TOP, SIDE_BOTTOM]: np.set_patch_margin(s, 28)
		np.modulate = Color(0.62, 0.55, 0.48)    # a crumpled sheet in the dark: not yet yours
		np.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return np
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", Kit.box("bubble", 0.0))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## a slate niche with the thing in it (muted) or '?'
func _niche(it: Array, sz: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(sz, sz)
	c.size = Vector2(sz, sz)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := _pic("niche", sz)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	c.add_child(bg)
	var s := String(it[0])
	if not bool(it[1]):
		var q := UI.label("?", int(sz * 0.46), UI.display, Color(Kit.AMBER, 0.42))
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.size = Vector2(sz, sz)
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(q)
		return c
	var img := TextureRect.new()
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var k := 0.16 if s.begins_with("i:") else 0.12
	img.position = Vector2(sz * k, sz * k)
	img.size = Vector2(sz * (1.0 - 2.0 * k), sz * (1.0 - 2.0 * k))
	img.modulate = Color(0.82, 0.8, 0.76)
	c.add_child(img)
	if s.begins_with("g:") or s.begins_with("sp:"):
		# the finest stone kept now; grey once none is (as the atlas)
		img.material = _fade(not bool(_shown(s)[1]))
		img.modulate = Color.WHITE    # (the shader mutes it)
	if s.begins_with("g:"):
		var o: Dictionary = _shown(s)[0]
		if o.is_empty(): img.texture = _tex(String(it[2]))
		else: Atlas.cutout(Spec.of_stone(o) if o.has("value") else o, func(t: Texture2D): if is_instance_valid(img): img.texture = t, img)
	elif s.begins_with("i:"):
		img.texture = _tex(s.trim_prefix("i:"))
		pass   # the drawings are coloured: shown as they are, muted like the finds
	elif s.begins_with("kit:"):
		img.texture = Kit.tex("icons/" + s.trim_prefix("kit:"))
	elif s.begins_with("res:"):
		img.texture = Kit.tex_at(s.trim_prefix("res:"))
	elif s.begins_with("sp:"):
		var id := s.trim_prefix("sp:")
		var e: Dictionary = Save.d.atlas.get(id, {})
		Atlas.cutout(Spec.of_stone(e.best) if e.has("best") else Atlas._sample(id), func(t: Texture2D): if is_instance_valid(img): img.texture = t, img)
	return c

static var _fade_m: Array = [null, null]

## a find's picture fading into its niche (shaders/niche_fade.gdshader); grey: no longer kept
static func _fade(grey := false) -> ShaderMaterial:
	var i := 1 if grey else 0
	if _fade_m[i] == null:
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/niche_fade.gdshader")
		m.set_shader_parameter("grey", float(i))
		_fade_m[i] = m
	return _fade_m[i]

## one achievement
func _strip(e: Dictionary, w: float) -> Control:
	var st := _state(e)
	var hidden := st == "hidden"
	var s := Control.new()
	s.custom_minimum_size = Vector2(w, STRIP_H)
	s.size = Vector2(w, STRIP_H)
	if st == "ready":
		var glow := Control.new()
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.size = s.size
		glow.draw.connect(func():
			for i in 4:
				var g := 1.0 + i * 1.5
				var r := Rect2(Vector2(-g, -g), s.size + Vector2(g, g) * 2.0)
				glow.draw_style_box(_round(Color(1.0, 0.72, 0.3, 0.42 - i * 0.09), 12.0 + g), r))
		s.add_child(glow)
		var tw := glow.create_tween().set_loops()
		tw.tween_property(glow, "modulate:a", 0.45, 1.1).set_trans(Tween.TRANS_SINE)
		tw.tween_property(glow, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)
	var p := _parchment(hidden)
	p.size = s.size
	s.add_child(p)
	var ic := _pic("question" if hidden else String(e.icon), ICON)
	ic.position = Vector2(9, (STRIP_H - ICON) / 2.0)
	if hidden: ic.modulate = Color(1, 1, 1, 0.45)
	s.add_child(ic)
	var rule := ColorRect.new()
	rule.color = Color(INK, 0.28)
	rule.size = Vector2(1.5, STRIP_H - 26)
	rule.position = Vector2(ICON + 16, 13)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(rule)
	# the cards: three slots right-aligned on one column for every strip; a fourth peeks out at the edge
	var g := _got(e)
	var x3 := w - 8.0 - PEEK - GAP - (3.0 * CARD + 2.0 * GAP)    # where the first of three cards starts
	var tx := ICON + 22.0
	var t := VBoxContainer.new()
	t.add_theme_constant_override("separation", 0)
	t.alignment = BoxContainer.ALIGNMENT_CENTER
	t.position = Vector2(tx, 6)
	t.size = Vector2(x3 - tx - 6, STRIP_H - 12)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(t)
	var nl := UI.label("???" if hidden else String(e.n), 14, UI.display, INK)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.custom_minimum_size = Vector2(t.size.x, 0)
	nl.add_theme_constant_override("line_spacing", -4)
	t.add_child(nl)
	if not hidden:
		var c := _count(e)
		# no "3/8": the niches show how far it is, the names stay secret until found
		if e.has("give"):
			var cl := UI.label(String(e.r), 12, load(FELL) as Font, INK_SOFT)
			cl.clip_text = true
			cl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			cl.custom_minimum_size = Vector2(t.size.x, 0)
			t.add_child(cl)
		else: t.add_child(_reward(e, 12, t.size.x))
	if st == "ready":
		# ready to claim: a warm rim right on the parchment's edge, breathing
		var rim := Control.new()
		rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rim.size = s.size
		rim.draw.connect(func():
			var sb := StyleBoxFlat.new()
			sb.draw_center = false
			sb.border_color = Color(1.0, 0.8, 0.4, 0.9)
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(11)
			sb.anti_aliasing = true
			rim.draw_style_box(sb, Rect2(Vector2(2, 2), s.size - Vector2(4, 4))))
		s.add_child(rim)
		var tw2 := rim.create_tween().set_loops()
		tw2.tween_property(rim, "modulate:a", 0.35, 1.1).set_trans(Tween.TRANS_SINE)
		tw2.tween_property(rim, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)
	if not hidden:
		var order: Array = g.filter(func(x: Array) -> bool: return bool(x[1])) + g.filter(func(x: Array) -> bool: return not bool(x[1]))
		var row := _row(order, w - 8.0 - x3)
		row.position = Vector2(x3, (STRIP_H - CARD) / 2.0)
		s.add_child(row)
		if st == "done":
			row.modulate = Color(0.85, 0.82, 0.78)
			# a small seal stamped on the strip's bottom right corner, over its edge
			var seal := _pic("seal", 34)
			seal.position = Vector2(w - 26.0, STRIP_H - 30.0)
			seal.pivot_offset = Vector2(17, 17)
			seal.rotation = 0.18
			s.add_child(seal)
	s.gui_input.connect(func(ev: InputEvent): if Atlas._tapped(ev):
		Sfx.play("open")
		if st == "ready": _claim(e, s)
		else: _sheet(e))
	return s

## the cards of a strip, right-aligned to the third slot; with more than three the row slides sideways
func _row(items: Array, w: float) -> Control:
	var clip := Control.new()
	clip.clip_contents = true
	clip.size = Vector2(w, CARD)
	clip.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(GAP))
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(h)
	for it in items: h.add_child(_niche(it, CARD))
	var n := items.size()
	if n < 3: h.position.x = (3 - n) * (CARD + GAP)
	if n > 3:
		var span := n * CARD + (n - 1) * GAP - (w - PEEK - GAP) - PEEK
		var drag := {on = false, dir = 0}
		clip.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton or ev is InputEventScreenTouch:
				drag.on = ev.pressed
				drag.dir = 0
			elif (ev is InputEventMouseMotion and drag.on) or ev is InputEventScreenDrag:
				var rel: Vector2 = ev.relative
				if int(drag.dir) == 0 and rel.length() > 2.0: drag.dir = 1 if absf(rel.x) > absf(rel.y) else 2
				if int(drag.dir) == 1:
					h.position.x = clampf(h.position.x + rel.x, -span - PEEK, 0.0)
					clip.accept_event())
	return clip

## an opened pass: a wide card with Play
func _pass_card(e: Dictionary) -> Control:
	var w := size.x - SIDE * 2
	var s := Control.new()
	s.custom_minimum_size = Vector2(w, STRIP_H + 6)
	var p := _parchment(false)
	p.size = Vector2(w, STRIP_H + 6)
	s.add_child(p)
	var ic := _pic(String(e.icon), ICON + 8)
	ic.position = Vector2(8, (STRIP_H + 6 - ICON - 8) / 2.0)
	s.add_child(ic)
	var l := UI.label("Opened:\n" + String(e.r), 16, UI.display, INK)
	l.add_theme_constant_override("line_spacing", -4)
	l.position = Vector2(ICON + 26, 14)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(l)
	var b := Kit.button("Play", "btn_green", 18)
	b.size = Vector2(108, 46)
	b.position = Vector2(w - 118, (STRIP_H + 6 - 46) / 2.0)
	b.pressed.connect(func(): Ov.toast("%s: coming soon" % e.r))
	s.add_child(b)
	return s

func _tabs(w: float) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.custom_minimum_size = Vector2(w, 72)
	var tw := (w - 5 * 4.0) / 6.0
	for t in TABS:
		var id: String = t[0]
		var on := id == tab
		var b := Control.new()
		b.custom_minimum_size = Vector2(tw, 72)
		var bg := TextureRect.new()
		bg.texture = _tex("tab_on" if on else "tab")
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.size = Vector2(tw, 72)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(bg)
		var ic := _pic(String(t[2]), 24)
		ic.position = Vector2((tw - 24) / 2.0, 7)
		if on: b.position.y = -3
		b.add_child(ic)
		var done := 0
		var all := 0
		for e in LIST:
			if String(e.tab) != id: continue
			all += 1
			if _state(e) in ["done", "ready"]: done += 1
		var col := Kit.AMBER if on else Kit.CREAM
		if on: bg.modulate = Color(1.08, 1.0, 0.9)
		var nl := UI.label(String(t[1]), 9, UI.display, col)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.position = Vector2(0, 32)
		nl.size = Vector2(tw, 12)
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(nl)
		var cl := UI.label("%d/%d" % [done, all], 10, UI.display, Color(col, 0.8))
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cl.position = Vector2(0, 44)
		cl.size = Vector2(tw, 12)
		cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(cl)
		b.gui_input.connect(func(ev: InputEvent): if Atlas._tapped(ev) and not on:
			Sfx.play("tab")
			tab = id
			render())
		h.add_child(b)
	return h

static func _round(c: Color, r: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(int(r))
	s.anti_aliasing = true
	return s

# ---------------------------------------------------------------- the sheet

## every item of an achievement on a parchment sheet: the teaser, the reward, what is still missing
func _sheet(e: Dictionary) -> void:
	var hidden := _state(e) == "hidden"
	var lay := Control.new()
	lay.set_anchors_preset(Control.PRESET_FULL_RECT)
	lay.size = size
	lay.z_index = 5
	add_child(lay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.size = size
	lay.add_child(dim)
	var w := minf(size.x - 40, 340)
	var p := PanelContainer.new()
	var bx := Kit.box("parchment_tall", 0.0)
	bx.content_margin_left = 22
	bx.content_margin_right = 22
	bx.content_margin_top = 20
	bx.content_margin_bottom = 22
	p.add_theme_stylebox_override("panel", bx)
	p.custom_minimum_size = Vector2(w, 0)
	p.mouse_filter = Control.MOUSE_FILTER_STOP   # a tap on the sheet itself keeps it open
	lay.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	var ic := _pic("question" if hidden else String(e.icon), 76)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var c := _count(e)
	var tl := UI.label("???" if hidden else String(e.n), 22, UI.display, INK)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tl)
	if not hidden and e.has("give"):
		var cn := UI.label(String(e.r), 15, load(FELL) as Font, INK)
		cn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cn.custom_minimum_size = Vector2(w - 44, 0)
		v.add_child(cn)
	if not hidden:
		var rw := _reward(e, 15, w - 44, "Reward: ")
		rw.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(rw)
	var g := _got(e)
	# the teaser; a tap on a '?' puts a hint of where to look in its place
	var tz := UI.label("A secret. You'll know it when it happens." if hidden else String(e.t), 16, load(FELL) as Font, INK)
	tz.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tz.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tz.custom_minimum_size = Vector2(w - 44, 0)
	if not hidden and not e.get("one", false):
		var grid := GridContainer.new()
		grid.columns = 3 if g.size() <= 6 or g.size() == 9 else 4
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var cs := minf(68.0, (w - 44 - (grid.columns - 1) * 8.0) / grid.columns)
		for it in g:
			var ni := _niche(it, cs)
			# found: its card (grey if sold); not yet: a hint where to look, in the teaser's place
			ni.mouse_filter = Control.MOUSE_FILTER_STOP
			ni.gui_input.connect(func(ev: InputEvent): if Atlas._tapped(ev):
				if bool(it[1]):
					if String(it[0]).begins_with("g:") or String(it[0]).begins_with("sp:"): _open_find(it)
				else:
					Sfx.play("tab")
					tz.text = _where(e, String(it[0]))
					tz.modulate = Color(0.55, 0.32, 0.12))
			if (it as Array).size() < 4:
				grid.add_child(ni)
				continue
			# a gene: its name under the niche once found; until then a secret
			var cell := VBoxContainer.new()
			cell.add_theme_constant_override("separation", 1)
			cell.add_child(ni)
			var nm := UI.label(String(it[3]) if bool(it[1]) else "?", 10, UI.body_bold, INK if bool(it[1]) else Color(INK_SOFT, 0.7))
			nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			nm.custom_minimum_size = Vector2(cs, 0)
			nm.clip_text = true
			nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			cell.add_child(nm)
			grid.add_child(cell)
		v.add_child(grid)
	v.add_child(tz)
	if e.get("opens", false) and _state(e) == "done":
		var wait := 0
		if String(e.n) == "Where She Danced":
			wait = maxi(0, int(Save.d.maiden_day) + 7 - int(Time.get_unix_time_from_system() / 86400.0))
		var b := Kit.button(("Play: " + String(e.r)) if wait == 0 else "She dances again in %d day%s" % [wait, "" if wait == 1 else "s"], "btn_green" if wait == 0 else "btn_slate", 17)
		b.custom_minimum_size = Vector2(0, 48)
		b.pressed.connect(func():
			if String(e.n) == "Where She Danced":
				if wait == 0:
					lay.queue_free()
					go.emit("maiden")
			else: Ov.toast("%s: coming soon" % e.r))
		v.add_child(b)
	await get_tree().process_frame
	p.position = (size - p.size) / 2.0
	# closed by the ✕ in its corner or by a tap anywhere outside it
	var close := func() -> void:
		if not lay.is_queued_for_deletion():
			Sfx.play("tab")
			lay.queue_free()
	var x := Kit.icon_button("close", 34)
	x.position = p.position + Vector2(p.size.x - 34 - 10, 10)
	x.pressed.connect(close)
	lay.add_child(x)
	dim.gui_input.connect(func(ev: InputEvent): if Atlas._tapped(ev): close.call())

## what an achievement gives, as it reads: coins and geodes as their picture with a number, the rest (a series,
## a frame, a title…) in words — those names are a lure of their own. A condition (Bosses, Mastery) stays words too
func _reward(e: Dictionary, fs: int, w: float, lead := "") -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.custom_minimum_size = Vector2(0, fs + 4)
	var fell := load(FELL) as Font
	var gv := give_of(e)
	var r := String(gv.get("unlock", ""))
	var parts: Array = []
	var coins := gv.has("coins")
	if coins: parts.append(["res://assets/ui/kit/icons/coin.png", UI.fmt(int(gv.coins))])
	if gv.has("geode"): parts.append(["res://assets/ui/geode/whole.png", ["geode", "fine geode", "rare geode"][clampi(int(gv.geode), 0, 2)]])
	var bo: Dictionary = gv.get("boost", {})
	for id in bo: parts.append(["res://assets/board/boosters/%s.png" % id, "×%d" % int(bo[id])])
	if gv.has("lives"): parts.append(["res://assets/ui/kit/icons/heart.png", "×%d" % int(gv.lives)])
	if parts.size() and r != "":
		# a thing to come and pictures: the thing in words first
		h.add_child(UI.label(lead + r + " +", fs, fell, INK_SOFT))
		lead = ""
	if lead != "" and parts.size(): h.add_child(UI.label(lead, fs, fell, INK_SOFT))
	if parts.is_empty():
		var l := UI.label(lead + r, fs, fell, INK_SOFT)
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.custom_minimum_size = Vector2(w, 0)
		if lead != "": l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(l)
		return h
	for i in parts.size():
		if i: h.add_child(UI.label(" +", fs, fell, INK_SOFT))
		var ic := TextureRect.new()
		ic.texture = Kit.tex_at(String(parts[i][0]))
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(fs + 4, fs + 4)
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ic)
		h.add_child(UI.label(String(parts[i][1]), fs, UI.body_bold if coins and i == 0 else fell, INK_SOFT))
	return h

## the species a gene shows on (for the hint of where to look)
const GENE_SP := {gold = ["gold"], genus = ["trilobite"], pearl = ["trilobite"], ob = ["obsidian"], fire = ["ammonite"],
	insect = ["amber", "simetite"], bloom = ["flower_quartz", "amber"], plant = ["fern"]}

## a hint for a '?': which mine (named only once opened) and among what to look — not the name of the thing itself
func _where(e: Dictionary, item: String) -> String:
	var sids: Array = []
	if item.begins_with("g:"):
		var tag := item.trim_prefix("g:")
		var kind := tag.get_slice(":", 0)
		if kind == "fx": return "Only a legendary find has it. Every mine keeps a few."
		if kind == "fly": return "They land where the dead lie: look on the skulls of a barrow."
		if tag == "shroom:4": return "It feeds on old wood. Look at the petrified kind."
		if kind in ["shroom", "tr", "acc"]: return "It grows on the rock around a find. Damp, deep places suit it."
		if kind == "pal": sids = [tag.get_slice(":", 1)]
		else: sids = GENE_SP.get(kind, [])
		if kind == "pearl": return _in_mines(sids, "Something on the old sea floor guards it, %s.")
	elif item.begins_with("sp:"):
		var id := item.trim_prefix("sp:")
		if id.begins_with("skull_"):
			return _in_mines([], "Dig among the bones %s." , Stones.SKULL_AREAS.keys())
		sids = [id]
	elif e.has("evs"):
		match String(e.icon):
			"flask": return "Swap two special stones into each other. Not every pair has met yet."
			"scroll": return "The guide has more to say. Keep building and digging deeper."
			"eye": return "Stay a while on the screen of Old Adit. The mine moves when it's quiet."
			"axe_crown": return "A giant you haven't beaten yet."
		return String(e.t)
	else:
		return String(e.t)
	var names: Array = []
	for sid in sids: if Data.SP.has(sid) and not names.has(Data.SP[sid].n): names.append(String(Data.SP[sid].n))
	return _in_mines(sids, "Look closely at %s %s." % [" and ".join(names) if names.size() else "the finds", "%s"])

## "…in Whalebone Cove" / "…in a mine you haven't opened yet"
func _in_mines(sids: Array, line: String, areas: Array = []) -> String:
	if areas.is_empty():
		for a in Data.AREAS.size():
			for sid in sids:
				if (Data.AREAS[a].pool as Dictionary).has(sid) and not areas.has(a): areas.append(a)
	var open: Array = []
	for a in areas: if Atlas.is_open(int(a)): open.append(String(Data.AREAS[int(a)].n))
	var where := ("in " + " or ".join(open)) if open.size() else "in a mine you haven't opened yet"
	return line % where

## a found item: its find's card, as in the atlas — in colour while the stone is kept, grey once sold
func _open_find(it: Array) -> void:
	var s := String(it[0])
	var sh := _shown(s)
	var best: Dictionary = sh[0]
	var kept: bool = sh[1]
	if not best.has("value"):
		Ov.toast(String(it[3]) if it.size() > 3 else "Found")
		return
	Sfx.play("open")
	var v := Ov.card(350, Data.rarity_color(int(best.tier)))
	var view := Reveal.stone_card(v, best, 380, func(): Ov.close(), kept)
	if not kept: view.hold_grey()
	var ba := int(best.get("area", 0))
	var t := ("%s · " % it[3]) if it.size() > 3 else ""
	t += "%s, %d m" % [Data.AREAS[ba].n, Data.depth_m(ba, int(best.get("dl", 0)))]
	if not kept: t += "\nSold. Keep another stone with it to bring it back to colour."
	var l := Kit.label(t, 12, UI.body_bold, Kit.CREAM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)

## a ready achievement: the reward is handed over, the seal stamped
func _claim(e: Dictionary, strip: Control = null) -> void:
	if _busy: return
	_busy = true
	if strip: await _stamp(strip)
	await Awards.claim(e)
	if SAY.has(String(e.n)) and Save.told("s_sister_meet"):
		var l: Array = SAY[String(e.n)]
		await StoryScene.say(self, [["sister", String(l[0]), String(l[1])]]).finished
	_busy = false
	render()

var _busy := false

## the wax seal comes down on the strip's corner: big and high, a thud, a jolt of the strip, a ring of light
func _stamp(strip: Control) -> void:
	var seal := _pic("seal", 34)
	seal.pivot_offset = Vector2(17, 17)
	seal.position = Vector2(strip.size.x - 26.0, STRIP_H - 30.0)
	seal.scale = Vector2(3.2, 3.2)
	seal.rotation = -0.5
	seal.modulate.a = 0.0
	seal.z_index = 2
	strip.add_child(seal)
	var tw := seal.create_tween().set_parallel()
	tw.tween_property(seal, "modulate:a", 1.0, 0.12)
	tw.tween_property(seal, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(seal, "rotation", 0.18, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	Sfx.play("build")
	Sfx.buzz(30)
	var ring := Control.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.position = seal.position + Vector2(17, 17)
	strip.add_child(ring)
	var k := [0.0]
	ring.draw.connect(func():
		ring.draw_arc(Vector2.ZERO, 14.0 + 30.0 * k[0], 0, TAU, 32, Color(1.0, 0.8, 0.45, 0.8 * (1.0 - k[0])), 3.0, true))
	var rt := ring.create_tween()
	rt.tween_method(func(x: float):
		k[0] = x
		ring.queue_redraw(), 0.0, 1.0, 0.35)
	var x0 := strip.position.x
	var jt := strip.create_tween()
	jt.tween_property(strip, "position:x", x0 + 3.0, 0.04)
	jt.tween_property(strip, "position:x", x0 - 2.0, 0.05)
	jt.tween_property(strip, "position:x", x0, 0.05)
	await get_tree().create_timer(0.45).timeout

## for screenshots: ui=open_first opens the sheet of the first strip of the tab
func _open_first() -> void:
	# (the one nearest to done, as it heads the tab)
	var best: Dictionary = {}
	var bk := -1.0
	for e in LIST:
		if String(e.tab) != tab or _state(e) != "open": continue
		var c := _count(e)
		if float(c.x) / maxf(1.0, c.y) > bk:
			bk = float(c.x) / maxf(1.0, c.y)
			best = e
	if not best.is_empty(): _sheet(best)

## the cabinet's back wall behind, dim
class Bg extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#120d09"))
		var t := Kit.tex_at("res://assets/cabinet/room.png")
		var k := maxf(size.x / t.get_width(), size.y / t.get_height()) * 1.25
		var s := Vector2(t.get_size()) * k
		draw_texture_rect(t, Rect2((size - s) * Vector2(0.75, 0.3), s), false, Color(0.32, 0.27, 0.22))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.03, 0.02, 0.35))
