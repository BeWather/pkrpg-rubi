shader_type canvas_item;
// Destello de la ESFERA (pokeruby field_screen_effect.c, sub_80816A8): BG0 lleno de un color se mezcla con la
// escena (BLDCNT de primer objetivo BG0, REG_BLDALPHA eva/evb) solo dentro de una ventana circular de `radio` px
// alrededor de `centro` (SetFlashScanlineEffectWindowBoundaries); fuera, la escena tal cual.
// resultado = min(1, color * eva + escena * evb), como mezcla_gba.gdshader.
uniform sampler2D pantalla : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec4 color_esfera : source_color = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 centro = vec2(312.0, 240.0);
uniform float radio = 0.0;
uniform float eva : hint_range(0.0, 1.0) = 0.75;
uniform float evb : hint_range(0.0, 1.0) = 0.4375;

void fragment() {
	vec3 escena = texture(pantalla, SCREEN_UV).rgb;
	vec2 pixel = SCREEN_UV / SCREEN_PIXEL_SIZE;
	if (distance(pixel, centro) > radio) {
		COLOR = vec4(escena, 1.0);
	} else {
		COLOR = vec4(min(color_esfera.rgb * eva + escena * evb, vec3(1.0)), 1.0);
	}
}
