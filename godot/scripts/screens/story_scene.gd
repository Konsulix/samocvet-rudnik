class_name StoryScene
extends Control
## A story moment (docs/story.md, docs/onboarding.md "портрет"): the screen goes dark, big portraits of who speaks
## (faceted, art/story → assets/story via export_story.py) stand up from the bottom, one or two facing each other; the
## line is typed on a slate card under them, a tap shows it all, the next tap goes on. Rare: a few lines, then it fades.

signal finished

const DIR := "res://assets/story/"
## who can speak: their name on the plate, which way their pictures face
const CAST := {
	guide = {n = "Old Miner", faces = "left"},
	sister = {n = "The Scholar", faces = "right"},
	rival = {n = "The Apprentice", faces = "right"},
	# someone not yet seen: no picture, his lantern swinging over the dark (the prologue)
	voice = {n = "???", faces = "none"},
}
## the scenes: [who, mood, line]; a mood without a picture falls back to calm
const SCENES := {
	prologue_voice = [
		["voice", "", "Hey! Anyone alive down there?"],
		["voice", "", "Hold on - the rock's loose. Dig upward, towards my light!"],
	],
	prologue_meet = [
		["guide", "surprise", "Well I'll be. Alive! I thought this mountain didn't give anyone back any more."],
		["guide", "sad", "Third cave-in this year. The old adit's dying - nobody's worked her for a long time."],
		["guide", "point", "But there's gold in her yet. Stay a while, help an old man, and we'll wake her up."],
		["guide", "point", "Here - take this. Gold, out of these very walls. It's yours."],
	],
	# the gift was pyrite (Home._rise, Reveal.reply): he laughs at the newcomer's thanks
	fools_gold = [
		["guide", "laugh", "Ha-ha-ha! Me, give away gold? That's fool's gold, lad - pyrite!"],
		["guide", "calm", "Took me in too, forty years back. The real thing lies deeper. Let's go and find it."],
	],
	poloz_before = [
		["guide", "worry", "Hear that? Under the last level. That's no rockfall - that's him breathing."],
		["guide", "calm", "The Great Serpent. Gold in his scales, and a stone in his heart that was never his."],
		["guide", "point", "Knock that stone out of him and he'll sleep. Mind his coils - they crush."],
	],
	poloz_after = [
		["guide", "laugh", "He's asleep! Curled up in his vein like a cat by the stove."],
		["sister", "worry", "Excuse me. You're the one who went down to the Serpent?"],
		["sister", "calm", "I'm looking for my brother. He worked this adit. They all say he died in the collapse."],
		["guide", "sad", "...He did. I dug for him three days."],
		["sister", "resolve", "Then who took the stone the Serpent spat out? There are fresh boot prints in its lair."],
		["guide", "surprise", "Lord help us. The lad's alive."],
	],
}

## test runs (-- story_auto): the lines go on by themselves, for screenshots
static var auto := false
var lines: Array = []
var lamp_at := Vector2(-1, -1)   # where the unseen speaker's lantern hangs from (screen), if the caller has one
var _i := -1
var _shade: ColorRect
var _figs := {}           # who -> TextureRect
var _card: PanelContainer
var _name: Label
var _text: Label
var _typing: Tween
var _done := false

## plays a scene over everything; await the returned scene's `finished`
static func play(at: Node, id: String, lamp := Vector2(-1, -1)) -> StoryScene:
	var layer := CanvasLayer.new()
	layer.layer = 25   # over the windows (Ov, 20): a story line may come over a find's card
	at.get_tree().root.add_child(layer)
	var s := StoryScene.new()
	s.lines = SCENES.get(id, [])
	s.lamp_at = lamp
	layer.add_child(s)
	s.finished.connect(layer.queue_free)
	return s

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vp := get_viewport_rect().size
	# sized by hand: under a CanvasLayer the full-rect anchors left it 0×0, and a tap fell through to the board
	size = vp
	_shade = ColorRect.new()
	_shade.color = Color(0.02, 0.02, 0.03, 0.0)
	_shade.size = vp
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	create_tween().tween_property(_shade, "color:a", 0.8, 0.4)
	# the portraits, each on the side it faces from: one facing right stands on the left
	var whos := []
	for l in lines:
		if not whos.has(l[0]): whos.append(l[0])
	for who in whos:
		if CAST[who].faces == "none":
			# the unseen speaker: his lantern hangs into the dark from above
			var lamp := KitLantern.new(96.0)
			lamp.position = lamp_at if lamp_at.x >= 0.0 else Vector2(vp.x / 2, vp.y * 0.2)
			add_child(lamp)
			continue
		var fig := TextureRect.new()
		fig.texture = _pic(String(who), "calm")
		fig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fig.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		fig.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h := vp.y * 0.6
		var w := h * fig.texture.get_width() / fig.texture.get_height()
		fig.size = Vector2(w, h)
		var left: bool = CAST[who].faces == "right"
		# a lone speaker stands nearer the middle
		var inset := -0.12 * w if whos.size() > 1 else vp.x * 0.5 - w * 0.62
		fig.position = Vector2(inset if left else vp.x - w - inset, vp.y - h - _card_h() + 40.0)
		fig.pivot_offset = Vector2(w / 2, h)
		fig.modulate.a = 0.0
		fig.set_meta("home", fig.position)
		fig.set_meta("left", left)
		add_child(fig)
		_figs[who] = fig
	_build_card(vp)
	_next()

func _card_h() -> float:
	return 150.0 + UI.safe_bottom()

func _build_card(vp: Vector2) -> void:
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := Kit.box("card", 0.0)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 26
	sb.content_margin_bottom = 16
	_card.add_theme_stylebox_override("panel", sb)
	_card.position = Vector2(12, vp.y - _card_h() - 8.0)
	_card.size = Vector2(vp.x - 24, 150.0)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text = Kit.label("", 18, UI.body_bold)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(vp.x - 24 - 40, 0)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_text)
	var more := Kit.label("Tap to continue", 12, UI.body_bold, Kit.DIM)
	more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(more)
	_card.add_child(v)
	add_child(_card)
	# who speaks: a brass plate on the card's top edge, on the speaker's side
	var plate := PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ps := Kit.box("title", 0.0)
	ps.content_margin_left = 20
	ps.content_margin_right = 20
	ps.content_margin_top = 4
	ps.content_margin_bottom = 5
	plate.add_theme_stylebox_override("panel", ps)
	_name = Kit.label("", 16, UI.display, Kit.AMBER)
	plate.add_child(_name)
	add_child(plate)
	plate.set_meta("is_plate", true)
	_card.set_meta("plate", plate)

func _pic(who: String, mood: String) -> Texture2D:
	var p := DIR + "%s_%s.png" % [who, mood]
	if not ResourceLoader.exists(p): p = DIR + "%s_calm.png" % who
	return Kit.tex_at(p)

## the next line: its speaker steps up and lights, the other dims back; the words type out
func _next() -> void:
	_i += 1
	if _i >= lines.size():
		_end()
		return
	var l: Array = lines[_i]
	var who := String(l[0])
	for w in _figs:
		var fig: TextureRect = _figs[w]
		if fig == null: continue
		var on: bool = w == who
		if on: fig.texture = _pic(who, String(l[1]))
		var home: Vector2 = fig.get_meta("home")
		var first: bool = fig.modulate.a < 0.05 and on
		if first:
			# steps in from his side
			fig.position = home + Vector2(-60 if bool(fig.get_meta("left")) else 60, 0)
		if on or fig.modulate.a > 0.05:
			var tw := create_tween().set_parallel()
			tw.tween_property(fig, "position", home + (Vector2.ZERO if on else Vector2(0, 14)), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(fig, "modulate", Color.WHITE if on else Color(0.42, 0.42, 0.48, 1), 0.3)
			tw.tween_property(fig, "scale", Vector2.ONE if on else Vector2(0.95, 0.95), 0.3)
	# the speaker in front
	if _figs.has(who): move_child(_figs[who], _card.get_index() - 1)
	_name.text = String(CAST[who].n)
	var plate: Control = _card.get_meta("plate")
	var left: bool = CAST[who].faces == "right"
	(func():
		plate.position = Vector2(_card.position.x + (22.0 if left else _card.size.x - plate.size.x - 22.0), _card.position.y - plate.size.y * 0.5)
	).call_deferred()
	_text.text = String(l[2])
	_text.visible_ratio = 0.0
	if _typing: _typing.kill()
	_typing = create_tween()
	_typing.tween_property(_text, "visible_ratio", 1.0, clampf(_text.text.length() / 40.0, 0.5, 3.0))
	if auto:
		var at := _i
		get_tree().create_timer(1.6).timeout.connect(func(): if _i == at and not _done: _next())

func _gui_input(e: InputEvent) -> void:
	var pressed: bool = (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)
	if not pressed or _done: return
	accept_event()
	if _text.visible_ratio < 1.0:
		if _typing: _typing.kill()
		_text.visible_ratio = 1.0
		return
	_next()

func _process(_dt: float) -> void:
	# the one speaking breathes
	if _i < 0 or _i >= lines.size(): return
	var fig: TextureRect = _figs.get(String(lines[_i][0]))
	if fig: fig.scale.y = 1.0 + 0.006 * sin(Time.get_ticks_msec() / 1000.0 * 2.2)

func _end() -> void:
	_done = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func(): finished.emit())
