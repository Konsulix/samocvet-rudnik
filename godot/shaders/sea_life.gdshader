shader_type spatial;
// Small sea life round a sea find (SpecSea): sea lilies, anemones, weed, starfish. COLOR.rgb is its colour,
// COLOR.a its own phase. In the current:
//   mode 0 — it sways, more the higher up (model y / h): stalks, weed, tentacles
//   mode 1 — a frill ripples along itself (UV.x along, UV.y towards the free edge): an oyster's mantle
//   mode 2 — still (a starfish), its skin knobbly
// The flesh glows a little at its rim, as if lit through.

render_mode cull_disabled;

uniform int mode = 0;
uniform float h = 0.3;
uniform float amp = 0.05;
uniform float speed = 1.0;
uniform float rough = 0.6;
uniform float rim_k = 0.35;
uniform float reach = 0.0;   // a swimmer's arms opening forward (0 .. 1)
uniform float snap = 0.0;    // and snapping shut

varying vec3 v_op;

float h3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vn(vec3 x) {
	vec3 i = floor(x), f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	float ph = COLOR.a * 6.2832;
	if (mode == 0) {
		float k = clamp(VERTEX.y / h, 0.0, 1.0);
		k *= k;
		// a slow lean in the current, and a quicker flutter over it
		VERTEX.x += (sin(TIME * speed + ph + VERTEX.y * 3.0) + 0.3 * sin(TIME * speed * 2.7 + ph * 2.0)) * amp * k;
		VERTEX.z += cos(TIME * speed * 0.8 + ph * 1.3 + VERTEX.y * 2.0) * amp * 0.6 * k;
	} else if (mode == 1) {
		VERTEX += NORMAL * sin(UV.x * 34.0 + TIME * speed * 2.0 + ph) * amp * UV.y;
	} else if (mode == 3) {
		// its eyes blink now and then (UV2.x 1: an eye; its centre on the stalk's tip): squashed shut for a moment
		// its arms (UV2.x 2): curling and uncurling slowly at rest, the two out of step; opened forward as it closes
		// in on its prey, snapped shut over it. A bend about the root, growing towards the tip (UV.y)
		if (UV2.x > 1.5) {
			float sd = sign(VERTEX.x);
			float ang = (0.28 * sin(TIME * 1.1 + sd * 0.9) - 0.95 * reach + 1.25 * snap) * UV.y;
			vec3 piv = vec3(VERTEX.x, -0.03, 0.4);
			vec3 r = VERTEX - piv;
			float ca = cos(ang), sa = sin(ang);
			VERTEX = piv + vec3(r.x, r.y * ca - r.z * sa, r.y * sa + r.z * ca);
			NORMAL = vec3(NORMAL.x, NORMAL.y * ca - NORMAL.z * sa, NORMAL.y * sa + NORMAL.z * ca);
		} else if (UV2.x > 0.5) {
			float bt = fract(TIME / 4.3 + COLOR.a);
			float shut = smoothstep(0.0, 0.03, bt) * (1.0 - smoothstep(0.05, 0.09, bt));
			float ey = 0.05;
			VERTEX.y = ey + (VERTEX.y - ey) * (1.0 - 0.9 * shut);
		}
		// a swimmer (UV.x along it, head 0 .. tail 1; UV.y out along a flap): its flaps beat in a wave running back,
		// the body sways a little behind the head
		VERTEX.y += sin(TIME * speed * 5.0 - UV.x * 11.0) * amp * UV.y;
		VERTEX.x += sin(TIME * speed * 2.5 - UV.x * 4.0) * amp * 0.35 * UV.x;
	}
	v_op = VERTEX;
}

void fragment() {
	// (vertex colours are written as on screen: into linear light)
	vec3 c = COLOR.rgb * COLOR.rgb * (COLOR.rgb * 0.3 + 0.7);
	if (mode == 2) {
		// a starfish's skin: rows of little knobs, lighter on top
		float kb = smoothstep(0.55, 0.8, vn(v_op * 220.0));
		c *= 0.8 + 0.45 * kb;
	}
	vec3 n = normalize(NORMAL);
	if (!FRONT_FACING) n = -n;
	float ro = rough;
	if (mode == 3) {
		// chitin: a glossy horn-like skin over fine growth lines and pits, mottled in patches, the rings' edges
		// lighter where they overlap; translucent-looking at the thin edges of the flaps
		float lines = sin(v_op.z * 260.0 + vn(v_op * 30.0) * 4.0) * 0.5 + 0.5;
		float pits = smoothstep(0.7, 0.85, vn(v_op * 320.0));
		float mott = vn(v_op * 18.0);
		c *= 0.82 + 0.25 * mott - 0.12 * pits + 0.06 * lines;
		vec3 dx = dFdx(v_op), dy = dFdy(v_op);
		float hgt = lines * 0.0008 - pits * 0.0012 + vn(v_op * 90.0) * 0.0006;
		vec3 r1 = cross(dy, n), r2 = cross(n, dx);
		float det = dot(dx, r1);
		n = normalize(abs(det) * n - sign(det) * (dFdx(hgt) * r1 + dFdy(hgt) * r2));
		ro = mix(0.22, 0.45, pits + (1.0 - mott) * 0.3);
		c += c * vec3(0.6, 0.35, 0.2) * smoothstep(0.3, 0.9, UV.y) * 0.5;
		SPECULAR = 0.6;
	}
	float rim = pow(1.0 - abs(dot(n, VIEW)), 2.0);
	ALBEDO = c;
	EMISSION = c * rim * rim_k;
	ROUGHNESS = ro;
	NORMAL = n;
}
