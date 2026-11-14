extends Node
## QA of what a close of the game must not lose (Save.owe/paid, d.in_level, the side-file save). Modes:
##   "$G" --headless --path godot res://tests/close_safety.tscn -- save=qa_x mode=state   — prints what the save loaded
##   ... mode=owed   — stones owed through a JSON round trip (as after a restart) are paid by Keep and by Sell
## The file cases (torn save, side file, deleted save) and the restarts are driven from the shell (see the session)

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	match String(args.get("mode", "state")):
		"state":
			print("QA state coins=%d lives=%d streak=%d in_level=%s owed=%d hoard_due=%d coll=%d" % [Save.d.coins, Save.d.lives,
				Save.d.streak, str(Save.d.in_level), (Save.d.owed as Array).size(), int(Save.d.hoard_due), (Save.d.coll as Array).size()])
		"owed":
			await _owed()
	get_tree().quit()

func _owed() -> void:
	Save.d.owed = []
	Save.d.coll = []
	var a := Stones.roll(Save.next_uid(), 0, 0.8, 1)
	var b := Stones.roll(Save.next_uid(), 0, 0.8, 1)
	Save.owe(a)
	Save.owe(b)
	Save.owe(a)   # (twice: owed once)
	Save.persist()
	print("QA owed after owe: %d (want 2)" % (Save.d.owed as Array).size())
	# a restart's JSON: whole numbers come back as floats
	Save.d.owed = JSON.parse_string(JSON.stringify(Save.d.owed))
	var coins0 := int(Save.d.coins)
	for k in 2:
		var st: Dictionary = (Save.d.owed as Array)[0]
		var rv := Reveal.new()
		rv.show_stone(st)
		await get_tree().process_frame
		await get_tree().process_frame
		var want := "Keep" if k == 0 else "Sell"
		var btn := _button(get_tree().root, want)
		if btn == null:
			print("QA FAIL no %s button" % want)
			return
		btn.pressed.emit()
		await get_tree().process_frame
		print("QA after %s: owed=%d coll=%d coins+%d" % [want, (Save.d.owed as Array).size(), (Save.d.coll as Array).size(), int(Save.d.coins) - coins0])
	var ok := (Save.d.owed as Array).is_empty() and (Save.d.coll as Array).size() == 1 and int(Save.d.coins) > coins0
	print("QA owed %s" % ("OK" if ok else "FAIL"))

func _button(n: Node, starts: String) -> Button:
	if n is Button and (n as Button).text.begins_with(starts) and (n as Button).is_visible_in_tree(): return n
	for c in n.get_children():
		var b := _button(c, starts)
		if b: return b
	return null
