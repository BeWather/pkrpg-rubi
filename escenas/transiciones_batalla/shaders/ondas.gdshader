shader_type canvas_item;
render_mode unshaded;

// B_TRANSITION_RIPPLE (Phase2_Transition_Ripple_Func2): ondas verticales. En el
// frame f: r4 = 0x400·f, r3 = (0x180·min(f, 22)) >> 8 (data2 deja de crecer al
// pasar de 0x1FFF) y VOFS(y) = Sin(((r4 + 384·y) & 0xFFFF) >> 8, r3).
#include "res://escenas/transiciones_batalla/shaders/seno_gba.gdshaderinc"

uniform sampler2D pantalla : hint_screen_texture, filter_nearest;
uniform float frame = 0.0;

void fragment() {
	ivec2 p = pixel_gba(SCREEN_UV, SCREEN_PIXEL_SIZE);
	int f = int(floor(frame + 0.001));
	int r4 = (1024 * f) & 65535;
	int r3 = (384 * min(f, 22)) >> 8;
	int vofs = sin_gba(((r4 + 384 * p.y) & 65535) >> 8, r3);
	ivec2 origen = ivec2(p.x, envolver(p.y + vofs, 160));
	COLOR = vec4(texture(pantalla, (vec2(origen) + 0.5) * SCREEN_PIXEL_SIZE).rgb, 1.0);
}
