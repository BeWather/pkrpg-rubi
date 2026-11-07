shader_type canvas_item;
render_mode unshaded;

uniform sampler2D indices : filter_nearest, repeat_disable;
uniform float paleta[16];
uniform float mezcla = 1.0;
uniform float fondo = 0.0;

void fragment() {
	vec2 pixel = (floor(UV * vec2(240.0, 160.0)) + 0.5) / vec2(240.0, 160.0);
	int indice = int(round(texture(indices, pixel).r * 15.0));
	// El índice 0 del BG es transparente: muestra el backdrop, no la paleta.
	float gris = indice == 0 ? fondo : min(paleta[indice] * mezcla + fondo, 1.0);
	COLOR = vec4(vec3(gris), 1.0);
}
