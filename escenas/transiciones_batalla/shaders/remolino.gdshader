shader_type canvas_item;
render_mode unshaded;

// B_TRANSITION_SWIRL (Phase2_Transition_Swirl_Func2): cada línea desplaza el
// mapa en horizontal HOFS(y) = Sin((data1 + 2·y) & 255, data2), con data1 = 4·f y
// data2 = 8·f en el frame f (el frame 0 es Func1, sin desplazamiento).
#include "res://escenas/transiciones_batalla/shaders/seno_gba.gdshaderinc"

uniform sampler2D pantalla : hint_screen_texture, filter_nearest;
uniform float frame = 0.0;

void fragment() {
	ivec2 p = pixel_gba(SCREEN_UV, SCREEN_PIXEL_SIZE);
	int f = int(floor(frame + 0.001));
	int hofs = f >= 1 ? sin_gba(4 * f + 2 * p.y, 8 * f) : 0;
	ivec2 origen = ivec2(envolver(p.x + hofs, 240), p.y);
	COLOR = vec4(texture(pantalla, (vec2(origen) + 0.5) * SCREEN_PIXEL_SIZE).rgb, 1.0);
}
