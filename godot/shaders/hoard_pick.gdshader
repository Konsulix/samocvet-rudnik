shader_type canvas_item;
// The hoard's pixel turntable (Hoard): the frame as it is, with the geodes picked out through their mask
// (red = 20 x geode number): the ones the lens shows breathe in their rarity's colour, the chosen one is
// brighter and ringed in gold, and bursts white when it is cracked.

uniform sampler2D mask_tex : filter_nearest;
uniform int sel = 0;
uniform float flash = 0.0;
uniform vec4 lit[10];

int id_at(vec2 uv) {
	return int(round(texture(mask_tex, uv).r * 255.0 / 20.0));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	int id = id_at(UV);
	if (id > 0 && c.a > 0.5) {
		vec4 l = lit[id];
		if (l.a > 0.0) {
			float b = 0.5 + 0.5 * sin(TIME * 3.0 + float(id));
			c.rgb = mix(c.rgb, l.rgb, 0.3 + 0.25 * b) + l.rgb * 0.12 * b;
		}
		if (id == sel) {
			c.rgb *= 1.3 + 0.12 * sin(TIME * 6.0);
			c.rgb = mix(c.rgb, vec3(1.0), flash);
		}
	}
	// the chosen geode's rim: its own pixels next to any other
	if (sel > 0 && id == sel) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		if (id_at(UV + vec2(px.x, 0)) != sel || id_at(UV - vec2(px.x, 0)) != sel ||
			id_at(UV + vec2(0, px.y)) != sel || id_at(UV - vec2(0, px.y)) != sel) {
			c.rgb = mix(vec3(1.0, 0.82, 0.35), vec3(1.0), flash);
		}
	}
	COLOR = c;
}
