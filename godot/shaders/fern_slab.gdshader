shader_type spatial;
// The split slab under a fossil leaf (SpecFern._slab / _nodule): fine-grained shale or mudstone. Its grain from a
// photo-scanned rock (Poly Haven rock_surface, its brightness only), recoloured to the stone; the broken sides show the
// thin laminae it split along; the top — the bedding plane — smoother and with a dull sheen. Iron-stained stone is
// mottled with rust. A nodule (Mazon Creek): an ironstone concretion split in half — the face grey-buff inside, a rusty
// rind round its edge with a dark line under it and faint rings (Liesegang bands) soaking in, the outside a weathered
// rusty crust. UV2.x: 0..1 across the top from its middle to its edge, 1..2 down the side, 2 underneath.
render_mode cull_disabled;

uniform vec3 stone : source_color = vec3(0.5, 0.48, 0.45);
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float seed = 0.0;
uniform float rust = 0.0;
uniform float nodule = 0.0;

varying vec3 v_op;
varying vec3 v_on;

float h3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vn(vec3 x) {
	vec3 i = floor(x), f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	v_op = VERTEX;
	v_on = NORMAL;
}

void fragment() {
	vec3 w = pow(abs(v_on), vec3(4.0));
	w /= w.x + w.y + w.z;
	vec3 t = texture(tex, v_op.zy * 2.6 + seed).rgb * w.x + texture(tex, v_op.xz * 2.6 + seed).rgb * w.y + texture(tex, v_op.xy * 2.6 + seed).rgb * w.z;
	vec3 t2 = texture(tex, v_op.xz * 0.7 + seed + 0.37).rgb;
	float l = clamp((dot(t, vec3(0.333)) - 0.45) * 1.8 + 0.5, 0.0, 1.0);
	float l2 = dot(t2, vec3(0.333));
	float top = smoothstep(0.55, 0.9, v_on.y);
	float lam = 0.5 + 0.5 * sin(v_op.y * 240.0 + vn(v_op * 7.0 + seed) * 7.0);
	float big = vn(v_op * 2.2 + seed);
	vec3 c = stone * (0.55 + 0.75 * l) * (0.78 + 0.4 * big) * (0.8 + 0.4 * l2);
	float r = UV2.x;
	float rough = 0.0;
	if (nodule > 0.5) {
		// the split face: rings soaking in from the edge, the rind rusty and the line under it dark
		float wob = (vn(v_op * 5.0 + seed) - 0.5) * 0.05;
		float rr = r + wob;
		float rind = smoothstep(0.84, 0.9, rr);
		float dark = exp(-pow((rr - 0.83) / 0.012, 2.0));
		float bands = (0.5 + 0.5 * sin(rr * 46.0 + vn(v_op * 3.0 + seed) * 2.0)) * smoothstep(0.35, 0.8, rr);
		vec3 rindc = vec3(0.1, 0.035, 0.012) * (0.75 + 0.45 * l);
		vec3 face = mix(c, c * vec3(1.12, 0.86, 0.62), bands * 0.55 + 0.35 * smoothstep(0.6, 0.84, rr));
		face = mix(face, rindc, rind * 0.9);
		face *= 1.0 - 0.5 * dark;
		// outside: a lumpy weathered crust of limonite, dark rust with paler patches
		float lump = vn(v_op * 11.0 + seed) * 0.6 + vn(v_op * 30.0 + seed) * 0.4;
		vec3 crust = mix(vec3(0.06, 0.018, 0.005), vec3(0.2, 0.07, 0.02), lump) * (0.7 + 0.5 * l);
		c = mix(face, crust, smoothstep(0.99, 1.06, r));
		rough = 0.08 * smoothstep(1.0, 1.1, r);
	} else {
		// the edge where the slab broke: rounder, darker, and the sides in thin laminae
		float rim = 1.0 - smoothstep(0.75, 0.98, v_on.y);
		c *= mix(0.72 + 0.32 * lam, 1.0, top) * (1.0 - 0.25 * rim);
		if (rust > 0.0) {
			float m = smoothstep(0.45, 0.8, vn(v_op * 3.5 + seed + 2.0));
			c = mix(c, vec3(0.42, 0.2, 0.07), m * 0.45 * rust);
		}
	}
	// fine specks of mica on the bedding plane
	c += vec3(0.3) * step(0.996, h3(floor(v_op * 700.0) + seed)) * top * 0.5;
	ALBEDO = c;
	ROUGHNESS = mix(0.88, 0.58, top) - 0.1 * l + rough;
	SPECULAR = 0.35;
}
