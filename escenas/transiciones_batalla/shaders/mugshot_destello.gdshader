shader_type canvas_item;
render_mode unshaded;

// Phase2_Mugshot_Func7: brillo (BLDCNT 0xBF) por línea que crece desde el centro.
// En la iteración k (k = f - 80; Func7 empieza en el frame 81) data4 = min(2·k, 80)
// y en las k impares las líneas 80 ± i con i <= data4 suben BLDY en 1 (máx. 16);
// la línea 80 se cuenta dos veces. Forma cerrada: n = nº de k impares en
// [max(1, ceil(i / 2)), k]. Aclarar hacia blanco BLDY/16 = blanco con alfa BLDY/16.

uniform float frame = 0.0;

void fragment() {
	ivec2 p = ivec2(floor(SCREEN_UV / SCREEN_PIXEL_SIZE));
	int k = int(floor(frame + 0.001)) - 80;
	int i = abs(p.y - 80);
	int a = max(1, (i + 1) / 2);
	int n = k >= a ? (k + 1) / 2 - a / 2 : 0;
	if (i == 0) {
		n *= 2;
	}
	COLOR = vec4(1.0, 1.0, 1.0, float(min(n, 16)) / 16.0);
}
