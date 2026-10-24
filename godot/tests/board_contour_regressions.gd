extends Node
## Check outline topology and that every segment separates playable/void cells.
const OUTLINE := preload("res://scripts/game/board_contour.gd")
var failed := false

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func filled(mask: Array, p: Vector2) -> bool:
	var r := int(floor(p.y))
	var c := int(floor(p.x))
	return r >= 0 and r < mask.size() and c >= 0 and c < mask[r].size() and bool(mask[r][c])

func validate(mask: Array, label: String, expected_loops := -1) -> void:
	var cells := 0
	var expected_length := 0
	for r in mask.size():
		for c in mask[r].size():
			if not mask[r][c]: continue
			cells += 1
			for d in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
				if not filled(mask, Vector2(c + 0.5, r + 0.5) + d): expected_length += 1
	var loops: Array = OUTLINE.trace(mask)
	if expected_loops >= 0: check(loops.size() == expected_loops, label + ": wrong number of contours")
	var area := 0.0
	var length := 0.0
	for loop: PackedVector2Array in loops:
		check(loop.size() >= 4, label + ": invalid contour")
		for i in loop.size():
			var a := loop[i]
			var b := loop[(i + 1) % loop.size()]
			area += a.cross(b) * 0.5
			var direction := (b - a).normalized()
			var segment_length := a.distance_to(b)
			length += segment_length
			check(is_zero_approx(direction.x) != is_zero_approx(direction.y), label + ": edge must follow the cell grid")
			var inside := Vector2(-direction.y, direction.x)
			for k in roundi(segment_length):
				var midpoint := a + direction * (k + 0.5)
				check(filled(mask, midpoint + inside * 0.1), label + ": inner edge must touch a playable cell")
				check(not filled(mask, midpoint - inside * 0.1), label + ": no frame between adjacent playable cells")
	check(is_equal_approx(area, cells), label + ": outline must cover exactly the playable area, excluding holes")
	check(is_equal_approx(length, expected_length), label + ": missing or duplicate boundary edges")

func _ready() -> void:
	validate([[1, 1, 1], [1, 1, 1]], "Rectangle", 1)
	validate([[1, 0], [1, 1]], "Inside corner", 1)
	validate([[1, 1, 1], [1, 0, 1], [1, 1, 1]], "Hole", 2)
	validate([[1, 0], [0, 1]], "Diagonal islands", 2)
	validate([[0, 0], [0, 0]], "Empty", 0)
	for n in range(1, 31):
		var model := BoardModel.new()
		model.setup(n, [], 0, {}, 0, false)
		var mask := []
		for r in BoardModel.R:
			var row := []
			for c in BoardModel.C: row.append(model.playable(r, c))
			mask.append(row)
		validate(mask, "Level %d" % n)
	print("BOARD CONTOUR REGRESSIONS: ", "FAILED" if failed else "PASS")
	get_tree().quit(1 if failed else 0)
