shader_type canvas_item;
// Réplica del parpadeo de naming_screen.c: el color va de color_base a blanco con
// MultiplyInvertedPaletteRGBComponents(k * factor_canal).
// - Cursor de caracteres (sub_80B6998): factor (0.5, 1, 1) y semitransparente
//   con BLDALPHA = 0x80C (EVA 12/16, EVB 8/16).
// - Botones del menú (Task_80B64D4): factor (1, 1, 1) y opaco.
render_mode blend_premul_alpha;

uniform vec4 color_base : source_color = vec4(1.0, 0.0313725, 0.0313725, 1.0);
// Paso del parpadeo, de 0 a 16.
uniform float nivel : hint_range(0.0, 16.0, 1.0) = 0.0;
uniform vec3 factor_canal = vec3(0.5, 1.0, 1.0);
uniform bool semitransparente = true;

void fragment() {
	float mascara = step(0.5, texture(TEXTURE, UV).a);
	vec3 factores = floor(floor(nivel) * factor_canal);
	vec3 base5 = floor(color_base.rgb * 31.0 + 0.5);
	vec3 color5 = base5 + floor((31.0 - base5) * factores / 16.0);
	vec3 color = (color5 * 8.0 + floor(color5 / 4.0)) / 255.0;
	// Premultiplicado: salida = EVA * cursor + (1 - alfa) * fondo.
	vec4 salida = semitransparente ? vec4(color * (12.0 / 16.0), 8.0 / 16.0) : vec4(color, 1.0);
	COLOR = salida * mascara;
}
