shader_type canvas_item;
// The water of the Copper Mountain mill (its own layer, cut from the picture: the wet surface minus the dry one).
// Inside the falls' rectangles the colour runs down: it is read `shift` px higher, and what would come from above the
// lip wraps round by one period, so the lip has no seam; the silhouette (alpha) stays where it was drawn. Elsewhere
// (the pond, the pit) a slow ripple shifts the colour sideways and moonlit glints come and go. `on` lets the water in
// from the top (0: none, 1: all), for the moment the wheel is finished. Rectangles and lengths in texture px.

uniform vec4 falls0 = vec4(0.0);   // x0, y0, x1, y1
uniform vec4 falls1 = vec4(0.0);
uniform vec4 falls2 = vec4(0.0);
uniform float speed = 70.0;        // texture px a second
uniform float period = 28.0;
uniform float on = 1.0;
uniform vec4 tint : source_color = vec4(1.0);

bool inside(vec2 p, vec4 r) {
	return p.x >= r.x && p.x < r.z && p.y >= r.y && p.y < r.w;
}

vec3 fall(sampler2D tex, vec2 p, vec4 r, vec2 px) {
	float y = p.y - mod(TIME * speed, period);
	if (y < r.y) y += period;
	return texture(tex, vec2(p.x, y) * px).rgb;
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 p = UV / px;
	vec4 here = texture(TEXTURE, UV);
	vec3 col = here.rgb;
	if (inside(p, falls0)) col = fall(TEXTURE, p, falls0, px);
	else if (inside(p, falls1)) col = fall(TEXTURE, p, falls1, px);
	else if (inside(p, falls2)) col = fall(TEXTURE, p, falls2, px);
	else {
		float w = sin(p.y * 0.35 + TIME * 1.7) * 1.5 + sin(p.y * 0.11 - TIME * 0.9) * 1.0;
		col = texture(TEXTURE, UV + vec2(w * px.x, 0.0)).rgb;
		float g = sin(p.x * 0.09 + TIME * 2.3) * sin(p.y * 0.5 - TIME * 1.3);
		col += vec3(0.10, 0.14, 0.16) * smoothstep(0.85, 1.0, g);
	}
	float a = here.a * smoothstep(-0.02, 0.0, on - UV.y);
	COLOR = vec4(col * tint.rgb * COLOR.rgb, a * COLOR.a);
}
