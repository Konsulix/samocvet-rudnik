shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec3 col = vec3(0.4, 0.8, 1.0);
uniform float phase = 0.0;
uniform float speed = 0.6;     // beats per second
uniform int part = 0;          // 0 the bell, 1 an oral arm, 2 a tentacle, 3 the bell's inner layer, 4 its halo
uniform float seed = 0.0;      // each jelly's own crooked rim and skin
varying float v_d;
varying vec3 v_l;

float h3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vn(vec3 x) {
	vec3 i = floor(x), f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// one swim stroke: a quick contraction (the first fifth), then a long slow relaxation
float beat(float u) {
	return u < 0.2 ? sin(u / 0.2 * 1.5708) : pow(1.0 - (u - 0.2) / 0.8, 2.0);
}
// how far ahead of its steady drift the jelly is: it shoots forward on the stroke, then glides and falls back
float surge(float u) {
	float e = 1.0 - pow(1.0 - min(u / 0.35, 1.0), 3.0);
	return e - u;
}

void vertex() {
	v_l = VERTEX;
	float u = fract(TIME * speed + phase);
	float c = beat(u);
	float sg = surge(u) * 0.55;
	if (part == 4) {
		VERTEX *= 1.0 + 0.06 * c;
	} else if (part == 0 || part == 3) {
		// the bell: the rim pulls in hard and the dome rises as it beats; the rim wavers, unevenly, like soft jelly
		float low = 1.0 - clamp(VERTEX.y / 0.62, 0.0, 1.0);
		float a = atan(VERTEX.z, VERTEX.x);
		float wob = (vn(vec3(a * 2.0, seed, TIME * 0.3)) - 0.5) * 0.12 + (vn(vec3(a * 6.0, seed + 3.0, TIME * 0.5)) - 0.5) * 0.05;
		VERTEX.xz *= (1.0 - 0.3 * c * low * low) * (1.0 + wob * low * low);
		VERTEX.y *= 1.0 + 0.14 * c;
		VERTEX.y += wob * low * low * 0.4;
	} else {
		float d = -VERTEX.y;
		// tentacle tips curl a little (tentacles are a bit stiffer near the bell)
		float curl = smoothstep(0.6, 1.0, d / max(UV.y, 0.01)) * (part == 2 ? 0.08 : 0.0);
		VERTEX.x += sin(d * 9.0 + seed) * curl;
		VERTEX.z += cos(d * 9.0 + seed) * curl;
		// trailing behind: pulled straight and long on the stroke, drifting open and curling in the glide,
		// a wave running down from the bell to the tips
		float open = 1.0 - 0.65 * c;
		float k = (part == 1 ? 0.14 : 0.22) * open;
		float w = TIME * 2.2 - d * 2.6 + phase * 6.0;
		VERTEX.x += sin(w) * k * d + sin(w * 1.7 + 1.0) * 0.03 * d;
		VERTEX.z += cos(w * 0.8 + 2.0) * k * d;
		VERTEX.xz *= mix(1.0, 0.55, c * exp(-d * 1.5));
		VERTEX.y -= c * 0.18 * d;
		if (part == 1) {
			// frilly arms: their edges ripple
			VERTEX.xz += vec2(sin(d * 14.0 + TIME * 3.0), cos(d * 11.0 + TIME * 2.4)) * 0.025;
		}
		v_d = d;
	}
	VERTEX.y += sg;
}

void fragment() {
	float fr = 1.0 - abs(dot(normalize(NORMAL), VIEW));
	float u = fract(TIME * speed + phase);
	float glow = 0.8 + 0.45 * beat(u);
	vec3 c;
	if (part == 0) {
		float r = length(v_l.xz) / 0.6;
		float a = atan(v_l.z, v_l.x);
		// four horseshoe gonads round the middle, brighter and warmer
		float gon = 0.0;
		for (int k = 0; k < 4; k++) {
			float ak = 0.785 + float(k) * 1.5708;
			vec2 cen = vec2(cos(ak), sin(ak)) * 0.2;
			float rr = length(v_l.xz / 0.6 - cen);
			gon = max(gon, exp(-pow((rr - 0.12) / 0.035, 2.0)) * smoothstep(0.0, 0.08, rr));
		}
		// radial canals from the middle to the rim, a ring canal at the rim
		// (soft and wavering, fading in from the middle: veins, not wheel spokes)
		float canals = pow(abs(cos(a * 8.0 + sin(r * 9.0) * 0.12)), 30.0) * smoothstep(0.3, 0.6, r) * (0.5 + 0.5 * vn(v_l * 12.0));
		float ring = exp(-pow((r - 0.93) / 0.03, 2.0));
		// the jelly itself: a faint grain, clear in the middle, bright at the edges seen side-on
		float grain = 0.75 + 0.5 * vn(v_l * 40.0);
		// little bulbs along the rim where the tentacles hang
		float bulbs = pow(max(0.0, cos(a * 12.0)), 8.0) * smoothstep(0.85, 0.98, r) * (1.0 - smoothstep(0.12, 0.2, v_l.y));
		vec3 warm = mix(col, vec3(1.4, 0.7, 0.9), 0.45);
		// skin: a fine net of soft cells, seen where the bell turns side-on, and a wet glint
		vec3 q = v_l * 34.0 + seed;
		vec3 cell = floor(q);
		float dm = 9.0;
		for (int z = -1; z <= 1; z++) for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
			vec3 g = cell + vec3(float(x), float(y), float(z));
			dm = min(dm, length(g + vec3(h3(g), h3(g + 3.0), h3(g + 7.0)) - q));
		}
		float skin = smoothstep(0.35, 0.75, dm);
		float glint = pow(max(0.0, dot(reflect(-VIEW, normalize(NORMAL)), normalize(vec3(-0.4, 0.8, 0.5)))), 24.0);
		float face = 1.0 - fr;
		c = col * (0.01 + 0.55 * pow(fr, 2.5) * (0.7 + 0.5 * skin)) * grain;
		c += vec3(1.0) * glint * 0.25;
		gon *= 1.0 + 1.4 * face * face;
		canals *= 1.0 + 1.8 * face * face;
		c += warm * gon * 0.45 + col * canals * 0.15 + col * ring * 0.35 + warm * bulbs * 0.5;
		c *= glow;
	} else if (part == 4) {
		// light scattered in the water round it: soft, uneven, drifting and flickering
		float f = abs(dot(normalize(NORMAL), VIEW));
		vec3 q = v_l * 2.5 + vec3(seed, TIME * 0.25, TIME * 0.17);
		float n = vn(q) * 0.6 + vn(q * 2.3 + 5.0) * 0.4;
		float flick = 0.85 + 0.15 * sin(TIME * 7.0 + seed) * sin(TIME * 3.1 + seed * 2.0);
		c = col * 0.09 * pow(f, 1.6) * smoothstep(0.25, 0.85, n) * flick * glow;
	} else if (part == 3) {
		// the inner layer, seen through the jelly: a softer, warmer glow, so the bell has a thickness
		c = mix(col, vec3(1.2, 0.8, 1.0), 0.3) * (0.03 + 0.22 * pow(fr, 1.6)) * glow;
	} else if (part == 1) {
		c = mix(col, vec3(1.3, 0.75, 0.95), 0.3) * (0.16 + 0.3 * fr) * exp(-v_d * 0.7) * glow * (0.7 + 0.5 * vn(v_l * 30.0));
	} else {
		// fine tentacles, beaded with stinging cells
		float beads = 0.8 + 0.25 * pow(0.5 + 0.5 * sin(v_d * 60.0), 4.0);
		// thicker and thinner along it
		beads *= 0.7 + 0.6 * vn(vec3(v_d * 5.0, seed + v_l.x * 30.0, 0.0));
		c = col * 0.35 * exp(-v_d * 0.8) * glow * beads;
	}
	ALBEDO = c;
}
