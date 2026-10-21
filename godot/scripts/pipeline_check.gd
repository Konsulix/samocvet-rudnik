extends Node3D
## Stage 0: the smallest thing worth seeing on a phone. A glassy crystal turns in the light;
## tapping the button makes it spin faster and buzzes the phone, so input and haptics are checked too.

@onready var crystal: MeshInstance3D = $Crystal
@onready var label: Label = $UI/Panel/Info
var spin := 0.6

func _ready() -> void:
	$UI/Panel/Tap.pressed.connect(_on_tap)
	label.text = "Godot %s · %s" % [Engine.get_version_info().string, OS.get_name()]

func _process(delta: float) -> void:
	spin = lerpf(spin, 0.6, delta * 1.5)
	crystal.rotate_y(spin * delta)

func _on_tap() -> void:
	spin = 8.0
	Input.vibrate_handheld(40)
