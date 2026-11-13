extends Node3D
## One butterfly flying a set course on a transparent backdrop, for laying over the trailer: it comes in from `from`,
## lands on `land` (the Fly's own approach and landing), sits `sit` seconds, takes off (the model's own take-off) and
## makes for `exit`, out of the frame. Prints "EV <what> <frame>" as it lands, takes off and leaves the frame.
##   godot --path godot --resolution 664x1440 --write-movie <dir>/f.png --fixed-fps 30 --quit-after N
##     res://tests/butterfly_flight.tscn -- from=-5,1.5,0 [land=0,0,0] [sit=2] [exit=6,1,0] [dist=24] [pitch=0.35]
##   (art/trailer/butterflies3.py lays the frames over the cards; 1 unit = 1/6 of the frame's width at the landing spot)
var fb: SpecButterfly.Fly
var args := {}
var sat := false
var off := false
var gone := false
var frame := 0
var exit_at := Vector3(6, 1, 0)
var cam: Camera3D
var land2 := Vector3.INF      # land2px=x,y land2d=D: a second landing, at that pixel of the frame, D from the camera
var next_at := Vector3.ZERO   # where it goes after the first landing: land2 or the exit
var sat2 := false


func _v(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	get_viewport().transparent_bg = true
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_color = Color(0.45, 0.45, 0.5)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.9, 0.5, 0)
	key.light_color = Color(1.0, 0.93, 0.82)
	key.light_energy = 1.3
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(-0.3, PI + 0.4, 0)
	rim.light_color = Color(0.6, 0.75, 1.0)
	rim.light_energy = 0.8
	add_child(rim)
	var land := _v(String(args.get("land", "0,0,0")))
	exit_at = _v(String(args.get("exit", "6,1,0")))
	cam = Camera3D.new()
	cam.fov = 30.0
	var pitch := float(args.get("pitch", "0.35"))
	cam.position = land + Vector3(0, sin(pitch), cos(pitch)) * float(args.get("dist", "24"))
	add_child(cam)
	cam.look_at(land)
	next_at = exit_at
	var id := String(args.get("kind", "monarch"))
	var hold := Node3D.new()
	hold.set_meta("grown", {})
	add_child(hold)
	fb = SpecButterfly.put(hold, Rng32.new(int(args.get("seed", "7"))), id, land, Vector3.UP,
			1.0 / float(SpecButterfly.KINDS[id].span), false, [[land, Vector3.UP]])
	await get_tree().process_frame
	await get_tree().process_frame
	# (the window has its real size only now: at _ready it still reads the project's 390x844)
	if args.has("land2px"):
		var q := String(args.land2px).split(",")
		land2 = cam.project_position(Vector2(float(q[0]), float(q[1])), float(args.get("land2d", "12")))
		next_at = land2
		print("viewport ", get_viewport().get_visible_rect().size)
	# on its way in: in the air at `from`, heading for the spot
	var from := _v(String(args.get("from", "-5,1.5,0")))
	fb.pos = from
	fb.vel = (land - from).normalized() * fb.size * 3.0
	fb.yaw = atan2(fb.vel.x, fb.vel.z)
	fb.state = SpecButterfly.Fly.LAND
	fb.spot = [land, Vector3.UP]
	fb.land_key = Vector3.INF
	fb._m_play("fly", 0.0, 0.0, 0.0)


func _process(_dt: float) -> void:
	frame += 1
	if fb == null or fb.spot.is_empty(): return
	if not sat and fb.state == SpecButterfly.Fly.SIT:
		sat = true
		fb.timer = float(args.get("sit", "2"))
		print("EV land %d" % frame)
	if sat and not off and fb.state == SpecButterfly.Fly.SIT:
		# sitting, it turns itself (a few small steps' worth) to face where it goes next: no turn in the air after
		var to := next_at - fb.pos
		fb.yaw = lerp_angle(fb.yaw, atan2(to.x, to.z), minf(1.0, _dt * 2.5))
	if sat and not off and fb.state == SpecButterfly.Fly.OFF:
		off = true
		print("EV off %d" % frame)
	if off and land2 != Vector3.INF and args.has("hover"):
		# (hover=1: it makes for land2 and hangs about it, never landing - a trailer hands it over to another there)
		if fb.state == SpecButterfly.Fly.FLY:
			fb.way = land2
			fb.far = false
			fb.retarget = 99.0
			fb.dwell = 99.0
			fb.timer = 99.0
			fb.beats_left = 9
			fb.want_glide = false
			if not sat2 and fb.pos.distance_to(land2) < fb.size * 0.6:
				sat2 = true
				var sp := cam.unproject_position(fb.global_position)
				print("EV near %d" % frame)
		return
	if off and land2 != Vector3.INF:
		if fb.state == SpecButterfly.Fly.FLY:
			fb.state = SpecButterfly.Fly.LAND
			fb.spot = [land2, Vector3.UP]
			fb.land_key = Vector3.INF
			fb.beats_left = 9
		if not sat2 and fb.state == SpecButterfly.Fly.SIT:
			sat2 = true
			fb.timer = 999.0
			print("EV land2 %d" % frame)
		return
	if off and fb.state == SpecButterfly.Fly.FLY:
		# (flapping all the way out: a sail here left its wings hanging)
		fb.beats_left = 9
		fb.want_glide = false
		# away: straight for the exit, never down again
		fb.way = exit_at
		fb.far = true
		fb.retarget = 99.0
		fb.dwell = 99.0
		fb.timer = 99.0
		if not gone:
			var sp := cam.unproject_position(fb.global_position)
			var r := get_viewport().get_visible_rect()
			if not r.grow(60).has_point(sp):
				gone = true
				print("EV gone %d" % frame)
