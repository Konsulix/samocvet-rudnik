extends Node
## The scholar's word comes as the card of the find completing an award closes (Awards.say_after_find), not at its claim.
##   "$G" --path godot --resolution 390x844 res://tests/say_find.tscn -- save=qa_say [shot=user://say.png]
## Rolls Old Adit stones until a hopper fluorite (Matryoshka), opens its card, presses Keep, times the sister's line.

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	Save.tell("s_sister_meet")
	print("QA before: matryoshka ready=%s told=%s" % [str("Matryoshka" in Awards.said_ready()), str(Save.told("say:Matryoshka"))])
	var st := {}
	for sd in range(1, 40000):
		var s := Stones.roll(sd, 0, 0.8, 1)
		if s.sid != "fluorite": continue
		if "hopper:fluorite" in Awards.genes_of(s):
			st = s
			break
	if st.is_empty():
		print("QA no hopper fluorite found")
		get_tree().quit()
		return
	print("QA hopper fluorite id=%s" % str(st.id))
	var rv := Reveal.new()
	rv.show_stone(st)
	await get_tree().create_timer(4.0).timeout
	var btn := _button(get_tree().root, "Keep")
	var t0 := Time.get_ticks_msec()
	btn.pressed.emit()
	var seen := -1
	while Time.get_ticks_msec() - t0 < 4000:
		await get_tree().process_frame
		if seen < 0 and _story(get_tree().root):
			seen = Time.get_ticks_msec() - t0
	print("QA sister after Keep: %d ms (−1: never)" % seen)
	if args.has("shot"): get_viewport().get_texture().get_image().save_png(String(args.shot))
	print("QA after: told=%s" % str(Save.told("say:Matryoshka")))
	get_tree().quit()

func _story(n: Node) -> bool:
	if n is StoryScene: return true
	for c in n.get_children():
		if _story(c): return true
	return false

func _button(n: Node, txt: String) -> Button:
	if n is Button and txt in (n as Button).text: return n
	for c in n.get_children():
		var b := _button(c, txt)
		if b: return b
	return null
