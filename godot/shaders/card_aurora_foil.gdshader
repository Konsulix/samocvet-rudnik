shader_type canvas_item;
render_mode blend_add;
// A holographic sheen over the brass of a card whose stone has the northern lights (CardAurora), as on a shiny trading
// card: on the card's rim and the ribbon over its info panel a band of aurora colours — green, cyan, violet, pink —
// sweeps across as the phone is tilted (`tilt`, from its gravity sensor; on a computer it drifts by itself), with fine
// diffraction lines in it and a glint where it crosses. Added light, on the brass only. Lengths in the card's points.

uniform vec2 card = vec2(360.0, 640.0);
uniform float frame_in = 7.0;          // the card's brass rim
uniform float rim_top = 400.0;         // the ribbon over the info panel
uniform float rim_bot = 406.0;
uniform float rim_l = 30.0;
uniform float rim_r = 330.0;
uniform vec2 tilt = vec2(0.0);         // the phone's tilt (or the drift), -1..1 each way

vec3 spectrum(float x) {
	// round the aurora's colours: green, cyan, violet, pink and back
	x = fract(x);
	vec3 a = vec3(0.1, 1.0, 0.45), b = vec3(0.2, 0.85, 1.0), c = vec3(0.6, 0.3, 1.0), d = vec3(1.0, 0.35, 0.65);
	if (x < 0.25) return mix(a, b, x * 4.0);
	if (x < 0.5) return mix(b, c, (x - 0.25) * 4.0);
	if (x < 0.75) return mix(c, d, (x - 0.5) * 4.0);
	return mix(d, a, (x - 0.75) * 4.0);
}

void fragment() {
	vec2 p = UV * card;
	float e = min(min(p.x, card.x - p.x), min(p.y, card.y - p.y));
	float brass = smoothstep(0.6, 1.8, e) * smoothstep(frame_in + 0.3, frame_in - 1.0, e);
	float ribbon = (1.0 - smoothstep(0.0, (rim_bot - rim_top) * 0.5 + 0.8, abs(p.y - (rim_top + rim_bot) * 0.5)))
		* step(rim_l - 26.0, p.x) * step(p.x, rim_r + 26.0);
	float metal = max(brass, ribbon);
	if (metal <= 0.0) discard;
	// the diagonal across the card, shifted by the tilt
	float d = (p.x / card.x * 0.7 + p.y / card.y * 0.55) + tilt.x * 0.6 + tilt.y * 0.45;
	// the sheen: a broad band of colour, brightest at its middle, a thin white glint at its heart
	float band = fract(d * 0.9);
	float lit = smoothstep(0.0, 0.25, band) * (1.0 - smoothstep(0.35, 0.6, band));
	float glint = exp(-pow((band - 0.3) / 0.025, 2.0));
	// fine diffraction lines in the foil
	float lines = 0.7 + 0.3 * sin((p.x + p.y) * 2.2 + d * 40.0);
	vec3 col = spectrum(d * 2.5 + p.x * 0.004) * lit * lines * 0.85 + vec3(1.0) * glint * 0.7;
	// and always a little colour on the brass, as foil never quite loses it
	col += spectrum(d * 2.5 + 0.5) * 0.08;
	COLOR = vec4(col * metal, 1.0);
}
