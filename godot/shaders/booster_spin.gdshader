// The drill boosters' auger turning: a painted screw cannot be turned, but a screw turning looks like its threads
// running along it, so light and shade bands slanted like the threads run towards the tip over the steel.
// Only the auger is touched: past `split` along the axis, and only its grey steel (the motor is coloured paint).
shader_type canvas_item;

uniform vec2 axis = vec2(1.0, 0.0);   // which way the bit points in the sprite
uniform float split = 0.55;           // where the auger begins, along the axis (sprite UV)
uniform float pitch = 0.085;          // one thread, along the axis (UV)
uniform float slant = 0.55;           // how far a thread leans across the auger
uniform float speed = 9.0;            // threads a second
uniform float spin = 1.0;             // 0 standing still .. 1 full speed

void fragment() {
	vec4 c = COLOR;
	float along = dot(UV - 0.5, axis) + 0.5;
	float across = dot(UV - 0.5, vec2(-axis.y, axis.x));
	float sat = max(max(c.r, c.g), c.b) - min(min(c.r, c.g), c.b);
	float steel = smoothstep(split - 0.01, split + 0.02, along) * (1.0 - smoothstep(0.08, 0.14, sat));
	float ph = fract((along + across * slant) / pitch - TIME * speed);
	// a bright band, then a dark one: the thread's lit flank coming round, then its shadowed one
	float lit = smoothstep(0.0, 0.12, ph) * (1.0 - smoothstep(0.22, 0.42, ph));
	float dark = smoothstep(0.5, 0.65, ph) * (1.0 - smoothstep(0.8, 1.0, ph));
	float k = steel * spin;
	c.rgb *= 1.0 - dark * k * 0.35;
	c.rgb += lit * k * 0.3 * vec3(1.0, 0.96, 0.88);
	COLOR = c;
}
