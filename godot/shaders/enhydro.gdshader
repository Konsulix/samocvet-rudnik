shader_type spatial;
// An enhydro's pocket (SpecimenBuilder: Enhydro), drawn after the crystal's glass and past its depth (the glass writes
// depth and draws the stone over what is inside it: the pocket was lost to a white smudge). As one sees them in quartz:
// the pocket (part 0) a long cavity outlined dark where its wall turns away, faintly watery inside; the bubble (part 1)
// a round bead with a thick dark rim — light bends off its edge — and a bright spot of light in it.
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_back;

uniform int part = 0;

void fragment() {
	float f = 1.0 - abs(dot(normalize(NORMAL), VIEW));   // 0 facing, 1 at the outline
	if (part == 0) {
		float rim = smoothstep(0.3, 0.8, f);
		ALBEDO = mix(vec3(0.55, 0.68, 0.76), vec3(0.05, 0.06, 0.08), rim);
		ALPHA = 0.16 + rim * 0.7;
	} else {
		float rim = smoothstep(0.25, 0.7, f);
		// a bright spot of light, up and to one side
		vec2 s = (NORMAL.xy - vec2(-0.3, 0.35));
		float spot = 1.0 - smoothstep(0.0, 0.32, length(s));
		ALBEDO = mix(vec3(0.82, 0.88, 0.92), vec3(0.04, 0.05, 0.06), rim) + vec3(1.0) * spot * 0.8;
		ALPHA = 0.55 + rim * 0.4;
	}
}
