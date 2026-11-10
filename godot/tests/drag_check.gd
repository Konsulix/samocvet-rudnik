extends Node
## Drags a scroll list with the finger starting on one of its rows (a button) and checks that the list moved and no
## button fired. Run: "$G" --path godot --resolution 390x844 res://tests/drag_check.tscn -- screen=awards
## (any screen with a DragScroll: atlas, awards, stones…), `drag_at=X,Y` — where the finger goes down (points)

var _fired := []

func _ready() -> void:
	add_child(load("res://scenes/main.tscn").instantiate())
	await get_tree().create_timer(3.0).timeout
	var at := Vector2(195, 600)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("drag_at="): at = Vector2(float(a.get_slice("=", 1).get_slice(",", 0)), float(a.get_slice("=", 1).get_slice(",", 1)))
	var sc := _find(get_tree().root)
	if sc == null:
		print("DRAG no DragScroll on screen")
		get_tree().quit()
		return
	_hook(sc)
	var before := sc.scroll_vertical
	var hit := get_viewport().gui_get_hovered_control() if false else null
	_move(at)
	_press(at, true)
	for i in 12:
		await get_tree().process_frame
		_move(at + Vector2(0, -20.0 * (i + 1)))
	_press(at + Vector2(0, -240), false)
	await get_tree().create_timer(0.6).timeout
	print("DRAG list %s: scroll %d -> %d, buttons fired: %s, window open: %s" % [sc.get_path(), before, sc.scroll_vertical, _fired, Ov.is_open()])
	# then a plain tap on the same spot must still press what is there
	_fired.clear()
	_press(at, true)
	await get_tree().process_frame
	_press(at, false)
	await get_tree().create_timer(0.3).timeout
	print("TAP buttons fired: %s, window open: %s, sheets: %d" % [_fired, Ov.is_open(), _sheets()])
	if _sheets() > 0:
		_press(Vector2(195, 422), true)
		await get_tree().process_frame
		_press(Vector2(195, 422), false)
		await get_tree().create_timer(0.3).timeout
		print("TAP inside sheet -> sheets: %d" % _sheets())
		_press(Vector2(195, 800), true)
		await get_tree().process_frame
		_press(Vector2(195, 800), false)
		await get_tree().create_timer(0.3).timeout
		print("TAP outside sheet -> sheets: %d" % _sheets())
	get_tree().quit()

func _sheets() -> int:
	var n := 0
	for c in get_tree().root.find_children("*", "Control", true, false):
		if (c as Control).z_index == 5 and not c.is_queued_for_deletion() and c.get_parent().name != "": n += 1
	return n

func _find(n: Node) -> DragScroll:
	if n is DragScroll and (n as DragScroll).is_visible_in_tree() and (n as DragScroll).vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		return n
	for c in n.get_children():
		var f := _find(c)
		if f: return f
	return null

func _hook(n: Node) -> void:
	if n is BaseButton:
		var b := n as BaseButton
		b.pressed.connect(func(): _fired.append(b.name))
	for c in n.get_children(): _hook(c)

func _press(p: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = p
	e.global_position = p
	Input.parse_input_event(e)

func _move(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)
