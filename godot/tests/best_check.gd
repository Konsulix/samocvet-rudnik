extends Node
## the atlas record goes by present price (Save.mend_best): a record set at finding and since passed by another kept
## stone of the species moves to it. godot --headless --path godot res://tests/best_check.tscn -- save=best_check
func _ready() -> void:
	var a := {id = 101, sid = "celestine", kind = "crystal", value = 1220, g = 952, traits = []}
	var b := {id = 102, sid = "celestine", kind = "crystal", value = 1712, g = 4030, traits = []}
	Save.d.coll = [a, b]
	var aid := Stones.atlas_id(a)
	Save.d.atlas[aid] = {n = 2, max_g = 4030, max_v = 1500, legend = false, best = {id = 101, sid = "celestine", value = 1500}}
	print("before: record is ", Save.d.atlas[aid].best.id, " at ", Save.d.atlas[aid].best.value)
	print("is_record 101: ", Reveal.is_record(a), "  102: ", Reveal.is_record(b))
	print("after: record is ", Save.d.atlas[aid].best.id, " at ", Save.d.atlas[aid].best.value)
	# a sold record (not kept) stays while no kept one passes it
	Save.d.coll = [a]
	Save.d.atlas[aid].best = {id = 999, sid = "celestine", value = 2000}
	Save.mend_best(aid)
	print("sold 2000 vs kept 1220: record is ", Save.d.atlas[aid].best.id)
	get_tree().quit()
