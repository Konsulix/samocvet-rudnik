extends Node
## a legendary find's price as the player goes on (Stones.price: its effect's share in the furthest mine's coin):
## a legendary and a plain find of Old Adit, priced with the furthest mine 0..4; then the same through Save.open_mine
## godot --headless --path godot res://tests/legend_price.tscn -- save=legtest
func _ready() -> void:
	await get_tree().process_frame
	var leg := {}
	var plain := {}
	for sd in range(60000, 90000):
		var st := Stones.roll(sd, 0, 1.0, 2)
		if leg.is_empty() and bool(st.get("legend", false)): leg = st
		if plain.is_empty() and not bool(st.get("legend", false)) and st.sid == "amethyst": plain = st
		if leg.size() and plain.size(): break
	for st: Dictionary in [leg, plain]:
		var row := []
		for r in 5: row.append(Stones.price(st, 0, 2, r))
		print("PRICE %s legend=%s fx=%s: %s" % [st.sid, st.get("legend", false), st.get("fx", ""), row])
	# through the game: kept, then each next mine opened
	leg.area = 0
	leg.dl = 2
	leg.value = Stones.price(leg, 0, 2, 0)
	Save.d.coll = [leg]
	Save.d.area = 0
	Save.d.reached = 0
	var drill := []
	for a in range(1, 5):
		Save.open_mine(a)
		print("OPEN mine %d: value %d, gain %s" % [a, int(leg.value), Save.legend_gain])
		Save.legend_gain = [0, 0]
	Save.open_mine(0)
	print("BACK to mine 0: value %d, gain %s" % [int(leg.value), Save.legend_gain])
	# the toast: shown a moment after
	Save.legend_gain = [2, 15000]
	Stones.tell_legends(self)
	await get_tree().create_timer(3.0).timeout
	print("TOAST ok")
	get_tree().quit()
