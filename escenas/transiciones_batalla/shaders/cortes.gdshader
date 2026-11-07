shader_type canvas_item;
render_mode unshaded;

// B_TRANSITION_SLICE (Phase2_Transition_Slice_Func2): con d = `desplazamiento`
// (data1), las líneas impares llevan HOFS = +d y solo se ven en x < 240 - d; las
// pares HOFS = -d y solo en x >= d. Fuera de la ventana (WINOUT = 0), negro.

uniform sampler2D pantalla : hint_screen_texture, filter_nearest;
uniform float desplazamiento = 0.0;

void fragment() {
	ivec2 p = ivec2(floor(SCREEN_UV / SCREEN_PIXEL_SIZE));
	int d = int(floor(desplazamiento + 0.001));
	bool impar = (p.y & 1) == 1;
	bool visible = impar ? p.x < 240 - d : p.x >= d;
	ivec2 origen = ivec2(impar ? p.x + d : p.x - d, p.y);
	vec3 color = texture(pantalla, (vec2(origen) + 0.5) * SCREEN_PIXEL_SIZE).rgb;
	COLOR = vec4(visible ? color : vec3(0.0), 1.0);
}
