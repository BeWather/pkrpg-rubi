shader_type canvas_item;
render_mode unshaded;

// B_TRANSITION_WAVE (Phase2_Transition_Wave_Func2): ventana WIN0H por línea con
// borde izquierdo clamp(data1 + Sin((r5 + 4·y) & 255, 40), 0, 240), data1 = 8·(f+1)
// y r5 = 16·f; a la izquierda del borde (WINOUT = 0) todo es negro.
#include "res://escenas/transiciones_batalla/shaders/seno_gba.gdshaderinc"

uniform float frame = 0.0;

void fragment() {
	ivec2 p = pixel_gba(SCREEN_UV, SCREEN_PIXEL_SIZE);
	int f = int(floor(frame + 0.001));
	int borde = clamp(8 * (f + 1) + sin_gba(16 * f + 4 * p.y, 40), 0, 240);
	COLOR = vec4(0.0, 0.0, 0.0, p.x < borde ? 1.0 : 0.0);
}
