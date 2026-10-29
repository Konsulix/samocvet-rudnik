extends Control
## A wall of specimens for eyeballing the 3D port:  -- set=0 shot=user://g.png after=4
## set 0: crystals and druses, 1: geodes, nuggets, botryoids, 2: cut stones, jewellery, machines

const SETS := [
	[{seed = 11, sid = "quartz", kind = "crystal", gi = 2, traits = []}, {seed = 12, sid = "amethyst", kind = "druse", gi = 3, traits = []},
	{seed = 13, sid = "fluorite", kind = "druse", gi = 2, traits = ["irid"]}, {seed = 14, sid = "garnet", kind = "crystal", gi = 2, traits = []},
	{seed = 15, sid = "emerald", kind = "crystal", gi = 3, traits = ["rutile"]}, {seed = 16, sid = "gypsum", kind = "crystal", gi = 1, traits = []},
	{seed = 17, sid = "ruby", kind = "druse", gi = 2, traits = ["moss"]}, {seed = 18, sid = "aquamarine", kind = "crystal", gi = 4, traits = ["floater"]},
	{seed = 19, sid = "calcite", kind = "druse", gi = 1, traits = ["coral"]}, {seed = 20, sid = "pyrite", kind = "druse", gi = 2, traits = []},
	{seed = 21, sid = "diamond", kind = "crystal", gi = 4, traits = ["aurora"], legend = true}, {seed = 22, sid = "celestine", kind = "druse", gi = 2, traits = ["bubbles", "druzy"]}],
	[{seed = 31, sid = "amethyst", kind = "geode", gi = 3, traits = []}, {seed = 32, sid = "quartz", kind = "geode", gi = 2, traits = []},
	{seed = 33, sid = "gold", kind = "nugget", gi = 2, traits = []}, {seed = 34, sid = "nativecu", kind = "nugget", gi = 2, traits = []},
	{seed = 35, sid = "malachite", kind = "crystal", gi = 2, traits = []}, {seed = 36, sid = "opal", kind = "crystal", gi = 3, traits = []},
	{seed = 37, sid = "azurite", kind = "druse", gi = 2, traits = []}, {seed = 38, sid = "gold", kind = "nugget", gi = 3, traits = []},
	{seed = 39, sid = "fluorite", kind = "geode", gi = 2, traits = []}, {seed = 40, sid = "chrysocolla", kind = "crystal", gi = 2, traits = []},
	{seed = 41, sid = "sapphire", kind = "crystal", gi = 3, traits = ["phantom", "zoned"]}, {seed = 42, sid = "halite", kind = "crystal", gi = 2, traits = []}],
	[{seed = 51, sid = "ruby", cut = "cab"}, {seed = 52, sid = "emerald", cut = "facet"}, {seed = 53, sid = "sapphire", cut = "master"},
	{seed = 54, jewel = {rid = "ring", cols = ["#d0342c"]}}, {seed = 55, jewel = {rid = "ear", cols = ["#2e8b57", "#2e8b57"]}},
	{seed = 56, jewel = {rid = "pend", cols = ["#3a5fcd", "#ffffff"]}}, {seed = 57, jewel = {rid = "brooch", cols = ["#9b30ff", "#ffd700", "#40e0d0"]}},
	{seed = 58, jewel = {rid = "diadem", cols = ["#ff1744", "#2979ff", "#00e676", "#ffffff"]}}, {seed = 59, jewel = {rid = "crown", cols = ["#e0115f", "#0f52ba", "#50c878", "#e8f4ff", "#ffd700"]}},
	{machine = "hammer"}, {machine = "tbm"}, {machine = "crush"}],
	[{seed = 61, sid = "quartz", kind = "druse", gi = 2, traits = ["moss"]}, {seed = 62, sid = "amethyst", kind = "crystal", gi = 3, traits = ["moss"]},
	{seed = 63, sid = "fluorite", kind = "crystal", gi = 2, traits = []}, {seed = 64, sid = "aquamarine", kind = "druse", gi = 3, traits = ["coral"]}],
	[{seed = 71, sid = "halite", kind = "druse", gi = 2, traits = []}, {seed = 72, sid = "fluorite", kind = "crystal", gi = 3, traits = ["moss"]},
	{seed = 73, sid = "gypsum", kind = "crystal", gi = 2, traits = ["irid"]}, {seed = 74, sid = "aquamarine", kind = "crystal", gi = 3, traits = []},
	{seed = 75, sid = "celestine", kind = "druse", gi = 2, traits = ["moss"]}, {seed = 76, sid = "sylvite", kind = "crystal", gi = 2, traits = []},
	{seed = 77, sid = "amethyst", kind = "crystal", gi = 3, traits = ["aurora"]}, {seed = 78, sid = "quartz", kind = "druse", gi = 3, traits = ["moss"]}],
	[{seed = 81, sid = "amethyst", kind = "crystal", gi = 3, traits = ["eroded", "irid"]}, {seed = 82, sid = "quartz", kind = "druse", gi = 2, traits = ["silver", "moss"]},
	{seed = 83, sid = "aquamarine", kind = "crystal", gi = 3, traits = ["goldfleck"]}, {seed = 84, sid = "fluorite", kind = "crystal", gi = 2, traits = ["anomaly"]},
	{seed = 85, sid = "garnet", kind = "crystal", gi = 2, traits = ["eroded", "moss"]}, {seed = 86, sid = "ruby", kind = "crystal", gi = 3, traits = ["silver", "eroded"]},
	{seed = 87, sid = "sapphire", kind = "crystal", gi = 3, traits = ["irid"]}, {seed = 88, sid = "calcite", kind = "druse", gi = 2, traits = ["eroded", "goldfleck"]}],
	[{seed = 86, sid = "ruby", kind = "crystal", gi = 3, traits = ["silver", "eroded"]}, {seed = 81, sid = "amethyst", kind = "crystal", gi = 3, traits = ["eroded", "irid"]}],
	[{seed = 91, sid = "gold", kind = "nugget", gi = 3, traits = [], form = "vein"}, {seed = 92, sid = "nativecu", kind = "nugget", gi = 2, traits = [], form = "vein"},
	{seed = 93, sid = "quartz", kind = "crystal", gi = 3, traits = ["twin"], lustre = "dark", form = "columnar"}, {seed = 94, sid = "emerald", kind = "crystal", gi = 2, traits = [], lustre = "dark", form = "slabs"},
	{seed = 95, sid = "gold", kind = "nugget", gi = 2, traits = [], form = "vein"}, {seed = 96, sid = "amethyst", kind = "druse", gi = 2, traits = ["eroded"], lustre = "dark"},
	{seed = 97, sid = "aquamarine", kind = "crystal", gi = 3, traits = [], lustre = "dark", form = "single"}, {seed = 98, sid = "nativecu", kind = "nugget", gi = 3, traits = [], form = "vein"}],
	[{seed = 101, sid = "quartz", kind = "druse", gi = 3, traits = [], form = "slabs", accents = ["pompom", "inkspots", "clouds"]},
	{seed = 102, sid = "gypsum", kind = "crystal", gi = 2, traits = [], form = "slabs", accents = ["straw", "lichen"]},
	{seed = 103, sid = "pyrite", kind = "druse", gi = 2, traits = [], accents = ["dust"]}, {seed = 104, sid = "pyrite", kind = "crystal", gi = 3, traits = [], accents = ["pompom"]},
	{seed = 105, sid = "amethyst", kind = "crystal", gi = 3, traits = ["moss"], accents = ["pompom", "straw"]}, {seed = 106, sid = "calcite", kind = "druse", gi = 2, traits = [], accents = ["clouds", "lichen"]},
	{seed = 107, sid = "gold", kind = "nugget", gi = 2, traits = [], form = "nugget", accents = []}, {seed = 108, sid = "fluorite", kind = "druse", gi = 2, traits = ["moss"], accents = ["inkspots", "pompom"]}],
	[{seed = 111, sid = "quartz", kind = "crystal", gi = 3, traits = ["moss"], nest = "hollows", loose = 0.8, accents = ["fronds"]},
	{seed = 112, sid = "amethyst", kind = "druse", gi = 2, traits = ["moss"], nest = "hollows", loose = 0.0, accents = ["flowers", "fronds"]},
	{seed = 113, sid = "fluorite", kind = "crystal", gi = 2, traits = [], nest = "hollows", loose = 0.9, accents = ["lichen", "flowers"]},
	{seed = 114, sid = "gypsum", kind = "crystal", gi = 2, traits = ["moss"], nest = "surface", loose = 0.0, accents = ["fronds", "flowers"]},
	{seed = 115, sid = "aquamarine", kind = "druse", gi = 3, traits = [], nest = "hollows", loose = 1.0, accents = ["lichen"]},
	{seed = 116, sid = "calcite", kind = "crystal", gi = 2, traits = ["moss"], nest = "hollows", loose = 0.6, accents = ["fronds", "pompom"]},
	{seed = 117, sid = "garnet", kind = "crystal", gi = 2, traits = [], nest = "surface", loose = 0.7, accents = ["flowers"]},
	{seed = 118, sid = "emerald", kind = "crystal", gi = 3, traits = ["moss"], nest = "hollows", loose = 0.5, accents = ["fronds", "flowers"]}],
	[{seed = 116, sid = "calcite", kind = "crystal", gi = 2, traits = [], nest = "surface", loose = 0.0, accents = ["fronds", "flowers"]},
	{seed = 111, sid = "quartz", kind = "crystal", gi = 3, traits = ["moss"], nest = "hollows", loose = 0.8, accents = ["fronds", "flowers"]}],
	[{seed = 121, sid = "quartz", kind = "druse", gi = 4, traits = [], legend = true, fx = "lava", lustre = "glass"},
	{seed = 122, sid = "amethyst", kind = "crystal", gi = 4, traits = [], legend = true, fx = "heart", lustre = "glass", form = "single"},
	{seed = 123, sid = "fluorite", kind = "druse", gi = 4, traits = [], legend = true, fx = "fluor", lustre = "glass"},
	{seed = 124, sid = "aquamarine", kind = "crystal", gi = 4, traits = [], legend = true, fx = "levitate", lustre = "glass", form = "columnar"},
	{seed = 125, sid = "emerald", kind = "crystal", gi = 4, traits = [], legend = true, fx = "chameleon", lustre = "glass", form = "single"},
	{seed = 126, sid = "quartz", kind = "crystal", gi = 4, traits = [], legend = true, fx = "lightning", lustre = "glass", form = "single"},
	{seed = 127, sid = "sapphire", kind = "crystal", gi = 4, traits = [], legend = true, fx = "starry", lustre = "glass", form = "slabs"},
	{seed = 128, sid = "opal", kind = "crystal", gi = 4, traits = [], legend = true, fx = "opal", lustre = "glass", form = "pile"},
	{seed = 129, sid = "gypsum", kind = "crystal", gi = 4, traits = [], legend = true, fx = "kintsugi", lustre = "glass", form = "slabs"}],
	[{seed = 126, sid = "quartz", kind = "crystal", gi = 4, traits = [], legend = true, fx = "lightning", lustre = "glass", form = "single"},
	{seed = 129, sid = "gypsum", kind = "crystal", gi = 4, traits = [], legend = true, fx = "kintsugi", lustre = "glass", form = "slabs"}],
	[{seed = 121, sid = "quartz", kind = "druse", gi = 4, traits = [], legend = true, fx = "lava", lustre = "glass"},
	{seed = 131, sid = "amethyst", kind = "crystal", gi = 4, traits = [], legend = true, fx = "lava", lustre = "dark", form = "columnar"}],
	[{machine = "rig"}, {machine = "deep"}, {machine = "lift"}, {machine = "food"}, {machine = "vent"}, {machine = "crush"}],
	# set 15: the generator's known troubles: sunbursts and columns without rock, accents on geodes, the geode lip,
	# mushrooms under big crystals, columns standing apart from the block
	[{seed = 201, sid = "quartz", kind = "druse", gi = 3, traits = ["irid"], form = "radial"},
	{seed = 202, sid = "calcite", kind = "crystal", gi = 2, traits = [], form = "radial"},
	{seed = 350, sid = "calcite", kind = "druse", gi = 2, traits = [], form = "columnar"},
	{seed = 386, sid = "calcite", kind = "druse", gi = 2, traits = [], form = "columnar"},
	{seed = 305, sid = "calcite", kind = "druse", gi = 2, traits = [], form = "columnar"},
	{seed = 206, sid = "emerald", kind = "geode", gi = 2, traits = [], accents = ["pompom", "lichen"]},
	{seed = 207, sid = "amethyst", kind = "geode", gi = 3, traits = [], accents = ["straw", "pompom"]},
	{seed = 208, sid = "fluorite", kind = "geode", gi = 2, traits = []},
	{seed = 209, sid = "fluorite", kind = "druse", gi = 2, traits = [], form = "pile", shroom = 0},
	{seed = 210, sid = "fluorite", kind = "druse", gi = 2, traits = [], form = "hopper", shroom = 1},
	{seed = 211, sid = "quartz", kind = "druse", gi = 3, traits = [], form = "cluster", shroom = 2},
	{seed = 212, sid = "garnet", kind = "crystal", gi = 2, traits = [], form = "single", shroom = 3}],
	# set 16: plates and columns whose foot misses the rock lie broken off at the foot of the block
	[{seed = 1, sid = "sapphire", kind = "druse", gi = 3, traits = [], form = "slabs"}, {seed = 2, sid = "sapphire", kind = "druse", gi = 3, traits = [], form = "slabs"},
	{seed = 4, sid = "sapphire", kind = "druse", gi = 3, traits = [], form = "slabs"}, {seed = 8, sid = "sapphire", kind = "druse", gi = 3, traits = [], form = "slabs"},
	{seed = 2, sid = "sapphire", kind = "druse", gi = 3, traits = [], form = "columnar"}, {seed = 5, sid = "sapphire", kind = "druse", gi = 3, traits = [], form = "columnar"},
	{seed = 11, sid = "sapphire", kind = "druse", gi = 3, traits = [], form = "columnar"}, {seed = 13, sid = "sapphire", kind = "druse", gi = 3, traits = [], form = "columnar"}],
	# set 17: the druzy coat on different forms, and finds carrying many traits at once
	[{seed = 301, sid = "quartz", kind = "crystal", gi = 2, traits = ["moss", "druzy", "anomaly"], form = "columnar", accents = ["flowers", "lichen", "pompom"]},
	{seed = 302, sid = "calcite", kind = "druse", gi = 2, traits = ["moss", "zoned", "druzy"], accents = ["lichen"]},
	{seed = 303, sid = "gold", kind = "nugget", gi = 3, traits = ["coral", "zoned", "phantom", "bubbles"], accents = ["pompom"]},
	{seed = 304, sid = "amethyst", kind = "crystal", gi = 3, traits = ["druzy"], form = "single"},
	{seed = 305, sid = "fluorite", kind = "druse", gi = 2, traits = ["druzy"], form = "cluster"},
	{seed = 306, sid = "quartz", kind = "druse", gi = 2, traits = ["druzy"], form = "slabs"},
	{seed = 307, sid = "emerald", kind = "crystal", gi = 2, traits = ["druzy", "moss"], accents = ["flowers", "pompom"]},
	{seed = 308, sid = "calcite", kind = "crystal", gi = 2, traits = ["druzy"]}],
	# set 18: ammonites — on a slab, loose, sawn in half; with nacre (rainbow film makes ammolite)
	[{seed = 401, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "matrix", hetero = ""},
	{seed = 402, sid = "ammonite", kind = "fossil", gi = 2, traits = ["irid"], show = "matrix", hetero = ""},
	{seed = 403, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "loose", hetero = ""},
	{seed = 404, sid = "ammonite", kind = "fossil", gi = 3, traits = ["irid"], show = "loose", hetero = ""},
	{seed = 405, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "split", hetero = ""},
	{seed = 406, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "split", hetero = ""},
	{seed = 407, sid = "ammonite", kind = "fossil", gi = 3, traits = [], show = "split", hetero = ""},
	{seed = 408, sid = "ammonite", kind = "fossil", gi = 2, traits = ["moss"], show = "matrix", hetero = ""}],
	# set 19: ammolite — the nacre's share and its fire
	[{seed = 411, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "loose", nacre = 0.1, fire = "red", hetero = ""},
	{seed = 412, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "loose", nacre = 0.35, fire = "red", hetero = ""},
	{seed = 413, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "loose", nacre = 0.65, fire = "green", hetero = ""},
	{seed = 414, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "loose", nacre = 0.95, fire = "red", hetero = ""},
	{seed = 415, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "matrix", nacre = 0.5, fire = "green", hetero = ""},
	{seed = 416, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "loose", nacre = 0.9, fire = "blue", hetero = ""},
	{seed = 417, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "loose", nacre = 0.8, fire = "violet", hetero = ""},
	{seed = 418, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "split", nacre = 0.6, fire = "red", hetero = ""}],
	# set 20: sawn ammonites, every filling of the chambers
	[{seed = 421, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "split", fill = "calcite", hetero = ""},
	{seed = 422, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "split", fill = "white", hetero = ""},
	{seed = 423, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "split", fill = "pyrite", hetero = ""},
	{seed = 424, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "split", fill = "agate", hetero = ""},
	{seed = 425, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "split", fill = "ammolite", fire = "green", hetero = ""},
	{seed = 426, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "split", fill = "calcite", hetero = ""},
	{seed = 427, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "loose", pal = 3, nacre = 0.0, hetero = ""},
	{seed = 428, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "loose", pal = 3, nacre = 0.3, fire = "green", hetero = ""}],
	# set 21: a matched pair, crystal-lined chambers, a brood, crushed in shale, the three heteromorphs, dragon fire
	[{seed = 431, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "split", pair = true, hollow = 0.0, fill = "calcite", hetero = ""},
	{seed = 432, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "split", pair = false, hollow = 0.6, fill = "calcite", hetero = ""},
	{seed = 433, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "matrix", brood = 3, crushed = false, hetero = ""},
	{seed = 434, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "matrix", crushed = true, brood = 0, hetero = "", pal = 4},
	{seed = 435, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "loose", hetero = "open"},
	{seed = 436, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "loose", hetero = "helix"},
	{seed = 437, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "loose", hetero = "hook"},
	{seed = 438, sid = "ammonite", kind = "fossil", gi = 4, traits = [], show = "split", legend = true, fx = "dragonfire", pair = false, hollow = 0.0, fill = "ammolite", nacre = 0.8, hetero = ""},
	{seed = 439, sid = "ammonite", kind = "fossil", gi = 4, traits = [], show = "split", legend = true, fx = "dragonfire", pair = true, hollow = 0.0, fill = "calcite", nacre = 0.7, hetero = ""}],
	# set 22: jellyfish round a crystal, a druse, a geode, an ammonite
	[{seed = 501, sid = "aquamarine", kind = "crystal", gi = 4, traits = [], legend = true, fx = "jellyfish", lustre = "glass", form = "single"},
	{seed = 502, sid = "amethyst", kind = "druse", gi = 4, traits = [], legend = true, fx = "jellyfish", lustre = "glass"},
	{seed = 503, sid = "fluorite", kind = "geode", gi = 4, traits = [], legend = true, fx = "jellyfish"},
	{seed = 504, sid = "ammonite", kind = "fossil", gi = 4, traits = [], legend = true, fx = "jellyfish", show = "loose", hetero = ""}],
	# set 23: petrified wood — slices (palettes, cracks, a hollow heart), logs, opal
	[{seed = 601, sid = "petrified_wood", kind = "fossil", gi = 2, traits = [], show = "slice", pal = 0, opal = 0.0, checks = 2, ck_fill = "quartz", heart = "", pockets = 0, star = 7, rind = 0.04},
	{seed = 602, sid = "petrified_wood", kind = "fossil", gi = 2, traits = [], show = "slice", pal = 1, opal = 0.0, checks = 3, ck_fill = "empty", heart = "", pockets = 7, rind = 0.06, star = 5},
	{seed = 603, sid = "petrified_wood", kind = "fossil", gi = 2, traits = [], show = "slice", pal = 4, opal = 0.0, checks = 1, ck_fill = "quartz", heart = "amethyst"},
	{seed = 604, sid = "petrified_wood", kind = "fossil", gi = 2, traits = [], show = "slice", pal = 2, opal = 0.2, fire = "green", checks = 3, heart = ""},
	{seed = 605, sid = "petrified_wood", kind = "fossil", gi = 2, traits = [], show = "log", pal = 0, opal = 0.0, checks = 2, ck_fill = "quartz"},
	{seed = 606, sid = "petrified_wood", kind = "fossil", gi = 2, traits = [], show = "log", pal = 3, opal = 0.0, checks = 0},
	{seed = 607, sid = "petrified_wood", kind = "fossil", gi = 2, traits = [], show = "slice", opal = 0.85, fire = "blue", checks = 2, heart = ""},
	{seed = 608, sid = "petrified_wood", kind = "fossil", gi = 2, traits = [], show = "log", opal = 0.7, fire = "green", checks = 2}],
	# set 24: opalized wood — slices with opal pools between the chunks (dark, crystal, honey body), a log
	[{seed = 611, sid = "petrified_wood", kind = "fossil", gi = 2, traits = [], show = "slice", opal = 0.75, fire = "blue", body = "dark", spread = 0.5, pal = 1, bark = 1.0, checks = 0, heart = ""},
	{seed = 612, sid = "petrified_wood", kind = "fossil", gi = 2, traits = [], show = "slice", opal = 0.5, fire = "green", body = "crystal", spread = 0.4, pal = 3, bark = 0.8, checks = 0, heart = ""},
	{seed = 613, sid = "petrified_wood", kind = "fossil", gi = 2, traits = [], show = "slice", opal = 0.9, fire = "red", body = "honey", spread = 0.3, pal = 1, bark = 1.0, checks = 0, heart = ""},
	{seed = 614, sid = "petrified_wood", kind = "fossil", gi = 2, traits = [], show = "log", opal = 0.6, fire = "violet", body = "dark", spread = 0.5, pal = 2, bark = 0.8, checks = 0}],
	# set 25: opal twigs
	[{seed = 621, sid = "petrified_wood", kind = "fossil", gi = 2, traits = [], show = "twig", opal = 0.7, fire = "red", body = "dark", spread = 0.45},
	{seed = 622, sid = "petrified_wood", kind = "fossil", gi = 2, traits = [], show = "twig", opal = 0.5, fire = "green", body = "dark", spread = 0.35},
	{seed = 623, sid = "petrified_wood", kind = "fossil", gi = 2, traits = [], show = "twig", opal = 0.8, fire = "blue", body = "crystal", spread = 0.4},
	{seed = 624, sid = "petrified_wood", kind = "fossil", gi = 2, traits = [], show = "twig", opal = 0.6, fire = "violet", body = "dark", spread = 0.5}],
	# set 26: driftwood — opal chunks in a hollow (honey, crystal), a crystal glowing from inside with jelly fungi
	[{seed = 631, sid = "petrified_wood", kind = "fossil", gi = 2, traits = [], show = "driftwood", core = "opal", fungi = false, body = "honey", fire = "red", spread = 0.35},
	{seed = 632, sid = "petrified_wood", kind = "fossil", gi = 2, traits = [], show = "driftwood", core = "opal", fungi = false, body = "crystal", fire = "blue", spread = 0.4},
	{seed = 633, sid = "petrified_wood", kind = "fossil", gi = 2, traits = [], show = "driftwood", core = "crystal", fungi = true},
	{seed = 634, sid = "petrified_wood", kind = "fossil", gi = 2, traits = [], show = "driftwood", core = "crystal", fungi = true}],
	# set 27: fulgurites — hollow, branching like the strike; sands and glasses, in the sand, froth, iron, a fresh strike,
	# living lightning
	[{seed = 641, sid = "fulgurite", kind = "fossil", gi = 2, traits = [], open = 0.5, sand = 0, glass = 0, show = "loose", froth = 0.0, iron = false, hot = false},
	{seed = 642, sid = "fulgurite", kind = "fossil", gi = 2, traits = [], open = 0.4, sand = 1, glass = 1, show = "sand", froth = 0.0, iron = false, hot = false},
	{seed = 643, sid = "fulgurite", kind = "fossil", gi = 2, traits = [], open = 0.6, sand = 2, glass = 1, show = "loose", froth = 0.0, iron = true, hot = false},
	{seed = 644, sid = "fulgurite", kind = "fossil", gi = 2, traits = [], open = 0.4, sand = 3, glass = 3, show = "sand", froth = 0.8, iron = false, hot = false},
	{seed = 645, sid = "fulgurite", kind = "fossil", gi = 2, traits = [], open = 0.5, sand = 4, glass = 2, show = "loose", froth = 0.5, iron = true, hot = false},
	{seed = 646, sid = "fulgurite", kind = "fossil", gi = 2, traits = [], open = 0.5, sand = 1, glass = 1, show = "sand", froth = 0.0, iron = false, hot = true},
	{seed = 647, sid = "fulgurite", kind = "fossil", gi = 2, traits = [], open = 0.5, sand = 0, glass = 0, show = "loose", froth = 0.0, iron = false, hot = false, legend = true, fx = "discharge"},
	{seed = 648, sid = "fulgurite", kind = "fossil", gi = 2, traits = [], open = 0.5, sand = 3, glass = 3, show = "sand", froth = 0.3, iron = false, hot = false, legend = true, fx = "discharge"}],
	# set 28: flowers in stone — every form, colours, leaves; quartz, smoky, amber
	[{seed = 651, sid = "flower_quartz", kind = "fossil", gi = 2, traits = [], bloom = "star", look = 0, host = "quartz", leaves = 0, gold = true},
	{seed = 652, sid = "flower_quartz", kind = "fossil", gi = 2, traits = [], bloom = "rose", look = 2, host = "quartz", leaves = 2, gold = false},
	{seed = 653, sid = "flower_quartz", kind = "fossil", gi = 2, traits = [], bloom = "daisy", look = 3, host = "smoky", leaves = 1, gold = false},
	{seed = 654, sid = "flower_quartz", kind = "fossil", gi = 2, traits = [], bloom = "bell", look = 7, host = "quartz", leaves = 2, gold = false},
	{seed = 655, sid = "flower_quartz", kind = "fossil", gi = 2, traits = [], bloom = "blossom", look = 4, host = "quartz", leaves = 2, gold = false},
	{seed = 656, sid = "flower_quartz", kind = "fossil", gi = 2, traits = [], bloom = "poppy", look = 8, host = "amber", leaves = 0, gold = false},
	{seed = 657, sid = "flower_quartz", kind = "fossil", gi = 2, traits = [], bloom = "star", look = 9, host = "quartz", leaves = 3, gold = true},
	{seed = 658, sid = "flower_quartz", kind = "fossil", gi = 2, traits = [], bloom = "daisy", look = 6, host = "quartz", leaves = 2, gold = false}],
	# set 29: amber — every insect; copal; a flower in amber
	[{seed = 661, sid = "amber", kind = "fossil", gi = 2, traits = [], content = "insect", insect = "ant", host = "amber", tone = "honey", crust = 0.0, spangle = false},
	{seed = 662, sid = "amber", kind = "fossil", gi = 2, traits = [], content = "insect", insect = "beetle", host = "amber", tone = "cognac", crust = 0.0, spangle = true},
	{seed = 663, sid = "amber", kind = "fossil", gi = 2, traits = [], content = "insect", insect = "fly", host = "copal", crust = 0.0},
	{seed = 664, sid = "amber", kind = "fossil", gi = 2, traits = [], content = "insect", insect = "mosquito", host = "amber", tone = "lemon", crust = 0.5, spangle = false},
	{seed = 665, sid = "amber", kind = "fossil", gi = 2, traits = [], content = "insect", insect = "spider", host = "amber", tone = "cherry", crust = 0.0},
	{seed = 666, sid = "amber", kind = "fossil", gi = 2, traits = [], content = "flower", bloom = "blossom", look = 3, host = "amber", tone = "honey", crust = 0.7},
	{seed = 667, sid = "amber", kind = "fossil", gi = 2, traits = [], content = "fern", host = "amber", tone = "cognac", crust = 0.3},
	{seed = 668, sid = "amber", kind = "fossil", gi = 2, traits = [], content = "feather", host = "amber", tone = "honey", spangle = true, crust = 0.0}],
	# set 30: driftwood's life — lichen, moss, beetle galleries, the sea (shipworm, barnacles), foxfire, a staple, a pebble
	[{seed = 671, sid = "petrified_wood", kind = "fossil", gi = 2, traits = [], show = "driftwood", core = "crystal", fungi = false, sea = false, lichen = 0.9, moss = 0.6, galleries = 0.0, foxfire = false, staple = false, pebble = ""},
	{seed = 672, sid = "petrified_wood", kind = "fossil", gi = 2, traits = [], show = "driftwood", core = "crystal", fungi = false, sea = false, lichen = 0.0, moss = 0.0, galleries = 1.0, foxfire = false, staple = true, pebble = ""},
	{seed = 673, sid = "petrified_wood", kind = "fossil", gi = 2, traits = [], show = "driftwood", core = "opal", fungi = false, sea = true, lichen = 0.0, moss = 0.0, galleries = 0.0, foxfire = false, staple = false, pebble = ""},
	{seed = 674, sid = "petrified_wood", kind = "fossil", gi = 2, traits = [], show = "driftwood", core = "crystal", fungi = true, sea = false, lichen = 0.0, moss = 0.5, galleries = 0.5, foxfire = true, staple = false, pebble = ""},
	{seed = 675, sid = "petrified_wood", kind = "fossil", gi = 2, traits = [], show = "driftwood", core = "opal", fungi = false, sea = true, lichen = 0.0, moss = 0.0, galleries = 0.0, foxfire = false, staple = true, pebble = "jasper"},
	{seed = 676, sid = "petrified_wood", kind = "fossil", gi = 2, traits = [], show = "driftwood", core = "crystal", fungi = true, sea = false, lichen = 0.7, moss = 0.0, galleries = 0.6, foxfire = false, staple = false, pebble = "garnet"},
	{seed = 677, sid = "petrified_wood", kind = "fossil", gi = 2, traits = [], show = "driftwood", core = "opal", fungi = true, sea = false, lichen = 0.5, moss = 0.8, galleries = 0.0, foxfire = false, staple = false, pebble = "quartz"},
	{seed = 678, sid = "petrified_wood", kind = "fossil", gi = 2, traits = [], show = "driftwood", core = "crystal", fungi = false, sea = true, lichen = 0.0, moss = 0.0, galleries = 0.0, foxfire = true, staple = false, pebble = "agate"}],
	# set 31: trilobites, every kind: elrathia on shale, phacops, asaphus on its stalks, dicranurus, walliserops, isotelus
	[{seed = 701, sid = "trilobite", kind = "fossil", gi = 2, traits = [], genus = "elrathia", show = "matrix", pal = 0, accents = [], moult = false, bite = false, soft = false},
	{seed = 702, sid = "trilobite", kind = "fossil", gi = 2, traits = [], genus = "phacops", show = "prepared", pal = 1, moult = false, bite = false, soft = false},
	{seed = 703, sid = "trilobite", kind = "fossil", gi = 2, traits = [], genus = "asaphus", show = "prepared", moult = false, bite = false, soft = false},
	{seed = 704, sid = "trilobite", kind = "fossil", gi = 2, traits = [], genus = "dicranurus", show = "prepared", moult = false, bite = false, soft = false},
	{seed = 705, sid = "trilobite", kind = "fossil", gi = 2, traits = [], genus = "walliserops", show = "prepared", moult = false, bite = false, soft = false},
	{seed = 706, sid = "trilobite", kind = "fossil", gi = 2, traits = [], genus = "isotelus", show = "matrix", moult = false, bite = false, soft = false},
	{seed = 707, sid = "trilobite", kind = "fossil", gi = 2, traits = [], genus = "phacops", show = "enrolled", pal = 2, moult = false, bite = false, soft = false},
	{seed = 708, sid = "trilobite", kind = "fossil", gi = 2, traits = [], genus = "phacops", show = "matrix", pal = 4, moult = false, bite = false, soft = false}],
	# set 32: trilobites' rarities: a plate of several, a moult, a healed bite, legs in pyrite, awakened
	[{seed = 711, sid = "trilobite", kind = "fossil", gi = 2, traits = [], genus = "elrathia", show = "mass", mass = 5, moult = false, bite = false, soft = false},
	{seed = 712, sid = "trilobite", kind = "fossil", gi = 2, traits = [], genus = "elrathia", show = "matrix", moult = true, bite = false, soft = false},
	{seed = 713, sid = "trilobite", kind = "fossil", gi = 2, traits = [], genus = "isotelus", show = "matrix", moult = false, bite = true, soft = false},
	{seed = 714, sid = "trilobite", kind = "fossil", gi = 2, traits = [], genus = "elrathia", show = "matrix", moult = false, bite = false, soft = true},
	{seed = 715, sid = "trilobite", kind = "fossil", gi = 3, traits = [], genus = "phacops", show = "matrix", moult = false, bite = false, soft = true, legend = true, fx = "awaken"},
	{seed = 716, sid = "trilobite", kind = "fossil", gi = 2, traits = [], genus = "phacops", show = "mass", mass = 3, pal = 3, moult = false, bite = false, soft = false},
	{seed = 717, sid = "trilobite", kind = "fossil", gi = 2, traits = [], genus = "asaphus", show = "matrix", moult = false, bite = false, soft = false},
	{seed = 718, sid = "trilobite", kind = "fossil", gi = 2, traits = [], genus = "walliserops", show = "matrix", pal = 4, moult = false, bite = false, soft = false}]
,
	# set 33: pearls in their oyster: akoya, Tahitian, golden, south sea; on a valve with a blister; loose
	[{seed = 721, sid = "pearl", kind = "fossil", gi = 2, traits = [], body = "akoya", shape = "round", show = "shell", count = 1, barnacles = true},
	{seed = 722, sid = "pearl", kind = "fossil", gi = 2, traits = [], body = "tahitian", shape = "near", show = "shell", count = 1, tone = 0},
	{seed = 723, sid = "pearl", kind = "fossil", gi = 2, traits = [], body = "golden", shape = "round", show = "shell", count = 2},
	{seed = 724, sid = "pearl", kind = "fossil", gi = 2, traits = [], body = "south_sea", shape = "drop", show = "shell", count = 1, seeds = true},
	{seed = 725, sid = "pearl", kind = "fossil", gi = 2, traits = [], body = "akoya", shape = "round", show = "valve"},
	{seed = 726, sid = "pearl", kind = "fossil", gi = 2, traits = [], body = "tahitian", shape = "round", show = "valve", tone = 1},
	{seed = 727, sid = "pearl", kind = "fossil", gi = 2, traits = [], body = "akoya", shape = "baroque", show = "loose", count = 1},
	{seed = 728, sid = "pearl", kind = "fossil", gi = 3, traits = [], body = "south_sea", shape = "round", show = "shell", count = 1, legend = true, fx = "moon"}],
	# set 34: loose pearls, every body and shape
	[{seed = 731, sid = "pearl", kind = "fossil", gi = 2, traits = [], body = "akoya", shape = "round", show = "loose", count = 1, luster = 1.0},
	{seed = 732, sid = "pearl", kind = "fossil", gi = 2, traits = [], body = "tahitian", shape = "circled", show = "loose", count = 1, tone = 0},
	{seed = 733, sid = "pearl", kind = "fossil", gi = 2, traits = [], body = "tahitian", shape = "drop", show = "loose", count = 1, tone = 2},
	{seed = 734, sid = "pearl", kind = "fossil", gi = 2, traits = [], body = "golden", shape = "button", show = "loose", count = 1},
	{seed = 735, sid = "pearl", kind = "fossil", gi = 2, traits = [], body = "conch", shape = "near", show = "loose", count = 1},
	{seed = 736, sid = "pearl", kind = "fossil", gi = 2, traits = [], body = "melo", shape = "near", show = "loose", count = 1},
	{seed = 737, sid = "pearl", kind = "fossil", gi = 2, traits = [], body = "south_sea", shape = "baroque", show = "loose", count = 3},
	{seed = 738, sid = "pearl", kind = "fossil", gi = 3, traits = [], body = "tahitian", shape = "round", show = "loose", count = 1, legend = true, fx = "moon"}],
	# set 35: trilobites at sea: split nodules, opal, gold pyrite, sea lilies, the awakening crawling
	[{seed = 741, sid = "trilobite", kind = "fossil", gi = 2, traits = [], genus = "phacops", show = "nodule", pal = 2, moult = false, bite = false, soft = false},
	{seed = 742, sid = "trilobite", kind = "fossil", gi = 2, traits = [], genus = "elrathia", show = "nodule", pal = 0, moult = false, bite = false, soft = false},
	{seed = 743, sid = "trilobite", kind = "fossil", gi = 2, traits = [], genus = "isotelus", show = "nodule", pal = 6, moult = false, bite = false, soft = false},
	{seed = 744, sid = "trilobite", kind = "fossil", gi = 2, traits = [], genus = "phacops", show = "prepared", pal = 6, moult = false, bite = false, soft = false},
	{seed = 745, sid = "trilobite", kind = "fossil", gi = 2, traits = [], genus = "asaphus", show = "matrix", pal = 4, moult = false, bite = false, soft = false},
	{seed = 746, sid = "trilobite", kind = "fossil", gi = 2, traits = [], genus = "elrathia", show = "matrix", pal = 0, moult = false, bite = false, soft = false},
	{seed = 747, sid = "trilobite", kind = "fossil", gi = 2, traits = [], genus = "isotelus", show = "mass", mass = 3, pal = 1, moult = false, bite = false, soft = false},
	{seed = 748, sid = "trilobite", kind = "fossil", gi = 3, traits = [], genus = "phacops", show = "matrix", moult = false, bite = false, soft = true, legend = true, fx = "awaken"}],
	# set 36: trilobites with pearl oysters on their slab (1-3, open or shut; the pearl is a trilobite's gene now)
	[{seed = 751, sid = "trilobite", kind = "fossil", gi = 2, traits = [], genus = "elrathia", show = "matrix", pal = 0, oysters = 3, moult = false, bite = false, soft = false},
	{seed = 752, sid = "trilobite", kind = "fossil", gi = 2, traits = [], genus = "phacops", show = "matrix", pal = 1, oysters = 1, moult = false, bite = false, soft = false},
	{seed = 753, sid = "trilobite", kind = "fossil", gi = 2, traits = [], genus = "isotelus", show = "matrix", pal = 5, oysters = 2, moult = false, bite = false, soft = false},
	{seed = 754, sid = "trilobite", kind = "fossil", gi = 2, traits = [], genus = "asaphus", show = "matrix", pal = 3, oysters = 1, moult = false, bite = false, soft = false},
	{seed = 755, sid = "trilobite", kind = "fossil", gi = 2, traits = [], genus = "elrathia", show = "mass", mass = 4, pal = 0, oysters = 2, moult = false, bite = false, soft = false},
	{seed = 756, sid = "trilobite", kind = "fossil", gi = 2, traits = [], genus = "walliserops", show = "matrix", pal = 4, oysters = 1, moult = false, bite = false, soft = false},
	{seed = 757, sid = "trilobite", kind = "fossil", gi = 2, traits = [], genus = "phacops", show = "matrix", pal = 6, oysters = 1, moult = false, bite = false, soft = false},
	{seed = 758, sid = "trilobite", kind = "fossil", gi = 3, traits = [], genus = "phacops", show = "matrix", oysters = 1, moult = false, bite = false, soft = true, legend = true, fx = "awaken"}],
	# set 37: ammonites on their slab in the sea (lilies, light through water, bubbles); trilobites with moon pearls
	[{seed = 401, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "matrix", hetero = ""},
	{seed = 402, sid = "ammonite", kind = "fossil", gi = 2, traits = ["irid"], show = "matrix", hetero = ""},
	{seed = 433, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "matrix", brood = 3, crushed = false, hetero = ""},
	{seed = 415, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "matrix", nacre = 0.5, fire = "green", hetero = ""},
	{seed = 761, sid = "trilobite", kind = "fossil", gi = 3, traits = [], genus = "elrathia", show = "matrix", pal = 0, oysters = 2, moult = false, bite = false, soft = false, legend = true, fx = "moon"},
	{seed = 762, sid = "trilobite", kind = "fossil", gi = 3, traits = [], genus = "phacops", show = "matrix", pal = 1, oysters = 1, moult = false, bite = false, soft = false, legend = true, fx = "moon"},
	{seed = 763, sid = "trilobite", kind = "fossil", gi = 3, traits = [], genus = "isotelus", show = "mass", mass = 3, pal = 5, oysters = 3, moult = false, bite = false, soft = false, legend = true, fx = "moon"},
	{seed = 434, sid = "ammonite", kind = "fossil", gi = 2, traits = [], show = "matrix", crushed = true, brood = 0, hetero = "", pal = 4}],
	# set 38: the trilobite's new legendaries: the hunter (Anomalocaris circling, the trilobite rolling up), deep-sea glow
	[{seed = 771, sid = "trilobite", kind = "fossil", gi = 3, traits = [], genus = "elrathia", show = "matrix", pal = 0, oysters = 0, moult = false, bite = false, soft = false, legend = true, fx = "hunter"},
	{seed = 772, sid = "trilobite", kind = "fossil", gi = 3, traits = [], genus = "phacops", show = "prepared", pal = 1, oysters = 0, moult = false, bite = false, soft = false, legend = true, fx = "hunter"},
	{seed = 773, sid = "trilobite", kind = "fossil", gi = 3, traits = [], genus = "phacops", show = "matrix", pal = 2, oysters = 0, moult = false, bite = false, soft = false, legend = true, fx = "hunter"},
	{seed = 774, sid = "trilobite", kind = "fossil", gi = 3, traits = [], genus = "asaphus", show = "prepared", pal = 3, oysters = 0, moult = false, bite = false, soft = false, legend = true, fx = "hunter"},
	{seed = 775, sid = "trilobite", kind = "fossil", gi = 3, traits = [], genus = "isotelus", show = "matrix", pal = 5, oysters = 0, moult = false, bite = false, soft = false, legend = true, fx = "glow"},
	{seed = 776, sid = "trilobite", kind = "fossil", gi = 3, traits = [], genus = "walliserops", show = "prepared", pal = 2, oysters = 0, moult = false, bite = false, soft = false, legend = true, fx = "glow"},
	{seed = 777, sid = "trilobite", kind = "fossil", gi = 3, traits = [], genus = "phacops", show = "enrolled", pal = 1, oysters = 0, moult = false, bite = false, soft = false, legend = true, fx = "glow"},
	{seed = 778, sid = "trilobite", kind = "fossil", gi = 3, traits = [], genus = "dicranurus", show = "prepared", pal = 1, oysters = 0, moult = false, bite = false, soft = false, legend = true, fx = "hunter"}]
]

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var list: Array = SETS[int(args.get("set", "0"))]
	if args.has("only"): list = [list[int(args.only)]]  # one specimen, e.g. for the app icon: -- set=11 only=1 clean
	var cols := int(args.get("cols", "4"))
	var px := int(args.get("px", "280"))
	var t0 := Time.get_ticks_msec()
	for i in list.size():
		var v := SpecView.new(px, args.has("alpha"))   # alpha: no backdrop, the shot is the first stone alone
		v.position = Vector2((i % cols) * px, (i / cols) * px)
		v.size = Vector2(px, px)
		v.still = args.has("still")
		add_child(v)
		if list[i].has("fx") and not args.has("clean"):
			var l := Label.new()
			l.text = SpecLegend.FX_N.get(list[i].fx, list[i].fx)
			l.position = v.position + Vector2(10, 8)
			l.add_theme_font_size_override("font_size", 20)
			l.add_theme_color_override("font_outline_color", Color.BLACK)
			l.add_theme_constant_override("outline_size", 6)
			add_child(l)
		var t1 := Time.get_ticks_msec()
		await v.show_spec(list[i])
		print("built ", list[i].get("sid", list[i].get("machine", "jewel")), " in ", Time.get_ticks_msec() - t1, " ms")
		if v.live and list[i].has("sid"):
			print("  grown: ", ", ".join((v.live.get_meta("grown", {}) as Dictionary).keys()))
	print("total ", Time.get_ticks_msec() - t0, " ms")
	if args.has("shot"):
		await get_tree().create_timer(float(args.get("after", "3"))).timeout
		await RenderingServer.frame_post_draw
		var vp: Viewport = (get_child(0) as SpecView).studio.vp if args.has("alpha") else get_viewport()
		vp.get_texture().get_image().save_png(args.shot)
		print("shot saved")
		get_tree().quit()
