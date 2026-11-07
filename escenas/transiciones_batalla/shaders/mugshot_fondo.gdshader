shader_type canvas_item;
render_mode unshaded;

// Mugshots del Alto Mando (Phase2_Mugshot_Func3..7): BG0 con las bandas del rival
// (arriba) y del jugador (abajo), visible solo dentro de la ventana WIN0
// (WINOUT = 62: fuera se ve el mapa y los sprites, pero no BG0).
// - Frames 0-1 (Func1, Func2): ventana vacía.
// - Frames 2-31 (Func3, j = f - 2): líneas 0-79 [0, clamp(1 + 8·j + s)), líneas
//   80-159 [clamp(239 - 8·j - s), 240), con s = Sin((16·j + 16·y) & 255, 16).
// - Desde el frame 32 (Func4): ventana completa.
// Desplazamiento horizontal desde el frame 2: la mitad superior HOFS = -8·(f-1)
// (field_18) y la inferior +8·(f-1) (field_1A), envolviendo en 256.
#include "res://escenas/transiciones_batalla/shaders/seno_gba.gdshaderinc"

uniform sampler2D fondo : filter_nearest, repeat_disable;
uniform float frame = 0.0;

void fragment() {
	ivec2 p = pixel_gba(SCREEN_UV, SCREEN_PIXEL_SIZE);
	int f = int(floor(frame + 0.001));
	bool dentro = false;
	if (f >= 32) {
		dentro = true;
	} else if (f >= 2) {
		int j = f - 2;
		int s = sin_gba(16 * j + 16 * p.y, 16);
		if (p.y < 80) {
			int v = 1 + 8 * j + s;
			v = v < 0 ? 1 : min(v, 240);
			dentro = p.x < v;
		} else {
			int v = clamp(239 - 8 * j - s, 0, 239);
			dentro = p.x >= v;
		}
	}
	vec4 color = vec4(0.0);
	if (dentro) {
		int hofs = f >= 2 ? 8 * (f - 1) : 0;
		int x = envolver(p.y < 80 ? p.x - hofs : p.x + hofs, 256);
		color = texelFetch(fondo, ivec2(x, p.y), 0);
	}
	COLOR = color;
}
