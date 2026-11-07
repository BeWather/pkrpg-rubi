shader_type canvas_item;
// Fundido recursivo (bucle infinito) con suavizado senoidal desde el color
// de origen (#0000a5 por defecto) hacia el negro (#000000).
//
// IMPORTANTE: el efecto solo afecta a los píxeles cercanos al color de origen;
// el negro de las siluetas, blancos y cualquier tono distinto queda sin tocar:
//   - Dentro del sprite: se evalúa la distancia cromática entre el pixel y
//     `color_origen`. Si está dentro de `tolerancia`, se aplica el seno.
//     Si está lejos, se conserva el color original.
//   - Fuera del sprite: se conserva el color original intacto (transparencia).

// Color de origen sobre el que se aplica el fundido (azul Pokémon #0000a5)
uniform vec3 color_origen : source_color = vec3(0.0, 0.0, 0.647);
// Velocidad del ciclo en radianes/segundo (2π ≈ 1 ciclo/seg)
// 1.0 ≈ ciclo lento, 6.0 ≈ ciclo animado, 0.0 = congelado en color_origen
uniform float velocidad : hint_range(0.0, 20.0) = 2.0;
// Distancia máxima (en RGB) a la que un píxel se considera "del color de
// origen" y recibe el efecto. 0.1 deja pasar el azul puro y descarta el
// negro interno y otros tonos.
uniform float tolerancia : hint_range(0.01, 0.5) = 0.1;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Distancia cromática al color de origen (en RGB euclídeo).
	float dist = distance(tex.rgb, color_origen);

	// Máscara suave: 1.0 dentro de tolerancia, 0.0 fuera. El borde suave
	// (mitad del rango) evita cortes visibles entre el azul afectado y los
	// demás tonos del sprite.
	float mascara = 1.0 - smoothstep(
		tolerancia * 0.5,
		tolerancia,
		dist
	);

	// Suavizado senoidal: oscila en [0, 1] de forma continua.
	float t = 0.5 + 0.5 * sin(TIME * velocidad);

	// Color oscilante entre negro y color_origen, aplicado solo donde la
	// máscara es ≈ 1. En el resto, tex.rgb se conserva intacto.
	vec3 color_oscurecido = mix(vec3(0.0), color_origen, t);
	vec3 resultado = mix(tex.rgb, color_oscurecido, mascara);

	COLOR = vec4(resultado, tex.a);
}
