shader_type canvas_item;
render_mode unshaded;

// B_TRANSITION_WHITEFADE (sub_811CFD0): 8 bandas de 20 líneas; la banda i empieza
// RETRASOS[i] frames después del frame 1. Con k = frames desde que empezó (máx.
// 32): fuera de la ventana, x >= max(240 - 16·k, 0), el brillo (BLDCNT modo 10)
// vale BLDY = min(128·k >> 8, 16), es decir, mezcla hacia blanco BLDY/16.

uniform float frame = 0.0;

const int RETRASOS[8] = { 0, 20, 15, 40, 10, 25, 35, 5 };

void fragment() {
	ivec2 p = ivec2(floor(SCREEN_UV / SCREEN_PIXEL_SIZE));
	int f = int(floor(frame + 0.001));
	int banda = clamp(p.y / 20, 0, 7);
	int k = f - 1 - RETRASOS[banda];
	float brillo = 0.0;
	if (k >= 0) {
		k = min(k, 32);
		int derecha = max(240 - 16 * k, 0);
		if (p.x >= derecha) {
			brillo = float(min((128 * k) >> 8, 16)) / 16.0;
		}
	}
	COLOR = vec4(1.0, 1.0, 1.0, brillo);
}
