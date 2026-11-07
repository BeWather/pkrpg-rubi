shader_type canvas_item;
render_mode unshaded;

// B_TRANSITION_SHUFFLE (Phase2_Transition_Shuffle_Func2): cada línea desplaza el
// mapa en vertical. En el frame f >= 1 (j = f - 1): r4 = 4224·j, r3 = 384·j >> 8 y
// VOFS(y) = Sin(((r4 + 4224·y) & 0xFFFF) / 256, r3).
#include "res://escenas/transiciones_batalla/shaders/seno_gba.gdshaderinc"

uniform sampler2D pantalla : hint_screen_texture, filter_nearest;
uniform float frame = 0.0;

void fragment() {
	ivec2 p = pixel_gba(SCREEN_UV, SCREEN_PIXEL_SIZE);
	int f = int(floor(frame + 0.001));
	int vofs = 0;
	if (f >= 1) {
		int j = f - 1;
		int r4 = (4224 * j) & 65535;
		int r3 = (384 * j) >> 8;
		vofs = sin_gba(((r4 + 4224 * p.y) & 65535) >> 8, r3);
	}
	ivec2 origen = ivec2(p.x, envolver(p.y + vofs, 160));
	COLOR = vec4(texture(pantalla, (vec2(origen) + 0.5) * SCREEN_PIXEL_SIZE).rgb, 1.0);
}
