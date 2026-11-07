shader_type canvas_item;
// Desplazamiento rígido del fondo en una dirección configurable.
//
// El flujo va en la dirección marcada por `direccion` (0 rad = hacia arriba
// en pantalla) con rapidez `velocidad`. Además, se aplica una onda horizontal
// cuya magnitud depende solo de la altura: todos los píxeles de una misma
// fila reciben el mismo desplazamiento en X.
//
// Parámetros:
// - velocidad : rapidez del flujo en UV/segundo (0 = sin scroll).
// - amplitud  : desplazamiento horizontal máximo de la onda, en UV.
// - direccion : ángulo del flujo en radianes (0 = hacia arriba).

uniform float velocidad : hint_range(0.0, 2.0) = 0.1;
uniform float amplitud : hint_range(0.0, 0.5) = 0.03;
uniform float direccion : hint_range(-3.14159, 3.14159) = 0.0;

void fragment() {
	// Vector de flujo. Para `direccion = 0` queda (0, -1), que en el
	// espacio UV de Godot (V crece hacia abajo) equivale a "hacia arriba".
	vec2 dir = vec2(sin(direccion), -cos(direccion));
	// vec2 dir = vec2(cos(direccion), sin(direccion));

	// Para mover visualmente la textura en la dirección indicada hay que
	// muestrear la fuente en la dirección opuesta.
	vec2 uv_desplazado = UV - dir * velocidad * TIME;

	// La onda usa solo UV.y, nunca UV.x. Por eso el desplazamiento horizontal
	// es idéntico en toda una fila y no altera las distancias sobre el eje X.
	float desplazamiento_horizontal = sin(UV.y * 6.0 + TIME * 2.0) * amplitud;
	uv_desplazado.x += desplazamiento_horizontal;

	// El patrón debe repetirse al superar los límites de la textura. Sin
	// este envoltorio, el muestreo queda fijado al píxel del borde y toda la
	// pantalla acaba mostrando un único color.
	vec2 uv_envuelta = fract(uv_desplazado);

	vec4 tex = texture(TEXTURE, uv_envuelta);
	// Aplica únicamente la modulación alfa del Sprite2D; conserva intacto
	// el color RGB original de la textura.
	COLOR = vec4(tex.rgb, tex.a * COLOR.a);
}
