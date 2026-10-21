extends SceneTree
func _init() -> void:
	var r := Rng32.new((1234 * 2246822519) % 4294967296)
	print("gd  %.10f %.10f %.10f" % [r.next(), r.next(), r.next()])
	quit()
