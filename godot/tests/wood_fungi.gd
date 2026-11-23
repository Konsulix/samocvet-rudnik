extends Node
## the petrified wood's honey fungus gene: how often each show has it (only driftwood grows the fungi)
## godot --headless --path godot res://tests/wood_fungi.tscn
func _ready() -> void:
	var n := {}
	var f := {}
	for s in range(1, 4001):
		var g := SpecWood.genes(s, [])
		var sh := String(g.show)
		n[sh] = int(n.get(sh, 0)) + 1
		if bool(g.fungi): f[sh] = int(f.get(sh, 0)) + 1
	for sh: String in n: print("%-10s %4d finds, with fungi %d" % [sh, n[sh], int(f.get(sh, 0))])
	get_tree().quit()
