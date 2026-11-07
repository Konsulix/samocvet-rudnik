// A butterfly's wings (SpecButterfly): the real wings of a museum specimen (assets/specimen/butterflies, cut by
// prototype/tools/skull/cut_butterfly.py), one card per side on a fine grid, so the wing can curve and bend as it beats.
// UV.x out from the body 0..1, UV.y along it 0 (head) .. 1; the left side is the right one mirrored (VERTEX.z < 0).
// The script drives the stroke (ang, flex) — see SpecButterfly.Fly.
shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/opal.gdshaderinc"

uniform sampler2D wing : source_color, filter_linear_mipmap, repeat_disable;
uniform float ang = 0.0;       // the wings' angle at the root, up off flat (π/2: closed up over the back)
uniform float flex = 0.0;      // how far the outer wing lags the stroke (+ bent up, - bent down)
uniform float curve = 0.25;    // the wing cups a little
uniform float iri = 0.0;       // morpho: the blue flashes with the angle
uniform float glass = 0.0;     // see-through wings: alpha read as how solid
uniform float seed = 0.0;

varying float side;

void vertex() {
	side = sign(VERTEX.z);
	float u = UV.x;
	// the root angle, the tip lagging behind the stroke (the wing is a flexible sail), cupped a little;
	// the hindwing (the back of the card) trails the forewing by a hair
	float a = ang + flex * u * u * (1.0 + UV.y * 0.3) + u * curve * 0.25;
	a = min(a, 1.62);
	a *= side;
	float r = abs(VERTEX.z);
	VERTEX = vec3(VERTEX.x, r * sin(abs(a)), r * cos(a) * side);
	NORMAL = normalize(vec3(0.0, cos(a), -sin(abs(a)) * side));
}

void fragment() {
	// (the card's own edge: nothing but wing — a wrapped or clamped texel there drew dashes along the card)
	if (UV.x > 0.985 || UV.y < 0.012 || UV.y > 0.988) discard;
	vec4 t = texture(wing, UV);
	if (glass > 0.0) {
		// the membrane mostly clear (a faint film of it left), the veins, rim and eyespot solid
		if (h3(vec3(FRAGCOORD.xy, seed)) > 0.12 + smoothstep(0.4, 0.8, t.a) * 0.9) discard;
	} else if (t.a < 0.5) discard;
	vec3 c = t.rgb;
	float face = abs(dot(NORMAL, VIEW));
	// the scales: the photo's own fine detail (veins, rows of scales, worn patches) pressed in as relief, and its
	// contrast kept up so the mipmapped picture does not go flat on a small wing
	float lum = dot(c, vec3(0.3, 0.55, 0.15));
	float lum_s = dot(textureLod(wing, UV, 2.5).rgb, vec3(0.3, 0.55, 0.15));
	c = max(c + (c - textureLod(wing, UV, 2.5).rgb) * 0.6, vec3(0.0));
	float rows = 0.5 + 0.5 * sin((UV.x * 1.0 + UV.y * 0.15) * 900.0 + vn(vec3(UV * 120.0, seed)) * 3.0);
	float h = (lum - lum_s) * 1.5 + rows * 0.08;
	vec3 n = bump(NORMAL, VERTEX, h * 0.0015, 1.0);
	if (iri > 0.0) {
		// structural blue: the photo's blue, flashing deeper and brighter where the scales face the eye, going
		// violet-dark as they turn away — never washed to white
		float blue = smoothstep(0.08, 0.3, c.b - c.r);
		float f = pow(face, 1.5);
		c = mix(c, c * mix(vec3(0.35, 0.25, 0.9), vec3(0.8, 1.05, 1.25), f), blue * iri);
		EMISSION = vec3(0.02, 0.12, 0.45) * blue * iri * f * f * 0.5;
	}
	// the underside, seen when it flies over: duller (a real one is dusky beneath), and not lit as the top
	if (!FRONT_FACING) c *= 0.55;
	// (the find studio lights hard: a photo of a wing lit again would wash out — keep it near its own tone)
	c *= 0.72;
	ALBEDO = c;
	NORMAL = n;
	// (matte scales: a glossy wing mirrored the bright studio and went white)
	ROUGHNESS = 0.9;
	SPECULAR = iri > 0.0 ? 0.08 : 0.04;
	// thin: the light comes through from behind
	BACKLIGHT = c * (0.15 + glass * 0.5);
}
