shader_type canvas_item;
// A slow diagonal glint that sweeps across every stone on the board, offset by where the stone is,
// so the whole tray catches the lamp light in a wave. Shadows and dark outlines are left alone.

uniform float speed = 0.28;
uniform float width = 0.03;
uniform float strength = 0.32;
uniform float boost = 1.0;   // >1 makes a stone bloom under the glow pass (used for specials)
uniform float mip_bias = 0.0;

varying vec2 wpos;
varying vec4 tint;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	tint = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV, mip_bias) * tint;
	float lum = max(c.r, max(c.g, c.b));
	float phase = fract((wpos.x * 0.8 + wpos.y) / 1100.0 - TIME * speed);
	float band = 1.0 - smoothstep(0.0, width, abs(phase - 0.5));
	float mask = smoothstep(0.18, 0.4, lum) * step(0.5, c.a);
	c.rgb = c.rgb * boost + vec3(band * strength * mask);
	COLOR = c;
}
