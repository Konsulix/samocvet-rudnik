class_name TitleStrip
extends Control
## a card's name on one line in the room it has (up to the ✕): a name too long for it fades out softly at its right
## end and slides along under a finger to read the rest (and its left end fades once slid). On opening, a long name
## glides to its end and back once, to show it goes on. (TitleStrip.wrap puts a label in one; fit sets the room.)

const FADE := 34.0
const SHADER := "shader_type canvas_item;
// the strip's fade: the label's own x (VERTEX) less the slide is where it is in the strip
uniform float w = 10000.0;
uniform float off = 0.0;
uniform float fade_r = 0.0;
uniform float fade_l = 0.0;
uniform float fade = 34.0;
varying float x;
void vertex() { x = VERTEX.x; }
void fragment() {
	float sx = x - off;
	float a = mix(1.0, smoothstep(w, w - fade, sx), fade_r) * mix(1.0, smoothstep(0.0, fade * 0.7, sx), fade_l);
	COLOR.a *= a;
}
"
static var _shader: Shader

var label: Label
var off := 0.0
var room := 0.0
var _demo: Tween

## the label, now inside a strip (put the strip where the label was)
static func wrap(l: Label) -> TitleStrip:
	var t := TitleStrip.new()
	t.label = l
	t.clip_contents = true
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	t.add_child(l)
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	l.material = m
	return t

## the room for the name (pt); its strip's height follows the label
static func fit(l: Label, w: float) -> void:
	if not is_instance_valid(l) or w < 40.0: return
	l.set_meta("fit_w", w)
	var t := l.get_parent() as TitleStrip
	if t == null: return
	t.room = w
	var ms := l.get_combined_minimum_size()
	l.size = ms
	t.custom_minimum_size = Vector2(minf(ms.x, w), ms.y + 4.0)
	t._slide(clampf(t.off, 0.0, t._most()))
	if t._most() > 0.0 and t._demo == null:
		t._demo = t.create_tween()
		t._demo.tween_interval(1.4)
		t._demo.tween_method(t._slide, 0.0, t._most(), 0.35 + t._most() / 60.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t._demo.tween_interval(0.9)
		t._demo.tween_method(t._slide, t._most(), 0.0, 0.35 + t._most() / 60.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _most() -> float:
	return maxf(0.0, label.size.x - room) if room > 0.0 else 0.0

func _slide(v: float) -> void:
	off = v
	label.position.x = -off
	var m := label.material as ShaderMaterial
	m.set_shader_parameter("w", room)
	m.set_shader_parameter("off", off)
	m.set_shader_parameter("fade", FADE)
	m.set_shader_parameter("fade_r", 1.0 if off < _most() - 0.5 else 0.0)
	m.set_shader_parameter("fade_l", 1.0 if off > 0.5 else 0.0)

func _gui_input(e: InputEvent) -> void:
	if _most() <= 0.0: return
	var dx := 0.0
	if e is InputEventScreenDrag: dx = (e as InputEventScreenDrag).relative.x
	elif e is InputEventMouseMotion and ((e as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT): dx = (e as InputEventMouseMotion).relative.x
	if dx != 0.0:
		if _demo: _demo.kill()
		_slide(clampf(off - dx, 0.0, _most()))
		accept_event()
