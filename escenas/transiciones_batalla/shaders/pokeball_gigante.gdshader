shader_type canvas_item;
render_mode unshaded;

// B_TRANSITION_BIG_POKEBALL (Phase2_Transition_BigPokeball_Func1..6).
// - BG0 = la Poké Ball gigante (fondo de 256 de ancho que envuelve; las columnas
//   240-255 están vacías), ondulada en horizontal: en el frame f (1..64)
//   HOFS(y) = Sin((8·f + 132·y) & 255, 64 - f) (data4 += 8, data5 -= 256).
// - BLDCNT 0x3F41: donde la bola es opaca, min(1, bola·EVA/16 + debajo·EVB/16);
//   fuera de la bola se ve el mapa sin cambios.
// - Func6: iris circular de radio `radio` centrado en (120, 80); fuera, negro.

uniform sampler2D pantalla : hint_screen_texture, filter_nearest;
uniform sampler2D bola : filter_nearest, repeat_disable;
uniform float frame = 0.0;
uniform float eva = 0.0;
uniform float evb = 16.0;
uniform float radio = 160.0;

#include "res://escenas/transiciones_batalla/shaders/seno_gba.gdshaderinc"

void fragment() {
	ivec2 p = pixel_gba(SCREEN_UV, SCREEN_PIXEL_SIZE);
	vec3 debajo = texture(pantalla, (vec2(p) + 0.5) * SCREEN_PIXEL_SIZE).rgb;
	int f = int(floor(frame + 0.001));
	int hofs = (f >= 1 && f <= 64) ? sin_gba(8 * f + 132 * p.y, 64 - f) : 0;
	int bx = envolver(p.x + hofs, 256);
	vec4 texel = bx < 240 ? texelFetch(bola, ivec2(bx, p.y), 0) : vec4(0.0);
	vec3 color = debajo;
	if (texel.a > 0.5) {
		color = min(vec3(1.0), texel.rgb * floor(eva + 0.001) / 16.0 + debajo * floor(evb + 0.001) / 16.0);
	}
	vec2 centro = vec2(p) + 0.5 - vec2(120.0, 80.0);
	float r = floor(radio + 0.001);
	if (dot(centro, centro) >= r * r) {
		color = vec3(0.0);
	}
	COLOR = vec4(color, 1.0);
}
