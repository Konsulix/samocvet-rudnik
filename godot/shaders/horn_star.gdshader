// Starlit horns (SpecBeastFx "starhorn"): the horn turned to deep clear glass with a night sky inside it. What lies
// behind it shows through, bent and dimmed blue (the screen behind, offset by the horn's slope); looking in along the
// eye's ray, eight layers deep: stars at every depth (they slide past each other as the skull turns), nebulae drifting
// in the depths; a cold rim of light round the edge, a hard glint on the polish; now and then a falling star runs up
// the horn. UV.x: along the horn, 0 at the skull .. 1 at the tip; COLOR.r: how open (1) or deep in a pit (0).
shader_type spatial;
render_mode cull_back, specular_schlick_ggx;
#include "res://shaders/opal.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float seed = 0.0;

varying vec3 mp;
varying vec3 cam_m;

void vertex() {
	mp = VERTEX;
	cam_m = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}

void fragment() {
	float u = clamp(UV.x, 0.0, 1.0);
	vec3 rd = normalize(mp - cam_m);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 sky = vec3(0.0);
	float fog = 0.0;
	for (int k = 0; k < 8; k++) {
		float dep = 0.006 + float(k) * 0.016;
		vec3 p = mp + rd * dep;
		// stars in this layer
		vec3 sp = p * 22.0 + float(k) * 17.0 + seed;
		vec3 cell = floor(sp);
		vec3 fp = fract(sp) - 0.5 - (vec3(h3(cell), h3(cell + 7.0), h3(cell + 13.0)) - 0.5) * 0.7;
		float on = step(0.8, h3(cell + 3.0));
		float tw = 0.55 + 0.45 * sin(TIME * (0.8 + h3(cell + 5.0) * 3.0) + h3(cell) * 30.0);
		vec3 sc = mix(vec3(0.65, 0.78, 1.0), vec3(1.0, 0.85, 0.62), h3(cell + 9.0));
		float d = length(fp);
		float star = (smoothstep(0.075, 0.0, d) * 7.0 + smoothstep(0.25, 0.0, d) * 0.5) * on * tw;
		// nebulae: soft clouds deep in the glass, slowly turning
		vec3 nq = p * 6.0 + seed + vec3(0.0, TIME * 0.015, 0.0);
		float neb = smoothstep(0.5, 0.85, fbm(nq)) * fbm(nq * 2.3 + 4.0);
		vec3 nc = mix(vec3(0.35, 0.08, 0.6), vec3(0.06, 0.3, 0.65), fbm(nq * 0.6 + 9.0));
		float vis = 1.0 - fog;
		sky += (sc * star * (1.0 - float(k) * 0.07) + nc * neb * 0.8) * vis;
		fog = min(1.0, fog + neb * 0.12 + 0.03);
	}
	// a falling star now and then, up the horn
	float fs = fract(TIME * 0.09 + seed * 0.1);
	float head = fs * 1.7 - 0.35;
	float streak = smoothstep(0.05, 0.0, abs(u - head)) * smoothstep(head - 0.3, head, u) * step(fs, 0.55);
	sky += vec3(1.0, 0.95, 0.85) * streak * smoothstep(0.5, 0.8, fbm(mp * 25.0 + seed)) * 3.0;
	// what lies behind, through the glass: bent, a little blurred, dimmed blue
	vec2 bend = NORMAL.xy * 0.035 * (1.0 - fres);
	vec3 behind = textureLod(screen, SCREEN_UV - bend, 1.5).rgb;
	vec3 glass = behind * vec3(0.2, 0.24, 0.4);
	// the root, where the horn grows out of the bone: frosted, less clear
	float root = 1.0 - smoothstep(0.02, 0.12, u);
	ALBEDO = vec3(0.004, 0.005, 0.012);
	EMISSION = (glass + sky) * mix(1.0, 0.4, root) * mix(0.4, 1.0, COLOR.r) + vec3(0.35, 0.5, 1.0) * fres * 0.35;
	ROUGHNESS = mix(0.04, 0.35, root);
	SPECULAR = 0.5;
	METALLIC = 0.0;
}
