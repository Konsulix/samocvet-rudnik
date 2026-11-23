shader_type canvas_item;
render_mode blend_add;
// A holographic sheen over the brass of a card whose stone has the northern lights (CardAurora), as on a shiny trading
// card. Two rims, each a sheen of its own (23.11: one band over a plain rectangle ran off the rounded corners): the
// card's own brass rim, a rounded rectangle; and the info panel's — the ribbon drawn by Reveal._info_rim, down the
// card's rim, round the panel's rounded top corners and across. On each a band of aurora colours — green, cyan, violet,
// pink — sweeps as the phone is tilted (`tilt`, from its gravity sensor; on a computer it drifts), fine diffraction
// lines in it, a glint at its heart. Added light, on the brass only. Lengths in the card's points.

uniform vec2 card = vec2(360.0, 640.0);
uniform float frame_in = 7.0;          // the card's brass rim: this wide
uniform float frame_r = 12.0;          // its corners' radius (outside)
// the ribbon (Reveal._info_rim): its middle line across the top, the two corners' centres and radii (ellipses), the
// sides' x down the card's rim, how far down they run; its width
uniform float rib_y = 400.0;
uniform vec2 rib_cl = vec2(30.0, 420.0);
uniform vec2 rib_cr = vec2(330.0, 420.0);
uniform vec2 rib_ax = vec2(20.0, 20.0);
uniform float rib_xl = 5.0;
uniform float rib_xr = 355.0;
uniform float rib_end = 470.0;
uniform float rib_w = 5.6;
uniform vec2 tilt = vec2(0.0);         // the phone's tilt (or the drift), -1..1 each way

vec3 spectrum(float x) {
	x = fract(x);
	vec3 a = vec3(0.1, 1.0, 0.45), b = vec3(0.2, 0.85, 1.0), c = vec3(0.6, 0.3, 1.0), d = vec3(1.0, 0.35, 0.65);
	if (x < 0.25) return mix(a, b, x * 4.0);
	if (x < 0.5) return mix(b, c, (x - 0.25) * 4.0);
	if (x < 0.75) return mix(c, d, (x - 0.5) * 4.0);
	return mix(d, a, (x - 0.75) * 4.0);
}
float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
// the sheen of one rim at a point: `d` the diagonal across the card, `shift` this rim's own place in the sweep
vec3 sheen(vec2 p, float d, float shift) {
	float band = fract(d * 0.9 + shift);
	float lit = smoothstep(0.0, 0.25, band) * (1.0 - smoothstep(0.35, 0.6, band));
	float glint = exp(-pow((band - 0.3) / 0.025, 2.0));
	float lines = 0.7 + 0.3 * sin((p.x + p.y) * 2.2 + d * 40.0);
	return spectrum(d * 2.5 + p.x * 0.004 + shift) * lit * lines * 0.85 + vec3(1.0) * glint * 0.7
		+ spectrum(d * 2.5 + 0.5 + shift) * 0.08;
}

void fragment() {
	vec2 p = UV * card;
	float d = (p.x / card.x * 0.7 + p.y / card.y * 0.55) + tilt.x * 0.6 + tilt.y * 0.45;
	// the card's rim: inside the rounded outline, as wide as the brass
	float sd = -sd_round_box(p - card * 0.5, card * 0.5, frame_r);
	float card_m = smoothstep(0.6, 1.6, sd) * smoothstep(frame_in + 0.3, frame_in - 1.0, sd);
	// the ribbon: its distance to the middle line, part by part
	float rd = 1e4;
	if (p.x >= rib_cl.x && p.x <= rib_cr.x) rd = abs(p.y - rib_y);
	if (p.y >= rib_cl.y && p.y <= rib_end) rd = min(rd, min(abs(p.x - rib_xl), abs(p.x - rib_xr)));
	vec2 ql = (p - rib_cl) / rib_ax;
	if (p.x < rib_cl.x && p.y < rib_cl.y) rd = min(rd, abs(length(ql) - 1.0) * min(rib_ax.x, rib_ax.y));
	vec2 qr = (p - rib_cr) / rib_ax;
	if (p.x > rib_cr.x && p.y < rib_cr.y) rd = min(rd, abs(length(qr) - 1.0) * min(rib_ax.x, rib_ax.y));
	float rib_m = 1.0 - smoothstep(rib_w * 0.35, rib_w * 0.55, rd);
	// (down the sides it runs over the card's rim, and fades out where the ribbon does)
	rib_m *= 1.0 - smoothstep(rib_end - 30.0, rib_end, p.y);
	if (card_m <= 0.0 && rib_m <= 0.0) discard;
	vec3 col = sheen(p, d, 0.0) * card_m;
	// the ribbon's own sheen: further along the sweep, a little quicker, so the two rims shine apart
	col = max(col, sheen(p, d * 1.25 + tilt.x * 0.2, 0.37) * rib_m);
	COLOR = vec4(col, 1.0);
}
