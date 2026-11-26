shader_type canvas_item;
// The card's jellyfish still under the stone (CardJelly): its own layer, its light added to the card (as add_rgb), but
// cut by the stone's silhouette — the find drawn again, unshaded, on a clear background (`mask`: its alpha), where the
// stone's view lies in this layer (`view_rect`, points; `lsize` the layer's size) — so it comes out from under the stone
// (as the butterflies from under the skull: fly_behind.gdshader).
render_mode blend_add;

uniform sampler2D mask : filter_linear;
uniform vec4 view_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 lsize = vec2(1.0);

void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	vec2 v = (UV * lsize - view_rect.xy) / view_rect.zw;
	float m = 0.0;
	if (v.x >= 0.0 && v.y >= 0.0 && v.x <= 1.0 && v.y <= 1.0) m = texture(mask, v).a;
	// (glass is drawn see-through in the mask: any of the stone hides it — a jelly showed over the crystal's edge)
	COLOR = vec4(c * (1.0 - smoothstep(0.02, 0.14, m)), 1.0);
}
