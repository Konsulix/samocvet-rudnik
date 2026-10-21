extends Node
## Loads scripts one by one so their parse errors show up separately:  res://tests/check_scripts.tscn -- dir=res://scripts/specimen

func _ready() -> void:
	var dir := "res://scripts/specimen"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("dir="): dir = a.substr(4)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			print("--- ", f)
			var s: GDScript = load(dir + "/" + f)
			if s == null or not s.can_instantiate(): print("    FAILED")
	get_tree().quit()
