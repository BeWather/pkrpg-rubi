shader_type canvas_item;
// Barrido de brillo ("shine") que cruza el logo en diagonal: una banda fina
// adelante y una banda gruesa detrás, como el destello del logo de Pokémon.
// Solo ilumina los píxeles opacos del logo: el fondo negro y la transparencia
// no cambian. Se controla con un único uniform `progress`:
// 0.0 = bandas antes del logo · 0.5 = cruzando el centro · 1.0 = ya salieron.

// Posición del barrido (animar con AnimationPlayer o Tween)
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// Color del destello
uniform vec4 color_brillo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Ancho de la banda fina y de la banda gruesa (en unidades de UV)
uniform float ancho_fino = 0.018;
uniform float ancho_grueso = 0.065;
// Cuánto brillo se suma al color original
uniform float intensidad : hint_range(0.0, 2.0) = 0.75;
// Inclinación de las bandas: 0.2 casi vertical · 0.5 media · 0.8 muy tendida
uniform float inclinacion : hint_range(0.0, 1.0) = 0.45;

// Máscara de banda suave: 1.0 en el centro, 0.0 fuera del ancho.
// El borde suave es corto (ancho * 1.4) para conservar el aspecto pixel art.
float banda(float posicion, float centro, float ancho) {
	return 1.0 - smoothstep(ancho, ancho * 1.4, abs(posicion - centro));
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Respetar la transparencia: el efecto solo vive dentro del logo
	// (máscara 1.0 dentro de los píxeles opacos, 0.0 fuera; equivalente
	// a un return temprano, que no está permitido en fragment())
	float dentro_logo = step(0.01, tex.a);

	// Coordenada diagonal: define el ángulo del barrido
	float diagonal = UV.x + UV.y * inclinacion;

	// La banda fina va primero; la gruesa la sigue, un poco atrás,
	// para que no parezcan dos líneas pegadas
	float centro_fino = progress * 1.8 - 0.4;
	// float centro_grueso = progress * 1.8 - 0.52;
	float centro_grueso = progress * 1.8 - 0.47;

	float fino = banda(diagonal, centro_fino, ancho_fino);
	float grueso = banda(diagonal, centro_grueso, ancho_grueso);

	// El núcleo fino domina; la banda gruesa acompaña con menos peso
	// float brillo = max(fino, grueso * 0.55) * dentro_logo;
	float brillo = max(fino, grueso) * dentro_logo;

	vec3 color_final = tex.rgb + color_brillo.rgb * brillo * intensidad;
	COLOR = vec4(color_final, tex.a);
}
