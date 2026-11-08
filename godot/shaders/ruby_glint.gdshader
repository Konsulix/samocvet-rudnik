shader_type canvas_item;
render_mode blend_add;
// The glint on a boss's ruby on the atlas board (AtlasBoard.Glints): drawn over the ruby sprite, added.
// A light band sweeps across the stone with the board's movement (phase), brighter on the light facets; when it
// crosses the stone's point a small four-ray star flashes. COLOR.r carries the ruby's own offset (they don't all
// flash at once); the sprite's own colour is not used.
uniform float phase = 0.0;

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float p = fract(phase + COLOR.r);
	float s = p * 2.2 - 0.6;                       // the band's place along the diagonal, -0.6..1.6
	float x = (UV.x + UV.y) * 0.5;
	float band = smoothstep(0.13, 0.0, abs(x - s));
	float lum = dot(t.rgb, vec3(0.3, 0.59, 0.11));
	// only on the stone (red), not on the brass round it
	float red = smoothstep(0.25, 0.45, t.r - max(t.g, t.b));
	vec3 c = mix(vec3(1.0, 0.3, 0.32), vec3(1.0, 0.92, 0.9), lum) * band * t.a * red * (0.5 + lum) * 1.3;
	// the star at the point, when the band is on it
	vec2 d = UV - vec2(0.5, 0.5);
	float ray = smoothstep(0.018, 0.0, abs(d.x)) * smoothstep(0.32, 0.0, abs(d.y))
		+ smoothstep(0.018, 0.0, abs(d.y)) * smoothstep(0.32, 0.0, abs(d.x));
	float core = smoothstep(0.09, 0.0, length(d));
	float flash = smoothstep(0.16, 0.0, abs(s - 0.5));
	c += vec3(1.0, 0.92, 0.92) * (ray * 0.9 + core * 0.8) * flash;
	COLOR = vec4(c, 1.0);
}
