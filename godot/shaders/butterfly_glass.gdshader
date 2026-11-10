// A glasswing's wings: clear panes between solid veins (butterfly.gdshaderinc, GLASS). Blended: drawn after the
// find's glass (render_priority set by SpecButterfly), it writes no depth so nothing behind it is lost.
shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque;
#define GLASS
#include "res://shaders/butterfly.gdshaderinc"
