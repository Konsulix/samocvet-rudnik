shader_type spatial;
// The film of a fossil leaf on its split slab (SpecFern): a frond of pinnules, ginkgo fans, dawn-redwood sprigs or a
// horsetail, laid flat a hair above the stone. UV.x runs along a blade from its base to its tip, UV.y across it (-1..1);
// UV2.x is how far along the whole plant (0 at its base), for the legendary wave; COLOR.r 1 = stem, COLOR.g a random per
// blade, COLOR.b 0.5 = a ginkgo fan (UV.y its angle across the fan, UV.x out from the stalk).
// film: 0 carbon (glossy black on grey mudstone), 1 pyrite (gold, glittering), 2 silver (pale pyrophyllite on black
// shale), 3 iron (rusty orange on buff stone). mould: the counterpart half, the film a dull pressed shadow.
render_mode cull_disabled;

uniform vec3 film_col : source_color = vec3(0.1, 0.09, 0.08);
uniform int film = 0;
uniform float mould = 0.0;
uniform float spring = 0.0;    // the legendary "spring": light runs up the veins and the leaf greens as if alive
uniform float seed = 0.0;

varying vec3 v_op;

float h3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vn(vec3 x) {
	vec3 i = floor(x), f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	v_op = VERTEX;
}

void fragment() {
	float stem = COLOR.r;
	float fan = step(0.25, COLOR.b);
	float ay = abs(UV.y);
	// veins: a midrib and side veins sweeping out to the margin; a ginkgo fan's veins fork out from the stalk
	float mid = (1.0 - smoothstep(0.0, 0.1, ay)) * (1.0 - fan);
	float side = 1.0 - smoothstep(0.0, 0.16, abs(fract(UV.x * 7.0 - ay * 1.6 + COLOR.g * 3.0) - 0.5) * 2.0);
	side *= smoothstep(0.08, 0.2, ay) * (1.0 - fan);
	float fv = 1.0 - smoothstep(0.0, 0.3, abs(fract(UV.y * (9.0 + UV.x * 9.0) + COLOR.g) - 0.5) * 2.0);
	float veins = max(max(mid, side * 0.7), fv * fan * smoothstep(0.08, 0.25, UV.x));
	veins *= 1.0 - stem;
	// the margin: a fine dark line where the film is thickest, and the blade crumbling a little at its tip
	float edge = smoothstep(0.72, 1.0, ay) * (1.0 - stem);
	float mott = vn(v_op * 90.0 + seed) * 0.6 + vn(v_op * 23.0 + seed) * 0.4;
	vec3 c = film_col;
	float metal = 0.0;
	float rough = 0.35;
	float spec = 0.5;
	if (film == 0) {
		// carbon: glossy jet-black, the veins a shade browner, little islands where the film flaked off to the stone
		c = film_col * (0.8 + 0.5 * mott) + vec3(0.05, 0.035, 0.02) * veins;
		rough = 0.18 + 0.25 * mott;
		spec = 0.7;
	} else if (film == 1) {
		// pyrite: brassy gold in tiny crystals that catch the light one by one, darker veins, a rainbow tarnish here and there
		float glint = step(0.93, h3(floor(v_op * 420.0) + seed));
		c = film_col * (0.75 + 0.4 * mott) * (1.0 - 0.3 * veins) + vec3(0.9, 0.75, 0.45) * glint * 0.6;
		float tar = smoothstep(0.55, 0.8, vn(v_op * 14.0 + seed + 3.0));
		c = mix(c, c * vec3(0.7, 0.8, 1.25), tar * 0.5);
		metal = 0.9;
		rough = mix(0.32, 0.1, glint);
		// (a dark studio leaves bare metal dull: the gold glints on its own a little)
		EMISSION = film_col * (0.06 + 0.5 * glint * (0.5 + 0.5 * sin(TIME * 2.0 + h3(floor(v_op * 420.0)) * 30.0)));
	} else if (film == 2) {
		// silver: pale, pearly, with a soft sheen across it, the veins whiter
		c = film_col * (0.82 + 0.25 * mott) + vec3(0.12) * veins;
		EMISSION = film_col * 0.015;
		metal = 0.35;
		rough = 0.3;
		spec = 0.8;
	} else {
		// iron: rusty orange to brown, darker veins, matte
		c = film_col * (0.7 + 0.5 * mott) * (1.0 - 0.35 * veins);
		rough = 0.75;
		spec = 0.3;
	}
	c *= 1.0 - edge * (film == 2 ? 0.75 : 0.5);
	if (mould > 0.5) {
		// the counterpart: what the leaf left on the other half — a duller, thinner print
		c = mix(c, c * 0.55 + vec3(0.02), 0.6);
		metal *= 0.5;
		rough = mix(rough, 0.6, 0.6);
	}
	ALBEDO = c;
	METALLIC = metal;
	ROUGHNESS = rough;
	SPECULAR = spec;
	if (spring > 0.0) {
		// light running up the plant from its base, again and again, through the veins; the film greens under it
		float w = fract(UV2.x * 1.3 - TIME * 0.22);
		float pulse = smoothstep(0.0, 0.08, w) * (1.0 - smoothstep(0.08, 0.35, w));
		float alive = 0.5 + 0.5 * sin(TIME * 0.6 + UV2.x * 3.0);
		ALBEDO = mix(ALBEDO, vec3(0.12, 0.32, 0.08), 0.35 * alive);
		EMISSION += vec3(0.45, 1.3, 0.35) * (pulse * (0.35 + 1.4 * veins + stem) + 0.06 * alive) * spring;
	}
}
