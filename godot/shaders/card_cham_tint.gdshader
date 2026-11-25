shader_type canvas_item;
// The chameleon's colour on its card (CardChameleon): what is under this layer — the info panel's slate (mode 0) or the
// card's brass, its rim and the panel's ribbon (mode 1) — takes the colour of the moment, keeping its own light and
// dark. A change spreads from the chameleon's corner (`src`) as a ring of radius `rad`: the old colour outside it, the
// new inside, a bright edge on it. Lengths in points (the card's, or the panel's in mode 0).

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform int mode = 0;
uniform vec2 rsize = vec2(360.0, 640.0);
uniform vec3 col_a : source_color = vec3(0.1, 0.45, 0.12);
uniform vec3 col_b : source_color = vec3(0.1, 0.45, 0.12);
uniform vec2 src = vec2(360.0, 400.0);
uniform float rad = 9999.0;
uniform float k = 0.5;
// mode 1: the brass (as card_aurora_foil.gdshader's)
uniform float frame_in = 7.0;
uniform float frame_r = 12.0;
uniform float rib_y = 400.0;
uniform vec2 rib_cl = vec2(30.0, 420.0);
uniform vec2 rib_cr = vec2(330.0, 420.0);
uniform vec2 rib_ax = vec2(20.0, 20.0);
uniform float rib_xl = 5.0;
uniform float rib_xr = 355.0;
uniform float rib_end = 470.0;
uniform float rib_w = 5.6;
// mode 0: the panel's rounded top corners
uniform float pan_r = 18.0;

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = UV * rsize;
	float m = 1.0;
	if (mode == 1) {
		float sd = -sd_round_box(p - rsize * 0.5, rsize * 0.5, frame_r);
		float card_m = smoothstep(0.6, 1.6, sd) * smoothstep(frame_in + 0.3, frame_in - 1.0, sd);
		float rd = 1e4;
		if (p.x >= rib_cl.x && p.x <= rib_cr.x) rd = abs(p.y - rib_y);
		if (p.y >= rib_cl.y && p.y <= rib_end) rd = min(rd, min(abs(p.x - rib_xl), abs(p.x - rib_xr)));
		vec2 ql = (p - rib_cl) / rib_ax;
		if (p.x < rib_cl.x && p.y < rib_cl.y) rd = min(rd, abs(length(ql) - 1.0) * min(rib_ax.x, rib_ax.y));
		vec2 qr = (p - rib_cr) / rib_ax;
		if (p.x > rib_cr.x && p.y < rib_cr.y) rd = min(rd, abs(length(qr) - 1.0) * min(rib_ax.x, rib_ax.y));
		float rib_m = (1.0 - smoothstep(rib_w * 0.35, rib_w * 0.6, rd)) * (1.0 - smoothstep(rib_end - 30.0, rib_end, p.y));
		m = max(card_m, rib_m);
	} else {
		// the panel, its top corners rounded, its bottom ones the card's
		vec2 q = p;
		if (q.y < pan_r && (q.x < pan_r || q.x > rsize.x - pan_r)) {
			vec2 c = vec2(q.x < pan_r ? pan_r : rsize.x - pan_r, pan_r);
			m = 1.0 - smoothstep(pan_r - 1.0, pan_r, length(q - c));
		}
	}
	if (m <= 0.0) discard;
	vec3 under = texture(screen, SCREEN_UV).rgb;
	float d = length(p - src);
	float inside = 1.0 - smoothstep(rad - 14.0, rad, d);
	float edge = exp(-pow((d - rad) / 9.0, 2.0)) * step(rad, 2000.0);
	vec3 col = mix(col_a, col_b, inside);
	float lum = dot(under, vec3(0.3, 0.59, 0.11));
	vec3 tinted = mode == 1 ? lum * col * 2.3 : under * 0.55 + col * (0.12 + lum * 0.9);
	tinted += col * edge * (mode == 1 ? 0.9 : 0.35);
	COLOR = vec4(tinted, m * k);
}
