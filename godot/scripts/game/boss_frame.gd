class_name BossFrame
extends Node2D
## The boss' body round the board (Poloz: a stone serpent), built from a kit like the board's own stone frame
## (BoardKit): straight runs cut to length along every outside edge, a corner piece on every turn, outer or inner,
## quartz on the board's extreme corners and the swaying tail over the bottom-right one. The pieces are rendered by
## prototype/tools/blender/serpent_kit.py (kit) and brought to the 1-pt grid by art/boss/export.py.

const TURNS := ["tl", "tr", "bl", "br"]

var kit := {}                # piece name -> texture
var tails: Array[Texture2D] = []
var meta: Dictionary
var swaying := true
var fill: Callable           # (r, c) -> is the cell part of the board
var rows := 9                # the board's size (LevelBoss sets it from the model)
var cols := 8
var origin := Vector2.ZERO   # the grid's top-left corner
var ts := 42.0
var dir := ""
## the boss' own boards come with a whole frame each (no seams): set by use_stage, empty for any other board
var whole: Texture2D
var whole_tails: Array[Texture2D] = []
var whole_meta := {}
var _t := 0.0

static func load_for(id: String) -> BossFrame:
	var f := BossFrame.new()
	var dir := "res://assets/boss/%s/kit/" % id
	f.dir = dir
	f.meta = JSON.parse_string(FileAccess.get_file_as_string(dir + "kit.json"))
	# a boss whose boards all have a whole frame each (the Mistress) has no pieces
	if bool(f.meta.get("pieces", true)):
		var names := ["straight_h", "straight_v", "outer_tl_x", "outer_bl_x", "outer_tr_x"]
		for kind in ["outer", "inner"]:
			for t in TURNS: names.append("%s_%s" % [kind, t])
		for n: String in names:
			f.kit[n] = load(dir + n + ".png")
	for i in int(f.meta.tail_frames):
		f.tails.append(load(dir + "tail_%d.png" % i))
	f.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# on iPhone with baked shaders the stock shader can draw nothing: the stones' own one
	f.material = BoardSprites.plain_material()
	return f

## board `i` of the fight: its whole frame if one was baked, else the kit builds it
func use_stage(i: int) -> void:
	whole = null
	whole_tails.clear()
	var js := dir + "stage%d.json" % i
	if not FileAccess.file_exists(js): return
	whole_meta = JSON.parse_string(FileAccess.get_file_as_string(js))
	whole = load(dir + "stage%d.png" % i)
	for f in int(whole_meta.tail_frames):
		whole_tails.append(load(dir + "stage%d_tail%d.png" % [i, f]))
	queue_redraw()

## the board's shape and where its grid lies (in the parent's coordinates), cell size ts
func fit(shape: Callable, grid_origin: Vector2, cell: float) -> void:
	fill = shape
	origin = grid_origin
	ts = cell
	queue_redraw()

## the line the top run's body runs along (the health bar lies on it)
func top_line() -> float:
	return origin.y - ts * float(meta.offset)

func _full(r: int, c: int) -> bool:
	return r >= 0 and c >= 0 and r < rows and c < cols and bool(fill.call(r, c))

func _pt(r: float, c: float) -> Vector2:
	return origin + Vector2(c, r) * ts

## what kind of corner a grid point is: "" none, "outer_tl" etc. (two names for a diagonal pair)
func _corner(r: int, c: int) -> Array:
	var tl := _full(r - 1, c - 1)
	var tr := _full(r - 1, c)
	var bl := _full(r, c - 1)
	var br := _full(r, c)
	var n := int(tl) + int(tr) + int(bl) + int(br)
	if n == 1:
		return ["outer_tl" if br else "outer_tr" if bl else "outer_bl" if tr else "outer_br"]
	if n == 3:
		return ["inner_tl" if not tl else "inner_tr" if not tr else "inner_bl" if not bl else "inner_br"]
	if n == 2 and tl == br:
		return ["outer_tl", "outer_br"] if tl else ["outer_tr", "outer_bl"]
	return []

func _process(dt: float) -> void:
	if not swaying or fill.is_null() or (tails.is_empty() and whole_tails.is_empty()): return
	var was := int(_t * 8.0)
	_t += dt
	if int(_t * 8.0) != was: queue_redraw()

func _draw() -> void:
	if fill.is_null(): return
	if whole:
		var kw := ts / float(whole_meta.cell_pt)
		var o := (origin - Vector2(whole_meta.cells_top_left[0], whole_meta.cells_top_left[1]) * kw).round()
		var sz := Vector2(whole.get_size()) * kw
		draw_texture_rect(whole, Rect2(o, sz), false)
		if whole_tails.is_empty(): return
		var tt: Texture2D = whole_tails[int(_t * 8.0) % whole_tails.size()] if swaying else whole_tails[0]
		draw_texture_rect(tt, Rect2(o, sz), false)
		return
	if kit.is_empty(): return
	var k := ts / float(meta.cell_pt)
	var off := float(meta.offset) * ts
	var cpt := float(meta.cell_pt)
	var inner_at := func(r: int, c: int) -> bool:
		var cn := _corner(r, c)
		return not cn.is_empty() and String(cn[0]).begins_with("inner")
	# straight runs: along each row line, then each column line, with the side the board is on
	var sh: Texture2D = kit.straight_h
	var sv: Texture2D = kit.straight_v
	for r in rows + 1:
		var c := 0
		while c < cols:
			var above := _full(r - 1, c)
			var below := _full(r, c)
			if above == below:
				c += 1
				continue
			var c0 := c
			while c < cols and _full(r - 1, c) == above and _full(r, c) == below:
				c += 1
			var y := _pt(r, 0).y + (-off if below else off)
			var x0 := _pt(0, c0).x + (off if inner_at.call(r, c0) else 0.0)
			var x1 := _pt(0, c).x - (off if inner_at.call(r, c) else 0.0)
			# a different stretch of the long piece for each run, so runs don't repeat each other
			var src := Rect2(minf(float((c0 * 3 + r * 5) % 3), float(meta.straight) - (x1 - x0) / ts) * cpt, 0, (x1 - x0) / k, cpt)
			draw_texture_rect_region(sh, Rect2(Vector2(x0, y - ts * 0.5).round(), Vector2(x1 - x0, ts).round()), src)
	for c in cols + 1:
		var r := 0
		while r < rows:
			var left := _full(r, c - 1)
			var right := _full(r, c)
			if left == right:
				r += 1
				continue
			var r0 := r
			while r < rows and _full(r, c - 1) == left and _full(r, c) == right:
				r += 1
			var x := _pt(0, c).x + (-off if right else off)
			var y0 := _pt(r0, 0).y + (off if inner_at.call(r0, c) else 0.0)
			var y1 := _pt(r, 0).y - (off if inner_at.call(r, c) else 0.0)
			var src := Rect2(0, minf(float((r0 * 3 + c * 5) % 3), float(meta.straight) - (y1 - y0) / ts) * cpt, cpt, (y1 - y0) / k)
			draw_texture_rect_region(sv, Rect2(Vector2(x - ts * 0.5, y0).round(), Vector2(ts, y1 - y0).round()), src)
	# corners on top: inner first, then outer; quartz on the extreme ones, the tail on the lowest right one
	var outers := []
	var inners := []
	for r in rows + 1:
		for c in cols + 1:
			for n: String in _corner(r, c):
				(inners if n.begins_with("inner") else outers).append([n, r, c])
	var best := {}
	for o: Array in outers:
		var score: int = {outer_tl = -(o[1] + o[2]), outer_bl = o[1] - o[2], outer_tr = o[2] - o[1], outer_br = o[1] + o[2]}[o[0]]
		if not best.has(o[0]) or score > int(best[o[0]][0]):
			best[o[0]] = [score, o[1], o[2]]
	var half := float(meta.canvas) * 0.5 * ts
	for list in [inners, outers]:
		for o: Array in list:
			var n: String = o[0]
			if best.has(n) and int(best[n][1]) == int(o[1]) and int(best[n][2]) == int(o[2]) and kit.has(n + "_x"):
				n += "_x"
			var p := _pt(o[1], o[2])
			draw_texture_rect(kit[n], Rect2((p - Vector2(half, half)).round(), Vector2(half, half) * 2.0), false)
	if best.has("outer_br"):
		var p := _pt(best.outer_br[1], best.outer_br[2])
		var tex: Texture2D = tails[int(_t * 8.0) % tails.size()] if swaying else tails[0]
		draw_texture_rect(tex, Rect2((p - Vector2(half, half)).round(), Vector2(half, half) * 2.0), false)
