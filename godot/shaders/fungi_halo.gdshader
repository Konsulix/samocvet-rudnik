// The soft light round a glowing mushroom's cap (SpecFungi, the glowing mycena): one square to a cap, turned to the
// viewer, added over the picture — brightest in the middle, gone at the edge; it breathes with the cap (each its own
// beat, from the instance colour) and grows when the room goes dark.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 col = vec3(0.03, 0.5, 0.15);
uniform float power = 0.36;
global uniform float fluor_uv;

void vertex() {
	float sc = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sc, INV_VIEW_MATRIX[1] * sc, INV_VIEW_MATRIX[2] * sc, MODEL_MATRIX[3]);
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = pow(max(0.0, 1.0 - d), 2.4);
	float br = 0.82 + 0.18 * sin(TIME * 1.3 + COLOR.r * 20.0);
	ALBEDO = col * a * power * br * (1.0 + fluor_uv * 0.8);
}
