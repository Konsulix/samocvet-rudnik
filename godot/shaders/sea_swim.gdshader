// The sea's swimmers round a sea find (SpecReef): a scan or a model, its colour and relief baked (sea_prep.py), moved
// alive in the vertex shader, each by its own way of swimming (SpecReef.MODELS "anim"). Model space: one unit long
// along x, the head at +x, its back up +y, its sides ±z.
//   tail:  a wave runs back down the body from `swim_from` to the tail, strongest at the tail (an eel's body all of
//          it, a shark's or an ichthyosaur's only the tail stalk); it beats in bursts and glides between (`glide`)
//   flippers: everything out past the body's half width `flip_w` between flip_x0 and flip_x1 strokes up and down
//          about the body; the fore and hind pair (front of `flip_mid` or behind) a half beat apart, a plesiosaur's
//          rowing; the down stroke the stronger
//   neck:  past `neck_from` the neck sways side to side and the head nods (a plesiosaur looking about)
//   jaw:   the lower jaw (past `jaw_x`, under `jaw_y`) drops open now and then and snaps shut
//   jet:   an octopus: the mantle swells and squeezes, the arms trail and wave behind
// `phase` puts each one on its own beat. `haze`: the far ones, greyed into the deep water between.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D tex_d : source_color, filter_linear_mipmap;
uniform sampler2D tex_n : hint_normal, filter_linear_mipmap;
uniform vec3 tint = vec3(1.0);
uniform float gain = 1.35;
uniform float sat = 1.15;
uniform float rough = 0.45;
uniform float haze = 0.0;
uniform vec3 haze_col : source_color = vec3(0.07, 0.13, 0.16);
uniform float phase = 0.0;
uniform float swim = 0.05;
uniform float swim_f = 0.8;
uniform float swim_k = 1.2;
uniform float swim_from = 0.3;
uniform float glide = 0.5;
uniform float flip = 0.0;
uniform float flip_w = 0.08;
uniform float flip_x0 = -0.5;
uniform float flip_x1 = 0.5;
uniform float flip_mid = 0.0;
uniform float flip_f = 0.5;
uniform float neck = 0.0;
uniform float neck_from = 0.0;
uniform float jaw = 0.0;
uniform float jaw_x = 0.4;
uniform float jaw_y = 0.1;
uniform float jet = 0.0;
uniform vec2 eye = vec2(9.0);   // (the eye, side on: x along, y up; both eyes, either side)
uniform float eye_r = 0.008;
uniform float blink_force = 0.0;   // (tests: shut the eyes)
uniform float heave = 0.35;     // (the tail's wave a little up and down too: side on, a sideways wave is hardly seen)
varying vec3 v_mp;

// how hard it is swimming now: a few strong beats, then a glide (the same in SpecReef.Swim.burst)
float burst(float t) {
	return mix(1.0 - glide, 1.0, smoothstep(-0.3, 0.7, sin(t * 0.42 + phase * 6.2831)));
}

void vertex() {
	vec3 p = VERTEX;
	v_mp = p;
	float t = TIME;
	float b = burst(t);
	float tp = t * 6.2831 * swim_f + phase * 6.2831;
	// the tail: weight from nothing at swim_from to all at the tail tip
	float w = clamp((swim_from - p.x) / (swim_from + 0.5), 0.0, 1.0);
	VERTEX.z += sin(tp - p.x * swim_k * 6.2831) * swim * b * (0.15 * w + w * w);
	VERTEX.y += sin(tp - p.x * swim_k * 6.2831 + 1.3) * swim * heave * b * (0.15 * w + w * w);
	// the head turns a little against the tail (a swimming body pivots about its middle)
	VERTEX.z -= sin(tp) * swim * b * 0.2 * smoothstep(0.1, 0.5, p.x);
	// the flippers, rowing
	float side = abs(p.z) - flip_w;
	if (flip > 0.0 && side > 0.0 && p.x > flip_x0 && p.x < flip_x1) {
		float fp = t * 6.2831 * flip_f + phase * 6.2831 + (p.x > flip_mid ? 0.0 : 3.1416);
		// (a stroke: fast and strong down, slow back up)
		float s = sin(fp) + 0.35 * sin(2.0 * fp);
		VERTEX.y += s * side * flip * (0.6 + 0.4 * b);
		// and swept back a little as it strokes
		VERTEX.x -= abs(s) * side * flip * 0.25;
	}
	// the neck: its sway grows to the head
	if (neck > 0.0 && p.x > neck_from) {
		float n = (p.x - neck_from) / (0.5 - neck_from);
		n = n * n;
		VERTEX.z += sin(t * 0.55 + phase * 6.2831) * neck * n + sin(t * 1.3 + phase * 3.0) * neck * 0.25 * n;
		VERTEX.y += sin(t * 0.4 + phase * 5.0) * neck * 0.55 * n;
	}
	// the jaw: open a while every so often, then shut
	if (jaw > 0.0 && p.x > jaw_x) {
		float open = pow(max(0.0, sin(t * 0.62 + phase * 6.2831 + 1.0)), 4.0) * jaw;
		float low = smoothstep(jaw_y + 0.012, jaw_y - 0.012, p.y);
		VERTEX.y -= (p.x - jaw_x) * open * low;
	}
	// the octopus: the mantle (the head end) breathes in and out, the arms (the tail end) trail and curl
	if (jet > 0.0) {
		float pulse = pow(0.5 + 0.5 * sin(t * 1.6 + phase * 6.2831), 3.0);
		float mant = smoothstep(0.0, 0.3, p.x);
		VERTEX.yz += (p.yz - vec2(0.09, 0.0)) * pulse * jet * mant;
		float arm = smoothstep(0.1, -0.5, p.x);
		VERTEX.y += sin(t * 2.1 - p.x * 9.0 + p.z * 20.0 + phase * 6.2831) * jet * 0.25 * arm;
		VERTEX.z += sin(t * 1.7 - p.x * 7.0 + phase * 4.0) * jet * 0.2 * arm;
	}
}

void fragment() {
	vec3 c = texture(tex_d, UV).rgb;
	float l = dot(c, vec3(0.3, 0.5, 0.2));
	c = mix(vec3(l), c, sat) * gain * tint;
	// a blink every few seconds, now and then twice: the lid is the skin round the eye (the texture, blurred)
	if (eye.x < 5.0) {
		float f = fract(TIME * 0.21 + phase * 3.7);
		float shut = 1.0 - smoothstep(0.0, 0.02, abs(f - 0.5));
		shut = max(shut, (1.0 - smoothstep(0.0, 0.02, abs(f - 0.56))) * step(0.5, fract(phase * 7.3 + floor(TIME * 0.21 + phase * 3.7) * 0.37)));
		shut = max(shut, blink_force);
		float d = length(v_mp.xy - eye);
		float lid = smoothstep(eye_r * 1.3, eye_r * 0.9, d) * shut;
		// (the lid: the skin's colour, the texture averaged wide — the eye itself is too small to tint it — and a dark
		// crease across its middle)
		vec3 skin = textureLod(tex_d, UV, 6.0).rgb;
		skin = mix(vec3(dot(skin, vec3(0.3, 0.5, 0.2))), skin, sat) * gain * tint;
		skin *= 1.15 - 0.35 * smoothstep(eye_r * 0.18, 0.0, abs(v_mp.y - eye.y));
		c = mix(c, skin, lid);

	}
	c = mix(c, haze_col, haze);
	ALBEDO = c;
	NORMAL_MAP = FRONT_FACING ? texture(tex_n, UV).rgb : vec3(0.5, 0.5, 1.0);
	ROUGHNESS = mix(rough, 1.0, haze);
	SPECULAR = 0.35 * (1.0 - haze);
	EMISSION = haze_col * haze * 0.55;
}
