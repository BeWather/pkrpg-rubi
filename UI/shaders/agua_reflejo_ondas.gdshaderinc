// Reflejo de agua con ondas (modo ONDAS_SHADER de ReflexionesAgua), compartido
// por `agua_reflejo.gdshader` (semitransparente) y `reflejo_agua_fondo.gdshader`
// (opaco, lee el agua del backbuffer). Mismos uniforms y misma fórmula en ambos.

// Opacidad base del reflejo (0.0 - 1.0)
uniform float opacidad : hint_range(0.0, 1.0) = 0.55;

// Mezcla hacia blanco para el efecto pálido del GBA (0.0 = sin cambio, 1.0 = blanco puro)
uniform float paleness : hint_range(0.0, 1.0) = 0.30;

// Intensidad de la distorsión de ola
uniform float amplitud_ola : hint_range(0.0, 8.0) = 1.5;

// Velocidad de la animación de ola
uniform float velocidad_ola : hint_range(0.0, 5.0) = 1.2;

// Frecuencia horizontal de la ola
uniform float frecuencia_ola : hint_range(0.0, 20.0) = 6.0;

// Tinte de color (ligeramente azulado/gris para agua)
uniform vec4 color_tinte : source_color = vec4(0.78, 0.85, 0.90, 1.0);

// Color del reflejo con ondas: rgb pálido y tintado; alfa = alfa del texel ×
// `opacidad` (el modulate del nodo no interviene). El espejo vertical se hace
// aquí (el nodo va con flip_v = false).
vec4 calcular_reflejo_ondas(sampler2D textura, vec2 uv, float tiempo) {
	// Distorsión ondulante horizontal: cada fila se desplaza en X según una onda
	float ola = sin(uv.y * frecuencia_ola + tiempo * velocidad_ola) * (amplitud_ola / 256.0);
	vec2 uv_distorsionado = vec2(uv.x + ola, uv.y);

	// Invertir verticalmente para el efecto espejo
	uv_distorsionado.y = 1.0 - uv_distorsionado.y;

	vec4 color_original = texture(textura, uv_distorsionado);

	// Palidar: mezclar hacia blanco para simular el efecto GBA (Pokémon RS/Emerald)
	vec4 color_palido = mix(color_original, vec4(1.0, 1.0, 1.0, color_original.a), paleness);

	// Aplicar tinte de agua y opacidad
	vec4 resultado = color_palido * color_tinte;
	resultado.a = color_original.a * opacidad;
	return resultado;
}
