// Horns and antlers of an animal skull (SpecSkull, beasts): UV.x runs from the base (0, where the horn left the skull)
// to the tip (1). Vertex colour r: how open (1) or deep in a pit (0), as on the bone.
// mode 0 keratin: growth rings (ridged on a ram), streaks along the horn, grey-cream base darkening to a polished tip
// mode 1 antler: furrowed brown bark at the burr, rubbed paler along the tines, ivory tips
// mode 2 cast metal (gold, silver, copper): polished, hammered, dark in the hollows
// mode 3 engraved brass: scrolls and leaves cut into old brass
// mode 4 dressed: weathered horn gone green with verdigris, gold wire wrapped round the base, flecks of leaf higher up
// mode 5 starlit (a beast's legend): dark glass with a night sky deep inside — stars at three depths, nebulae, now and
// then a falling star running up the horn
shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/opal.gdshaderinc"

uniform int mode = 0;
uniform vec3 base_col : source_color = vec3(0.62, 0.58, 0.5);
uniform vec3 tip_col : source_color = vec3(0.16, 0.13, 0.11);
uniform float ring_k = 0.4;     // how ridged the growth rings are (a ram's horn: deep)
uniform float rings = 26.0;     // how many along the horn
uniform vec3 metal_col = vec3(0.95, 0.68, 0.28);
uniform float metal_rough = 0.2;
uniform float seed = 0.0;
uniform float age = 0.5;
// the scans (SpecSkull.horn_mat) and the horn's length; UV.y, UV2.x: the cosine and sine of the angle round the horn
uniform sampler2D fib_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D ring_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D ring_disp : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D bark_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D bark_disp : repeat_enable, filter_linear_mipmap_anisotropic;
uniform float horn_len = 1.0;

varying vec3 mp;
varying vec3 cam_m;

void vertex() {
	mp = VERTEX;
	cam_m = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}

// a scan laid on the horn: `uv` — along and round it (round: -0.5..0.5, jumping at the seam); gx, gy — how uv changes
// across a pixel, taken from the unbroken along and cosine/sine (the jump at the seam would pick the smallest mip)
vec4 on_horn(sampler2D t, vec2 uv, vec2 gx, vec2 gy) {
	return textureGrad(t, uv, gx, gy);
}

void fragment() {
	float u = clamp(UV.x, 0.0, 1.0);
	float along = u * horn_len;
	vec2 cs = vec2(UV.y, UV2.x);
	float ang = atan(cs.y, cs.x) / 6.2832;
	// (the angle's own slope, from its cosine and sine: no jump in it)
	vec2 g_al = vec2(dFdx(along), dFdy(along));
	vec2 g_an = vec2(cs.x * dFdx(cs.y) - cs.y * dFdx(cs.x), cs.x * dFdy(cs.y) - cs.y * dFdy(cs.x)) / (6.2832 * max(dot(cs, cs), 1e-4));
	float cav = COLOR.r;
	vec3 q = mp * 9.0 + seed;
	vec3 c;
	float rough = 0.5, metal = 0.0, spec = 0.4, h = 0.0;
	// streaks along the horn: noise stretched along it (u) and fine across it (position)
	float streak = fbm(vec3(u * 3.0, 0.0, 0.0) + mp * vec3(26.0, 26.0, 26.0) * 0.6 + seed);
	float ring = 0.5 + 0.5 * sin(u * rings * 6.2832 + fbm(q * 0.5) * 1.3 + fbm(vec3(u * 14.0, seed, 0.0)) * 2.5);
	if (mode == 0) {
		// keratin: fine fibres along the horn (a veneer's grain), growth bands round it (a cherry bark's), the rings'
		// own swell where the horn is ridged; pale and dry at the base, darker and worn smoother to the tip
		vec2 fuv = vec2(along * 1.1 + seed, ang * 1.0);
		float fib = on_horn(fib_tex, fuv, vec2(g_al.x * 1.1, g_an.x), vec2(g_al.y * 1.1, g_an.y)).r;
		fib = clamp((fib - 0.3) * 7.0, 0.0, 1.0);
		vec2 ruv = vec2(ang * 1.0 + seed * 0.3, along * 2.6);
		float band = dot(on_horn(ring_tex, ruv, vec2(g_an.x, g_al.x * 2.6), vec2(g_an.y, g_al.y * 2.6)).rgb, vec3(0.333));
		float bdisp = on_horn(ring_disp, ruv, vec2(g_an.x, g_al.x * 2.6), vec2(g_an.y, g_al.y * 2.6)).r;
		band = clamp(band * 3.2, 0.0, 1.0);
		float ridge = pow(ring, 2.2);
		vec3 b = mix(base_col, tip_col, smoothstep(0.2, 0.95, u));
		b *= 0.4 + 0.85 * fib;
		b *= 0.7 + 0.5 * band;
		// the grooves between the rings and the bands' own cracks: dark, dusty
		float groove = (1.0 - ridge) * ring_k + (1.0 - smoothstep(0.25, 0.5, bdisp)) * 0.5;
		b = mix(b, b * vec3(0.5, 0.45, 0.4), clamp(groove, 0.0, 1.0) * 0.7);
		b = mix(b, b * vec3(0.55, 0.5, 0.45), smoothstep(0.55, 0.75, fbm(mp * 7.0 + u * 4.0)) * 0.5);
		b = mix(b, mix(b, vec3(0.5, 0.45, 0.38), 0.45), smoothstep(0.25, 0.0, u));
		c = b;
		float worn = smoothstep(0.55, 1.0, u);
		rough = mix(0.82, 0.58, worn) - fib * 0.08;
		spec = 0.28;
		h = (fib * 1.1 + bdisp * 1.6) * mix(1.0, 0.6, worn) + ridge * ring_k * 1.3;
	} else if (mode == 1) {
		// antler: bone furrowed along its beams (a willow bark's furrows), deep and stained brown at the burr, shallower
		// up the beam, the ridges rubbed to ivory; the tines' ends polished pale; pearling round the burr
		vec2 buv = vec2(ang * 1.0 + seed * 0.3, along * 0.8);
		float lum = dot(on_horn(bark_tex, buv, vec2(g_an.x, g_al.x * 0.8), vec2(g_an.y, g_al.y * 0.8)).rgb, vec3(0.333));
		float disp = on_horn(bark_disp, buv, vec2(g_an.x, g_al.x * 0.8), vec2(g_an.y, g_al.y * 0.8)).r;
		float tip = smoothstep(0.8, 0.98, u);
		float deep = mix(1.0, 0.6, smoothstep(0.1, 0.8, u)) * (1.0 - tip * 0.75);
		float furrow = 1.0 - smoothstep(0.32, 0.72, disp);
		vec3 ivory = mix(vec3(0.4, 0.3, 0.19), vec3(0.62, 0.52, 0.37), clamp(lum * 2.4, 0.0, 1.0));
		vec3 stain = mix(vec3(0.08, 0.045, 0.025), vec3(0.24, 0.14, 0.07), clamp(lum * 2.2, 0.0, 1.0));
		c = mix(ivory, stain, clamp(furrow * deep * 1.15 + (1.0 - smoothstep(0.0, 0.3, u)) * 0.35, 0.0, 1.0));
		c = mix(c, vec3(0.78, 0.72, 0.6), tip * 0.85);
		// pearling: knobs at the burr
		float knob = smoothstep(0.55, 0.85, vn(q * 3.5)) * smoothstep(0.25, 0.0, u);
		c = mix(c, vec3(0.7, 0.62, 0.5), knob * 0.5);
		rough = mix(0.85, 0.5, tip) - (1.0 - furrow) * 0.1;
		spec = 0.3;
		h = disp * 4.5 * deep + knob * 1.5 + streak * 0.3;
	} else if (mode == 2) {
		vec2 cl = vor2(vec2(u * 30.0, fbm(q) * 6.0)).xy;
		float ham = vn(q * 3.0);
		c = metal_col * (0.82 + 0.3 * ham);
		metal = 1.0;
		rough = metal_rough + ham * 0.08;
		h = ham * 0.8 + cl.x * 0.2;
	} else if (mode == 3) {
		// scrolls: a warped wave pattern, cut lines dark with old polish in them
		vec3 w = q * 0.9 + vec3(fbm(q * 0.5), fbm(q * 0.5 + 7.0), fbm(q * 0.5 + 13.0)) * 2.4;
		float scroll = abs(sin(w.x * 2.6 + sin(w.y * 2.2) * 1.6 + u * 18.0));
		float leaf = abs(sin(w.z * 3.1 + cos(w.x * 1.7) * 2.0));
		float cut = (1.0 - smoothstep(0.0, 0.12, scroll)) + (1.0 - smoothstep(0.0, 0.08, leaf)) * 0.7;
		cut = clamp(cut, 0.0, 1.0);
		vec3 brass = metal_col * vec3(0.98, 0.9, 0.72);
		c = mix(brass * (0.85 + 0.25 * vn(q * 4.0)), brass * 0.18, cut);
		metal = mix(1.0, 0.4, cut);
		rough = mix(0.24, 0.6, cut);
		h = -cut * 1.4;
	} else {
		// weathered horn gone green: verdigris over pale horn, gold showing through in flakes
		float pat = fbm(q * 0.8 + 3.0);
		vec3 hornc = mix(vec3(0.6, 0.6, 0.52), vec3(0.32, 0.36, 0.3), streak);
		vec3 verd = mix(vec3(0.16, 0.42, 0.38), vec3(0.42, 0.66, 0.58), vn(q * 3.0));
		c = mix(hornc, verd, smoothstep(0.42, 0.62, pat) * 0.85);
		float flake = smoothstep(0.62, 0.7, fbm(q * 1.6 + 9.0)) * smoothstep(0.3, 0.6, u);
		c = mix(c, metal_col, flake);
		metal = flake;
		rough = mix(0.7, 0.25, flake);
		// gold wire wrapped round the base: a sleeve of tight turns, a rim at each end
		float sleeve = smoothstep(0.03, 0.05, u) * smoothstep(0.24, 0.21, u);
		float turns = 0.5 + 0.5 * sin(u * 900.0);
		vec3 wire = metal_col * (0.7 + 0.45 * turns);
		c = mix(c, wire, sleeve);
		metal = max(metal, sleeve);
		rough = mix(rough, 0.18, sleeve);
		h = streak * 0.5 + sleeve * turns * 0.6 + flake * 0.3;
	}
	vec3 emis = vec3(0.0);
	if (mode == 5) {
		// the sky inside: looked into along the ray from the eye, at three depths
		vec3 rd = normalize(mp - cam_m);
		vec3 sky = vec3(0.0);
		for (int k = 0; k < 3; k++) {
			float dep = 0.02 + float(k) * 0.035;
			vec3 sp = (mp + rd * dep) * (26.0 - float(k) * 5.0) + float(k) * 13.0 + seed;
			vec3 cell = floor(sp);
			vec3 fp = fract(sp) - 0.5 - (vec3(h3(cell), h3(cell + 7.0), h3(cell + 13.0)) - 0.5) * 0.6;
			float on = step(0.72, h3(cell + 3.0));
			float tw = 0.6 + 0.4 * sin(TIME * (1.0 + h3(cell + 5.0) * 3.0) + h3(cell) * 30.0);
			vec3 sc = mix(vec3(0.7, 0.8, 1.0), vec3(1.0, 0.85, 0.6), h3(cell + 9.0));
			sky += sc * on * tw * (smoothstep(0.12, 0.0, length(fp)) * 5.0 + smoothstep(0.3, 0.0, length(fp)) * 0.4) * (1.6 - float(k) * 0.4);
		}
		vec3 nq = (mp + rd * 0.05) * 8.0 + seed;
		float neb = fbm(nq) * fbm(nq * 2.1 + 3.0);
		sky += mix(vec3(0.25, 0.05, 0.45), vec3(0.05, 0.25, 0.5), fbm(nq * 0.7 + 9.0)) * smoothstep(0.12, 0.35, neb) * 0.8;
		// a falling star: once in a while one runs up the horn
		float fs = fract(TIME * 0.11 + seed * 0.1);
		float head = fs * 1.6 - 0.3;
		float streak = smoothstep(0.06, 0.0, abs(u - head)) * smoothstep(head - 0.25, head, u) * step(fs, 0.6);
		sky += vec3(1.0, 0.95, 0.85) * streak * smoothstep(0.55, 0.85, fbm(mp * 30.0 + seed)) * 3.0;
		emis = sky;
		c = vec3(0.006, 0.007, 0.02);
		rough = 0.18;
		spec = 0.35;
		metal = 0.0;
		h = 0.0;
	}
	// down in the hollows: dark
	c *= mix(0.35, 1.0, cav);
	ALBEDO = c;
	METALLIC = metal;
	ROUGHNESS = rough;
	SPECULAR = spec;
	EMISSION = emis;
	NORMAL = bump(NORMAL, VERTEX, h * 0.004, 1.0);
}
