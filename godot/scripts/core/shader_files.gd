class_name ShaderFiles
extends RefCounted
## Shaders the game writes as text (the specimen variants of spec.gdshaderinc, the mushrooms, jellyfish, legendary
## glows, foliage, plants, lightning). The export's shader baker only sees .gdshader files, so on the iPhone these
## were compiled while the game ran — a ~140 ms stall each, and the loading screen froze.
## `-- bake_shaders` writes every one of them to res://shaders/gen/<name>.gdshader (the iOS build does it before
## exporting); get_shader() takes that file while its text is still the code's, and otherwise builds the shader from
## the text as before and says so in Diag. One Shader per text, shared by all its materials.

const DIR := "res://shaders/gen/"

static var _made := {}

static func get_shader(name: String, code: String) -> Shader:
	if _made.has(name):
		return _made[name]
	var sh: Shader = null
	var path := DIR + name + ".gdshader"
	if ResourceLoader.exists(path):
		var f: Shader = load(path)
		# (a Windows checkout may have turned the file's line ends into CR LF)
		if f.code.replace("\r", "") == code.replace("\r", ""):
			sh = f
	if sh == null:
		sh = Shader.new()
		sh.code = code
		Diag.note("shader %s built at run time (not baked: run bake_shaders)" % name)
	_made[name] = sh
	return sh

## every shader text get_shader() is asked for in the game: name -> code
static func sources() -> Dictionary:
	var out := {}
	for f in SpecMat.BAKE:
		out[SpecMat.name_of(f)] = SpecMat.code_of(f)
	out.fungi = SpecFungi.SHADER
	out.jelly = SpecJelly.SHADER
	out.legend_heart = SpecLegend.HEART
	out.legend_over = SpecLegend.OVER
	out.legend_glow = SpecLegend.GLOW
	out.foliage = SpecFoliage.SHADER
	out.plants = SpecPlants.SHADER
	out.plants_bed = SpecPlants.BED_SHADER
	out.bolt = SpecBolt.SHADER
	return out

## write them all (the old files of names no longer asked for are removed)
static func bake() -> int:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var src := sources()
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".gdshader") and not src.has(f.get_basename()):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + f))
	for name in src:
		var fa := FileAccess.open(ProjectSettings.globalize_path(DIR + name + ".gdshader"), FileAccess.WRITE)
		fa.store_string(String(src[name]))
		fa.close()
	return src.size()
