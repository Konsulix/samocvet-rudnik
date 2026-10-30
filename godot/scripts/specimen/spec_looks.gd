class_name SpecLooks
extends RefCounted
## Each species' own look, so a new species feels new (docs/species-looks.md): the layouts it grows in and the kinds
## of find it comes as, its proportions, the rock it likes, how often it rolls the dark lustre, and the one detail it
## always has. Whatever is not set here is as before; the common layer (growths, mushrooms, moss, rare traits,
## legendary effects) still comes to any species. A layout the real mineral never takes is sometimes allowed, so
## nothing the generator can do is lost (hopper cubes on fluorite, hex plates on aquamarine).
##
## forms   [[layout, weight]] for crystal and druse finds (a druse weighs "cluster" up)
## kinds   [[crystal | druse | geode, weight]]
## rock    [[rock, weight]]
## dark    the chance of the dark opaque lustre (5% when not set)
## hk, wk  height and thickness of the crystals; short ones, like amethyst's points, are low hk
## blunt   flat-ended prisms (the beryls), no point
## zone    always zoned: [mode, strength, hue shift] — mode 0 pale base, coloured tip; 1 dark base; 2 two colours
## sig     traits it always has (not named on the card: they are what the species is)
## more    traits it rolls more often: {trait: extra chance}
## core    a cube of another colour inside each crystal (fluorite's phantom cubes), [hex colour, size 0..1]
## palette the species' colours, picked per find on its own stream: [[body hex, core hex, weight], ...] (the core colour
##         replaces core's)
## rose    the rosette as a desert rose: frosted, sand-coloured petals, [hex colour from, hex colour to]
## with    companions: [[blades | crust, hex colour, chance, gene id], ...] — another mineral on the same rock
## opaque  no glass: a waxy or resinous lit surface {rough, coat, grain}
## ir      how much rainbow film / holographic sheen the species takes (1 as before)
## metal_col  a metal species' own colour (hematite's dark steel)
## rose_metal  the rosette's blades in steel (hematite's iron rose)
## dense   how many crystals a druse packs (x)
## growths the chance anything of the common layer (growths, mushrooms) grows on it at all
## no_acc  accents it never takes (dark inclusions in sulphur's glass)
## rose_n, rose_s  the rose's blade count and size (x): hematite's are many and small
## glass   {frost: a milky body, 0..1; dark: how dark the glass body is (smoky quartz), tint: how much the body glows in the species' own colour
##         rather than showing the room through it (garnet, azurite), 0..1}

const LOOK := {
	# Old Adit
	quartz = {forms = [["single", 3.0], ["cluster", 4.0], ["floater", 0.6], ["columnar", 0.8]], kinds = [["crystal", 5.0], ["druse", 4.0], ["geode", 0.4]],
		rock = [["quartzite", 4.0], ["basalt", 1.0], ["slate", 1.0]], hk = 1.25, wk = 0.85, more = {phantom = 0.12}},
	amethyst = {forms = [["cluster", 5.0], ["single", 0.6]], kinds = [["geode", 4.0], ["druse", 4.0], ["crystal", 0.8]],
		rock = [["basalt", 5.0], ["ironstone", 1.0]], hk = 0.4, wk = 1.15, zone = [0, 1.0, 0.0], sig = ["zoned"], more = {scepter = 0.08}},
	smoky = {forms = [["single", 4.0], ["columnar", 3.0], ["cluster", 1.0]], kinds = [["crystal", 6.0], ["druse", 2.0]],
		rock = [["quartzite", 3.0], ["slate", 1.0]], hk = 1.05, wk = 1.35, dark = 0.3, glass = {dark = 0.7}},
	calcite = {forms = [["cluster", 5.0], ["single", 2.0], ["pile", 0.6]], kinds = [["druse", 5.0], ["crystal", 3.0]],
		rock = [["limestone", 5.0], ["basalt", 1.0]]},
	fluorite = {forms = [["cluster", 5.0], ["single", 2.0], ["hopper", 0.7]], kinds = [["druse", 5.0], ["crystal", 3.0]],
		core = [0x5a2e9a, 0.42], palette = [[0x4fae6a, 0x5a2e9a, 4.0], [0x8a5ad0, 0x3a1a6a, 4.0], [0x5aa8d8, 0x2a3a8a, 2.0],
			[0xe0c040, 0x6a3aa0, 2.0], [0xdcdcd8, 0x7a4ab8, 1.5], [0xe8a0b8, 0x9a4a8a, 0.8]], glass = {tint = 0.55}},
	pyrite = {forms = [["cluster", 4.0], ["single", 2.0], ["pile", 1.0]], kinds = [["druse", 4.0], ["crystal", 4.0]],
		rock = [["slate", 5.0], ["ironstone", 1.0]]},
	garnet = {forms = [["pile", 4.0], ["single", 2.0], ["cluster", 1.0]], kinds = [["crystal", 6.0], ["druse", 2.0]],
		rock = [["slate", 6.0], ["quartzite", 1.0]], dark = 0.0, glass = {tint = 0.65}},
	# Copper Mountain
	azurite = {forms = [["radial", 6.0], ["cluster", 1.0]], kinds = [["crystal", 5.0], ["druse", 2.0]],
		rock = [["ironstone", 3.0], ["limestone", 1.0]], hk = 0.6, wk = 1.1, dark = 0.0, glass = {dark = 0.35, tint = 0.8}},
	beryl = {forms = [["single", 3.0], ["columnar", 4.0]], kinds = [["crystal", 6.0], ["druse", 1.0]], rock = [["quartzite", 2.0], ["slate", 1.0]],
		blunt = true, wk = 1.2},
	cuprite = {forms = [["pile", 4.0], ["cluster", 3.0]], kinds = [["druse", 4.0], ["crystal", 4.0]], rock = [["ironstone", 4.0], ["basalt", 1.0]], dark = 0.35,
		glass = {tint = 0.6}},
	aquamarine = {forms = [["single", 4.0], ["columnar", 3.0], ["hexplates", 0.6]], kinds = [["crystal", 6.0], ["druse", 1.0]],
		rock = [["quartzite", 3.0], ["slate", 1.0]], blunt = true, hk = 1.3, wk = 0.9, dark = 0.0},
	emerald = {forms = [["single", 5.0], ["columnar", 2.0]], kinds = [["crystal", 6.0], ["druse", 1.0]], rock = [["slate", 6.0]], blunt = true, dark = 0.0},
	# Whalebone Cove
	gypsum = {forms = [["slabs", 3.0], ["rosette", 4.0], ["radial", 1.0], ["single", 1.0]], kinds = [["crystal", 6.0], ["druse", 2.0]],
		rock = [["limestone", 3.0], ["slate", 1.0]], hk = 1.3, wk = 0.7, dark = 0.0, rose = [0x7a5a3c, 0xa4865e], more = {twin = 0.12}},
	# Fire Horizon (Sicily's sulphur mines and Etna)
	sulphur = {zone = [0, 0.0, 0.0], foot_frost = false, rock_shape = "slab", forms = [["spray", 1.0]], kinds = [["druse", 7.0], ["crystal", 2.0]],
		rock = [["gypsum", 4.0], ["limestone", 1.0]], dark = 0.0, glass = {tint = 0.75, frost = 0.3, glow = 0.24}, ir = 0.05, hk = 0.85, wk = 1.3,
		dense = 1.9, growths = 0.35, no_acc = ["inkspots", "clouds"], with = [["blades", 0xa8c8ec, 0.3, "celestine"]]},
	aragonite = {zone = [0, 0.0, 0.0], forms = [["spray", 1.0]], opaque = {rough = 0.5, coat = 0.15, grain = 0.15},
		kinds = [["druse", 5.0], ["crystal", 3.0]], rock = [["gypsum", 3.0], ["limestone", 1.0]], dark = 0.0, ir = 0.05, growths = 0.4,
		with = [["crust", 0xf0d020, 0.55, "sulphur"]]},
	realgar = {zone = [0, 0.0, 0.0], foot_frost = false, forms = [["cluster", 1.0]], kinds = [["druse", 1.0]], dense = 0.7,
		rock = [["slate", 3.0], ["lava", 2.0]], hk = 0.7, wk = 1.05, dark = 0.0, opaque = {rough = 0.18, coat = 0.7, grain = 0.25},
		ir = 0.0, blunt = true, growths = 0.3, no_acc = ["inkspots", "clouds"], with = [["crust", 0xd8681a, 0.85, "orpiment"]]},
	hematite = {forms = [["rosette", 4.0], ["platestack", 4.0]], kinds = [["crystal", 5.0], ["druse", 2.0]], rock = [["quartzite", 2.0], ["lava", 1.0]],
		rose = [0x1c1612, 0x3a3028], rose_metal = true, rose_n = 2.4, rose_s = 0.6, metal_col = 0x4c5060, growths = 0.0,
		with = [["blades", 0xeef2f6, 0.2, "rockcrystal"]]},
	olivine = {zone = [0, 0.0, 0.0], forms = [["xenolith", 1.0]], kinds = [["crystal", 1.0]], rock = [["lava", 1.0]], dark = 0.0,
		opaque = {rough = 0.22, coat = 0.8, grain = 0.0}, ir = 0.0, growths = 0.0},
	obsidian = {kinds = [["crystal", 1.0]]},
	# Proval (Svalbard's coal measures): the vein minerals of the coal and the shale, and agate from the old lavas
	siderite = {forms = [["pile", 4.0], ["cluster", 4.0]], kinds = [["druse", 5.0], ["crystal", 3.0]], rock = [["slate", 4.0], ["ironstone", 2.0]],
		hk = 0.8, wk = 1.0, dark = 0.0, opaque = {rough = 0.3, coat = 0.5, grain = 0.25}, ir = 0.1, dense = 1.4,
		with = [["blades", 0xeef2f6, 0.25, "rockcrystal"]]},
	barite = {forms = [["rosette", 4.0], ["slabs", 3.0]], kinds = [["druse", 4.0], ["crystal", 4.0]],
		rock = [["limestone", 3.0], ["slate", 2.0]], hk = 0.7, wk = 1.3, dark = 0.0, glass = {tint = 0.45, frost = 0.35}, ir = 0.1,
		rose = [0xc8b088, 0xe8dcc0], rose_n = 1.4,
		palette = [[0xe6d6b4, 0xe6d6b4, 4.0], [0xf2eee6, 0xf2eee6, 3.0], [0x9ab8d8, 0x9ab8d8, 2.0], [0xd8a868, 0xd8a868, 1.5]]},
	galena = {forms = [["cluster", 4.0], ["pile", 2.0], ["single", 1.0]], kinds = [["druse", 4.0], ["crystal", 4.0]],
		rock = [["slate", 3.0], ["quartzite", 2.0]], metal_col = 0x7a7e8a, growths = 0.3,
		with = [["blades", 0xe6d6b4, 0.3, "barite"]]},
	sphalerite = {forms = [["cluster", 4.0], ["pile", 3.0]], kinds = [["druse", 4.0], ["crystal", 3.0]], rock = [["slate", 4.0], ["limestone", 1.0]],
		dark = 0.0, glass = {tint = 0.9, dark = 0.45}, ir = 0.15,
		palette = [[0x8a3a12, 0x8a3a12, 4.0], [0xb8721a, 0xb8721a, 2.0], [0x3a2416, 0x3a2416, 2.0]]},
	chalcedony = {kinds = [["druse", 1.0]], rock = [["basalt", 4.0], ["lava", 1.0]], dark = 0.0, growths = 0.4,
		palette = [[0xa9c2dc, 0xa9c2dc, 4.0], [0xc8d4e2, 0xc8d4e2, 2.0], [0x8aa0c8, 0x8aa0c8, 1.5]]},
	celestine = {forms = [["cluster", 5.0], ["slabs", 1.0]], kinds = [["geode", 4.0], ["druse", 4.0], ["crystal", 1.0]],
		rock = [["limestone", 4.0], ["basalt", 1.0]], hk = 0.75, dark = 0.0},
}

static func of(sid: String) -> Dictionary:
	return LOOK.get(sid, {})

## the kind of find for a species (Stones.roll): its own weights, or the old ones
static func kinds(sid: String) -> Array:
	return of(sid).get("kinds", [["crystal", 5.0], ["druse", 4.0], ["geode", 1.4]])
