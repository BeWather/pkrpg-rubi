shader_type canvas_item;

// Fondo de partículas del movimiento de campo (MO / Golpe Roca, Corte, etc.).
// Tres funciones:
//   1. Scroll continuo hacia la derecha, reciclando por la izquierda.
//   2. Transición de entrada (progreso_entrada 0 → 1).
//   3. Transición de salida (progreso_salida 0 → 1).
// Ambos progresos están pensados para animarse como pistas del AnimationPlayer:
//   CapaMovCampo/MoveFieldParticle:material:shader_parameter/progreso_entrada
//   CapaMovCampo/MoveFieldParticle:material:shader_parameter/progreso_salida
// Dos variantes, como FLDEFF_FIELD_MOVE_SHOW_MON de Rubí (field_effect.c):
//   - Exterior (sub_8088120): corte de derecha a izquierda + apertura vertical
//     desde el centro; al salir se cierra en vertical hacia el centro.
//   - Interior (sub_808847C, cuevas/edificios; `modo_interior`): sin apertura
//     vertical; la franja de alto completo crece desde el borde izquierdo hacia
//     la derecha y al salir se borra desde la izquierda (se va por la derecha).
// Los progresos son lineales en frames de Rubí (ver cada rama): las animaciones
// mov_campo_inicio y mov_campo_inicio_interior fijan cuántos frames dura cada uno.

// Scroll: 240 px en 15 frames a 60 fps = 16 px por frame lógico.
// Avanza a saltos de píxel entero para mantener el pixel art nítido.
uniform float desplazamiento_px_frame = 16.0;
uniform float fps_logico = 60.0;

// 0 = todo invisible, 1 = todo visible.
// Un corte vertical va de derecha a izquierda (se dibuja lo que queda a su derecha)
// y dos referencias horizontales se abren desde el centro hacia los bordes.
uniform float progreso_entrada : hint_range(0.0, 1.0) = 1.0;

// 0 = todo visible, 1 = todo invisible.
// Las dos referencias horizontales vuelven desde los bordes hacia el centro.
uniform float progreso_salida : hint_range(0.0, 1.0) = 0.0;

// false = variante exterior (rutas, ciudades); true = interior (cuevas, edificios).
uniform bool modo_interior = false;

// Ancho visible de la pantalla del GBA (la textura mide 256, como el mapa de BG).
const float ANCHO_PANTALLA = 240.0;
// sub_8088228: la ventana se abre 2 px por frame arriba y abajo hasta 40 px
// (20 frames); progreso_entrada = frame / 20.
const float FRAMES_APERTURA_EXTERIOR = 20.0;

// En fragment() COLOR ya viene multiplicado por texture(TEXTURE, UV) (sin desplazar),
// así que el color del vértice (modulate) se guarda aquí y se aplica a la muestra desplazada.
varying vec4 color_vertice;

void vertex() {
	color_vertice = COLOR;
}

void fragment() {
	vec2 tam = vec2(textureSize(TEXTURE, 0));
	// Índice de píxel (0..ancho-1, 0..alto-1) y su centro para comparar con los cortes.
	vec2 px = floor(UV * tam);
	vec2 centro = px + 0.5;
	float mitad_y = tam.y * 0.5;

	if (modo_interior) {
		// Entrada (sub_8088708, 16 frames; progreso = frame / 16): cada frame se
		// copian 2 columnas de tiles (16 px) del mapa de 256 px mientras el fondo
		// avanza 16 px a la derecha, así que lo copiado ocupa [16, 16 + 256·p) y
		// los 16 px de la izquierda no se llenan hasta la última copia (p = 1).
		// Salida (sub_80887C0, 16 frames): cada frame se borran las 2 columnas
		// que entran por la izquierda: borrado [0, 256·p).
		float hueco = progreso_entrada < 1.0 ? desplazamiento_px_frame : 0.0;
		float frente_entrada = progreso_entrada < 1.0 ? hueco + tam.x * progreso_entrada : tam.x;
		float frente_salida = tam.x * progreso_salida;
		if (centro.x < hueco || centro.x >= frente_entrada || centro.x < frente_salida) {
			discard;
		}
	} else {
		// --- Entrada (sub_8088228) ---
		// El borde izquierdo de WIN0 baja 16 px por frame desde 240 (llega a 0
		// en el frame 15) mientras la apertura vertical sigue hasta el 20.
		float corte_x = max(0.0, ANCHO_PANTALLA - desplazamiento_px_frame * FRAMES_APERTURA_EXTERIOR * progreso_entrada);
		float sup_entrada = mix(mitad_y, 0.0, progreso_entrada);
		float inf_entrada = mix(mitad_y, tam.y, progreso_entrada);

		// --- Salida (sub_80882E4) ---
		// 6 px por frame por lado: progreso = 0,15 por frame (1 en el frame 7).
		float sup_salida = mix(0.0, mitad_y, progreso_salida);
		float inf_salida = mix(tam.y, mitad_y, progreso_salida);

		float sup = max(sup_entrada, sup_salida);
		float inf = min(inf_entrada, inf_salida);

		if (centro.x < corte_x || centro.y < sup || centro.y >= inf) {
			discard;
		}
	}

	// --- Scroll ---
	float offset = mod(floor(TIME * fps_logico) * desplazamiento_px_frame, tam.x);
	float src_x = mod(px.x - offset, tam.x);
	COLOR = texelFetch(TEXTURE, ivec2(int(src_x), int(px.y)), 0) * color_vertice;
}
