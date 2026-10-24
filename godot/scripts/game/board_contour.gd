extends RefCounted
## Closed grid boundaries, with playable cells on the right of every edge.
## Includes holes and disconnected islands; diagonal contacts remain separate.

static func trace(mask: Array) -> Array:
	var edges := {}
	for r in mask.size():
		for c in mask[r].size():
			if not mask[r][c]: continue
			if not _filled(mask, r - 1, c): _edge(edges, Vector2i(c, r), Vector2i(c + 1, r))
			if not _filled(mask, r, c + 1): _edge(edges, Vector2i(c + 1, r), Vector2i(c + 1, r + 1))
			if not _filled(mask, r + 1, c): _edge(edges, Vector2i(c + 1, r + 1), Vector2i(c, r + 1))
			if not _filled(mask, r, c - 1): _edge(edges, Vector2i(c, r + 1), Vector2i(c, r))
	var loops := []
	while not edges.is_empty():
		var start: Vector2i = edges.keys()[0]
		var at := start
		var incoming := Vector2i.ZERO
		var raw := PackedVector2Array()
		while true:
			raw.append(Vector2(at))
			var options: Array = edges[at]
			var selected := 0
			if incoming != Vector2i.ZERO:
				var best := 5
				for i in options.size():
					var direction: Vector2i = options[i] - at
					var turn := incoming.x * direction.y - incoming.y * direction.x
					var rank := 0 if turn > 0 else (1 if direction == incoming else (2 if turn < 0 else 3))
					if rank < best:
						best = rank
						selected = i
			var next: Vector2i = options[selected]
			options.remove_at(selected)
			if options.is_empty(): edges.erase(at)
			incoming = next - at
			at = next
			if at == start: break
		# One textured stone strip per straight run, rather than per cell.
		var corners := PackedVector2Array()
		for i in raw.size():
			var before := raw[i] - raw[(i + raw.size() - 1) % raw.size()]
			var after := raw[(i + 1) % raw.size()] - raw[i]
			if not is_zero_approx(before.cross(after)): corners.append(raw[i])
		loops.append(corners)
	return loops

static func _filled(mask: Array, r: int, c: int) -> bool:
	return r >= 0 and r < mask.size() and c >= 0 and c < mask[r].size() and bool(mask[r][c])

static func _edge(edges: Dictionary, from: Vector2i, to: Vector2i) -> void:
	if not edges.has(from): edges[from] = []
	edges[from].append(to)
