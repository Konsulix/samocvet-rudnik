class_name SpecTex
extends RefCounted
## Small procedural textures for the specimens.

static var _wisps := {}

## soft smoky veils for the inside of clear crystals (a few variants, cached)
static func wisp(seed_v: int) -> ImageTexture:
	var key := seed_v % 6
	if _wisps.has(key):
		return _wisps[key]
	var rng := Rng32.new(seed_v)
	var S := 96
	var acc := PackedFloat32Array()
	acc.resize(S * S)
	for k in 70:
		var px := (40.0 + rng.next() * 176.0) / 256.0 * S
		var py := (30.0 + rng.next() * 196.0) / 256.0 * S
		var r := (10.0 + rng.next() * 40.0) / 256.0 * S
		var a := 0.12 + rng.next() * 0.25
		for y in range(maxi(0, int(py - r)), mini(S, int(py + r) + 1)):
			for x in range(maxi(0, int(px - r)), mini(S, int(px + r) + 1)):
				var d := Vector2(x - px, y - py).length() / r
				if d < 1.0:
					var i := y * S + x
					acc[i] = acc[i] + (1.0 - acc[i]) * a * (1.0 - d)
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			var e := clampf(1.0 - (Vector2(x - S / 2.0, y - S / 2.0).length() - S * 0.234) / (S * 0.266), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, acc[y * S + x] * e))
	var t := ImageTexture.create_from_image(img)
	_wisps[key] = t
	return t
