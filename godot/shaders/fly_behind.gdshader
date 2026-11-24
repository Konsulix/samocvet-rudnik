shader_type canvas_item;
// The card's butterflies that are still behind the skull (CardFlies): their own layer, cut by the stone's silhouette —
// the find drawn again, unshaded, on a clear background (`mask`: its alpha), where the stone's view lies in this layer
// (`view_rect`, points; `lsize` the layer's size) — so one coming out from behind the skull comes out from under it.

uniform sampler2D mask : filter_linear;
uniform vec4 view_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 lsize = vec2(1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 v = (UV * lsize - view_rect.xy) / view_rect.zw;
	float m = 0.0;
	if (v.x >= 0.0 && v.y >= 0.0 && v.x <= 1.0 && v.y <= 1.0) m = texture(mask, v).a;
	COLOR = vec4(c.rgb, c.a * (1.0 - smoothstep(0.15, 0.6, m)));
}
