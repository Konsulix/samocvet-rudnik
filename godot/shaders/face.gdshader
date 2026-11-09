shader_type spatial;
// A nodule broken or sawn open (SpecimenBuilder._septaria, _flint), one mesh, drawn pixel by pixel: where the surface
// lies on the cutting plane it is the face, elsewhere the rind (so the edge of the face is a clean line, not the
// triangles' steps).
//  mode 0 — a septarian nodule sawn and polished: clay cells, each its own shade, crazed by golden calcite veins that
//           glitter with grains; a dark crack at the heart; brown rind
//  mode 1 — flint broken open: glassy black, conchoidal ripples spreading from where the blow fell (in the light only),
//           going cloudy grey-blue towards the white chalk rind
// Per vertex: COLOR.b = inside the hollow at the heart (part of the face, though sunk below the plane), COLOR.g = the
// rind's hollows (shade).

uniform int mode = 0;
uniform vec3 face_c = vec3(0.0);     // the face's middle, model space
uniform vec3 face_n = vec3(0.0, 1.0, 0.0);
uniform vec3 face_t1 = vec3(1.0, 0.0, 0.0);
uniform vec3 face_t2 = vec3(0.0, 0.0, 1.0);
uniform float face_d = 0.0;          // the plane: dot(p, face_n) == face_d
uniform float face_r = 1.0;          // the face's radius
uniform vec2 hit = vec2(0.3, 0.0);   // flint: where the blow fell (face uv)
uniform float seed = 0.0;
uniform vec3 c_a : source_color = vec3(0.47, 0.41, 0.34);   // septaria: clay light / flint: black
uniform vec3 c_b : source_color = vec3(0.18, 0.15, 0.12);   // septaria: clay dark / flint: the grey edge
uniform vec3 c_vein : source_color = vec3(0.88, 0.62, 0.18);
uniform float band_k = 0.0;   // flint: bands following the outline (striped flint), how strong
uniform float band_f = 20.0;  // and how many
uniform vec3 c_rind : source_color = vec3(0.85, 0.82, 0.74);
uniform sampler2D scan : source_color, filter_linear_mipmap, repeat_enable;       // the face's grain (septaria clay)
uniform sampler2D rind_scan : source_color, filter_linear_mipmap, repeat_enable;  // the rind's rock

varying vec3 v_op;
varying vec3 v_no;

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 h22(vec2 p) { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }
float vn2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1.0, 0.0)), f.x), mix(h2(i + vec2(0.0, 1.0)), h2(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm2(vec2 p) { return vn2(p) * 0.5 + vn2(p * 2.03 + 7.1) * 0.25 + vn2(p * 4.01 + 3.3) * 0.125 + vn2(p * 8.03 + 1.7) * 0.0625; }
float lum(vec3 c) { return dot(c, vec3(0.3, 0.5, 0.2)); }
float detail(sampler2D t, vec2 uv) { return clamp(lum(texture(t, uv).rgb) / max(lum(textureLod(t, uv, 5.0).rgb), 0.03), 0.4, 1.8); }

// cells: x = how far from the border between the nearest two (F2 - F1, halved), yz = the nearest cell's id
vec3 cells(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 id = n;
	for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) {
		vec2 g = vec2(float(i), float(j));
		vec2 o = h22(n + g + seed) * 0.8 + 0.1;
		float d = length(g + o - f);
		if (d < d1) { d2 = d1; d1 = d; id = n + g; }
		else if (d < d2) { d2 = d; }
	}
	return vec3((d2 - d1) * 0.5, id);
}

void vertex() {
	v_op = VERTEX;
	v_no = NORMAL;
}

void fragment() {
	vec3 q = v_op - face_c;
	vec2 uv = vec2(dot(q, face_t1), dot(q, face_t2)) / face_r;
	float hole = COLOR.b;
	// on the plane (a hair's width either side) or in the hollow: the face
	float dpl = dot(v_op, face_n) - face_d;
	float on = max(smoothstep(-0.006, -0.002, dpl), step(0.02, hole));
	float rim = clamp(length(uv), 0.0, 1.0);
	vec3 col;
	float rough;
	float coat;
	vec3 nmod = face_n;   // the face's normal in model space, tipped by its relief
	if (mode == 0) {
		vec2 w = uv * 3.2 + (vec2(fbm2(uv * 3.0 + seed), fbm2(uv * 3.0 + seed + 9.0)) - 0.5) * 0.55;
		vec3 c = cells(w);
		float vw = mix(0.022, 0.075, smoothstep(0.9, 0.05, rim)) * (0.75 + 0.5 * fbm2(w * 4.0 + 3.0));
		float vein = 1.0 - smoothstep(vw * 0.75, vw, c.x);
		float seam = 1.0 - smoothstep(vw, vw * 1.9, c.x);
		float shade = h2(c.yz + seed);
		float grain = detail(scan, uv * 1.7 + seed * 0.1);
		vec3 clay = mix(c_a, c_b, shade * 0.65 + fbm2(uv * 9.0 + c.yz) * 0.25) * grain;
		clay = mix(clay, c_b * 0.55, seam * 0.6);
		vec3 g = cells(uv * 46.0 + 3.0).yzx;
		float sp = pow(h2(g.xy), 8.0);
		float mid = smoothstep(vw, 0.0, c.x);
		vec3 cal = mix(c_vein * 0.45, c_vein * 1.15, mid) * (0.85 + 0.3 * h2(g.xy + 1.3)) + sp * 0.6;
		col = mix(clay, cal, vein);
		rough = mix(0.32, 0.12, vein);
		coat = 0.6;
		col = mix(col, mix(vec3(0.08, 0.05, 0.03), cal * 0.5, fbm2(uv * 20.0)), hole);
		rough = mix(rough, 0.5, hole);
		coat *= 1.0 - hole;
	} else {
		// depth in from the break's edge (per vertex): the cortex band at the edge, bands following the outline, the heart
		float dep = COLOR.g;
		float cl = fbm2(uv * 4.0 + seed);
		col = mix(c_a, c_a * 1.8 + vec3(0.0, 0.004, 0.012), cl * 0.6);
		col = mix(c_b, col, smoothstep(0.02, 0.3, dep + (cl - 0.5) * 0.12));
		float bs = 0.5 + 0.5 * sin(dep * band_f + (fbm2(uv * 3.0 + seed + 5.0) - 0.5) * 4.0);
		float bw = 0.5 + 0.5 * sin(dep * band_f * 0.37 + 1.3);
		col = mix(col, c_vein * (0.75 + 0.25 * cl), band_k * smoothstep(0.55, 0.85, bs) * (0.4 + 0.6 * bw) * smoothstep(0.92, 0.6, dep));
		col += vec3(0.25) * smoothstep(0.985, 1.0, vn2(uv * 140.0 + seed)) * (1.0 - rim);
		// the conchoidal fracture: rings out from the blow, its slope worked out exactly (no screen ripples)
		vec2 d = uv - hit;
		float rr = length(d);
		float a = 1.1;
		float f = 24.0 + sin(atan(d.y, d.x) * 3.0 + seed) * 2.0;
		float dh = (f * cos(rr * f) - a * sin(rr * f)) * exp(-a * rr) * 0.7 + 7.0 * cos(rr * 7.0) * 0.5;
		vec2 grad = (rr > 1e-4 ? d / rr : vec2(0.0)) * dh / face_r;
		nmod = normalize(face_n - (face_t1 * grad.x + face_t2 * grad.y) * 0.02);
		rough = 0.06 + rim * 0.15;
		coat = 0.9;
		// the hollow: chalcedony lining, grey-blue and faintly banded, under the crystals
		vec3 lin = mix(vec3(0.14, 0.15, 0.18), vec3(0.26, 0.27, 0.31), (0.5 + 0.5 * sin(rr * 40.0)) * 0.5 + fbm2(uv * 12.0) * 0.5);
		col = mix(col, lin, hole);
		rough = mix(rough, 0.35, hole);
		coat *= 1.0 - hole;
	}
	// the rind: the rock's scan, seen from the side it faces most
	vec3 an = pow(abs(normalize(v_no)), vec3(4.0));
	an /= an.x + an.y + an.z;
	vec3 ps = v_op * 1.3 + seed * 0.05;
	vec3 rk = texture(rind_scan, ps.yz).rgb * an.x + texture(rind_scan, ps.xz).rgb * an.y + texture(rind_scan, ps.xy).rgb * an.z;
	float rl = lum(rk) / max(lum(textureLod(rind_scan, ps.xz, 5.0).rgb), 0.03);
	vec3 rind = c_rind * clamp(pow(rl, 1.4), 0.35, 1.6) * (1.0 - 0.55 * COLOR.g);
	col = mix(rind, col, on);
	rough = mix(0.93, rough, on);
	coat *= on;
	vec3 nv = normalize((VIEW_MATRIX * (MODEL_MATRIX * vec4(nmod, 0.0))).xyz);
	NORMAL = normalize(mix(NORMAL, nv, on * (1.0 - hole)));
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.5;
	CLEARCOAT = coat;
	CLEARCOAT_ROUGHNESS = 0.05;
}
