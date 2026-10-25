extends Node
## Deterministic distribution checks and legacy-genome compatibility.
var failed := false

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func _ready() -> void:
	var baseline: GDScript
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("baseline="): baseline = load(arg.substr(9))
	var legendary := 0
	var eligible := 0
	var mushrooms := 0
	var rich_accents := 0
	var legacy_accents := 0
	for i in 9000:
		var stone := Stones.roll(1000 + i, i % Data.AREAS.size(), float(i % 5) * 0.5, i % 5)
		if stone.legend: legendary += 1
		var recipe := Spec.of_stone(stone)
		check(recipe.gene_version == 2, "New finds must propagate the enriched profile into rendering")
		var gene := SpecGenome.of(recipe)
		if not gene.form in ["floater", "geode", "nugget", "vein", "botryoid"]:
			eligible += 1
			if gene.shroom >= 0: mushrooms += 1
		rich_accents += gene.accents.size()
		var legacy := recipe.duplicate(true)
		legacy.erase("gene_version")
		var old_gene := SpecGenome.of(legacy)
		legacy_accents += old_gene.accents.size()
		if i < 300:
			check(Spec.key_of(recipe) != Spec.key_of(legacy), "Different gene profiles must not share thumbnail cache keys")
			if baseline: check(old_gene == baseline.of(legacy), "Previously collected finds must keep their entire genome")
		check(gene.accents.size() >= 2, "New finds should have at least two decorative genes")
	var legend_rate := legendary / 9000.0
	var mushroom_rate := mushrooms / float(eligible)
	check(absf(legend_rate - 1.0 / 3.0) < 0.025, "Legendary chance must be approximately one third across depths")
	check(absf(mushroom_rate - 0.45) < 0.04, "Mushroom chance must be approximately 45% of suitable forms")
	check(rich_accents > legacy_accents * 1.5, "Decoration density must increase materially")
	check(BoardSprites.tex("gas").resource_path == "res://assets/board/pieces/gas.png", "Gas must resolve to the original sprite")
	var export_config := ConfigFile.new()
	export_config.load("res://export_presets.cfg")
	check(not export_config.get_value("preset.0.options", "shader_baker/enabled", true), "iOS export must disable the affected shader baker")
	print("REWARD RATES: legend=%.2f%% mushrooms=%.2f%% accents=%.2f (legacy %.2f)" % [legend_rate * 100, mushroom_rate * 100, rich_accents / 9000.0, legacy_accents / 9000.0])
	print("REWARD REGRESSIONS: ", "FAIL" if failed else "PASS")
	get_tree().quit(1 if failed else 0)
