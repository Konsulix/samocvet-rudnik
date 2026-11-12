extends Node
## Memory over repeated card opens: the stones screen with a full collection, a stone's card opened and closed N times;
## prints video memory, textures, buffers and objects after each. A leak shows as numbers that keep climbing.
## Run: "$G" --path godot --resolution 390x844 res://tests/mem_check.tscn -- save=memtest screen=stones fill=60 opens=12

func _ready() -> void:
	add_child(load("res://scenes/main.tscn").instantiate())
	var n := 10
	for a in OS.get_cmdline_user_args():
		if a.begins_with("opens="): n = int(a.get_slice("=", 1))
	await get_tree().create_timer(4.0).timeout
	_print("start")
	var m := get_tree().root.find_children("*", "Museum", true, false)
	if m.is_empty():
		print("MEM no Museum")
		get_tree().quit()
		return
	var mu: Node = m[0]
	var coll: Array = Save.d.coll
	for i in n:
		mu.call("_open_stone", coll[i % coll.size()])
		await get_tree().create_timer(2.5).timeout
		Ov.close()
		await get_tree().create_timer(0.8).timeout
		_print("after %d" % (i + 1))
	get_tree().quit()

func _print(tag: String) -> void:
	var mb := func(v: float) -> int: return roundi(v / 1048576.0)
	print("MEM %-9s vram %4d  tex %4d  buf %4d  objects %6d  nodes %5d  viewports %d" % [tag,
		mb.call(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		mb.call(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		mb.call(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)),
		Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		get_tree().root.find_children("*", "SubViewport", true, false).size()])
