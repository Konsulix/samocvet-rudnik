class_name Rng32
extends RefCounted
## Mulberry32, bit for bit the same as the prototype's `mulberry()`,
## so a seed gives the same specimen in the browser and in the game.

const M := 0xFFFFFFFF
var a: int

func _init(seed_value: int) -> void:
	a = seed_value & M

static func imul(x: int, y: int) -> int:
	return (x * y) & M

func next() -> float:
	a = (a + 0x6D2B79F5) & M
	var t := imul(a ^ (a >> 15), 1 | a)
	t = ((t + imul(t ^ (t >> 7), 61 | t)) & M) ^ t
	return float((t ^ (t >> 14)) & M) / 4294967296.0

## integer in [lo, hi]
func range_i(lo: int, hi: int) -> int:
	return lo + int(floor(next() * (hi - lo + 1)))

func range_f(lo: float, hi: float) -> float:
	return lo + next() * (hi - lo)
