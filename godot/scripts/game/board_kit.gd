class_name BoardKit
extends RefCounted
## The board's stone kit for one mine (rendered by prototype/tools/blender/board_kit.py into assets/board/kit/<rock>/):
## cell tiles, long frame bars and the caps on their joints. draw() builds any board shape out of them:
## a dark bed, a tile per cell, a bar along every outside edge, a cap on every corner, and their shadows.

# sizes in cells, as board_kit.py renders them (FW, CAP, MARGIN, BAR_N there)
const PX := 192.0
const MARGIN := 0.06
const FW := 0.34
const CAP := 0.46
# which rock each mine's board is cut from (Data.AREAS order); `-- rock=<name>` overrides it
const AREA_ROCK := ["basalt", "serpentine", "basalt"]
# the bed between the tiles, the rock's darkest tone (kit.json's "bed")
const BED := {basalt = Color("#101011"), granite = Color("#322924"), serpentine = Color("#353735")}

static var force_rock := ""
static var _kits := {}

var rock: String
var tiles: Array[Texture2D] = []
var bar_h: Texture2D
var bar_v: Texture2D
var cap: Texture2D

static func for_area(area: int) -> BoardKit:
	var r: String = force_rock if force_rock != "" else AREA_ROCK[clampi(area, 0, AREA_ROCK.size() - 1)]
	if not _kits.has(r):
		var k := BoardKit.new()
		k.rock = r
		var dir := "res://assets/board/kit/%s/" % r
		for i in 3:
			k.tiles.append(load(dir + "tile%d.png" % i))
		k.bar_h = load(dir + "bar_h.png")
		k.bar_v = load(dir + "bar_v.png")
		k.cap = load(dir + "cap.png")
		_kits[r] = k
	return _kits[r]

static func paths() -> Array:
	var out := []
	for r in BED:
		for f in ["tile0", "tile1", "tile2", "bar_h", "bar_v", "cap"]:
			out.append("res://assets/board/kit/%s/%s.png" % [r, f])
	return out

## the whole tray onto `ci`: cells `fill(r, c)` of an R x C grid, cell `ts` wide, grid origin at `o`
func draw(ci: CanvasItem, o: Vector2, ts: float, rows: int, cols: int, fill: Callable) -> void:
	var at := func(r: float, c: float) -> Vector2: return o + Vector2(c, r) * ts
	var full := func(r: int, c: int) -> bool: return r >= 0 and r < rows and c >= 0 and c < cols and fill.call(r, c)
	# the bars, as [rect on screen, texture, its region, +1/-1: the cells lie below/right of it or above/left],
	# and the caps' centres; then everything in order
	var bars := []
	var fw := FW * ts
	var m := MARGIN * PX
	# horizontal runs on every row line, vertical runs on every column line, each with its outside side
	for r in rows + 1:
		var c := 0
		while c < cols:
			var above: bool = full.call(r - 1, c)
			var below: bool = full.call(r, c)
			if above == below:
				c += 1
				continue
			var c0 := c
			while c < cols and full.call(r - 1, c) == above and full.call(r, c) == below:
				c += 1
			var y: float = (at.call(r, 0) as Vector2).y + (-fw if below else 0.0)
			var x0: float = (at.call(0, c0) as Vector2).x
			bars.append([Rect2(x0, y, (c - c0) * ts, fw), bar_h, Rect2(m + c0 * PX, m, (c - c0) * PX, FW * PX), 1.0 if below else -1.0])
	for c in cols + 1:
		var r := 0
		while r < rows:
			var left: bool = full.call(r, c - 1)
			var right: bool = full.call(r, c)
			if left == right:
				r += 1
				continue
			var r0 := r
			while r < rows and full.call(r, c - 1) == left and full.call(r, c) == right:
				r += 1
			var x: float = (at.call(0, c) as Vector2).x + (-fw if right else 0.0)
			var y0: float = (at.call(r0, 0) as Vector2).y
			bars.append([Rect2(x, y0, fw, (r - r0) * ts), bar_v, Rect2(m, m + r0 * PX, FW * PX, (r - r0) * PX), 1.0 if right else -1.0])
	var caps := []
	for r in rows + 1:
		for c in cols + 1:
			var q := [full.call(r - 1, c - 1), full.call(r - 1, c), full.call(r, c - 1), full.call(r, c)]
			var n := q.count(true)
			if n == 0 or n == 4 or (n == 2 and q[0] != q[3]):
				continue   # inside, outside, or the middle of a straight edge
			# the cap sits in the corner the bars share: towards the empty quarter(s)
			var off := Vector2.ZERO
			if n == 3:
				var e := q.find(false)
				off = Vector2(-1 if e % 2 == 0 else 1, -1 if e < 2 else 1)
			elif n == 1:
				var f := q.find(true)
				off = Vector2(1 if f % 2 == 0 else -1, 1 if f < 2 else -1)
			caps.append((at.call(r, c) as Vector2) + off * fw * 0.5)
	# the dark bed, a little wider than the cells so it runs under the bars' inner edge
	var bed: Color = BED.get(rock, Color(0.05, 0.05, 0.05))
	for r in rows:
		for c in cols:
			if full.call(r, c):
				ci.draw_rect(Rect2(at.call(r, c), Vector2(ts, ts)).grow(2.0), bed)
	# tiles, three cuts mixed so no two neighbours repeat in a row
	var tw := ts * (1.0 + MARGIN * 2.0)
	for r in rows:
		for c in cols:
			if full.call(r, c):
				var t: Texture2D = tiles[(r * 7 + c * 5) % 3]
				ci.draw_texture_rect(t, Rect2((at.call(r, c) as Vector2) + Vector2(ts, ts) * 0.5 - Vector2(tw, tw) * 0.5, Vector2(tw, tw)), false)
	# the frame stands above the tiles: its shadow falls inwards, darkest along the top and left
	for b in bars:
		_inner_shadow(ci, b[0], b[3], ts)
	# and onto the rock round the board, down and to the right
	var drop := Vector2(ts * 0.03, ts * 0.07)
	for b in bars:
		ci.draw_texture_rect_region(b[1], Rect2((b[0] as Rect2).position + drop, (b[0] as Rect2).size).grow(ts * 0.02), b[2], Color(0, 0, 0, 0.45))
	var cw := ts * (CAP + MARGIN * 2.0)
	for p in caps:
		ci.draw_texture_rect(cap, Rect2((p as Vector2) + drop - Vector2(cw, cw) * 0.5, Vector2(cw, cw)), false, Color(0, 0, 0, 0.45))
	for b in bars:
		ci.draw_texture_rect_region(b[1], b[0], b[2])
	for p in caps:
		ci.draw_texture_rect(cap, Rect2((p as Vector2) - Vector2(cw, cw) * 0.5, Vector2(cw, cw)), false)

## a soft band of shade on the cells along one bar, deeper where the light comes from (top-left)
func _inner_shadow(ci: CanvasItem, bar: Rect2, into: float, ts: float) -> void:
	var horiz := bar.size.x > bar.size.y
	var depth := ts * (0.16 if into > 0 else 0.07)
	var a := 0.55 if into > 0 else 0.3
	var p: PackedVector2Array
	if horiz:
		var y := bar.end.y if into > 0 else bar.position.y
		p = PackedVector2Array([Vector2(bar.position.x, y), Vector2(bar.end.x, y), Vector2(bar.end.x, y + depth * into), Vector2(bar.position.x, y + depth * into)])
	else:
		var x := bar.end.x if into > 0 else bar.position.x
		p = PackedVector2Array([Vector2(x, bar.position.y), Vector2(x, bar.end.y), Vector2(x + depth * into, bar.end.y), Vector2(x + depth * into, bar.position.y)])
	var k := Color(0, 0, 0, a)
	var z := Color(0, 0, 0, 0)
	ci.draw_polygon(p, PackedColorArray([k, k, z, z]))
