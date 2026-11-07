shader_type canvas_item;

uniform bool recortar_sprite = false;
// Clip horizontal (corte inferior). Y local del nodo basico en píxeles.
// Con offset=(-16,-30): cabeza ≈ -28, cintura ≈ -14, pies ≈ 0
uniform float clip_local_y : hint_range(-32.0, 32.0) = 2.0;

// Clip lateral (corte izquierdo y derecho). X local en píxeles.
// Con offset=(-16,-30): borde izquierdo del sprite ≈ -16, borde derecho ≈ +16.
// En reposo ambos en sus extremos (sin recorte). Para entrada desde la derecha:
//   animar clip_local_x_der de +16 hacia -16.
// Para entrada desde la izquierda:
//   animar clip_local_x_izq de -16 hacia +16.
uniform float clip_local_x_izq : hint_range(-16.0, 16.0) = -16.0;
uniform float clip_local_x_der : hint_range(-16.0, 16.0) = 16.0;

// Agua termal (MB_HOT_SPRINGS de Rubí, bandera AGUA_TERMAL; ver SumersionTermal). En Rubí
// FldEff_HotSpringsWater dibuja encima del objeto un sprite de agua de 16x16 cuyos 8 px
// inferiores (9 en las esquinas) cubren el cuerpo: aquí se recorta lo que queda bajo esa línea para que se vea
// el agua del mapa. Es independiente del recorte de hierba (que se anima paso a paso): no
// comparten parámetros, así que los dos pueden coexistir en el mismo material.
// Mismo sistema de coordenadas que arriba (pies = 0; el suelo de la celda está en +2).
uniform bool sumergir_agua_termal = false;
// Se oculta lo que cae por debajo de esta Y (celda 16 px: 8 px sobre su borde inferior).
uniform float agua_termal_y = -6.0;
// Los 4 px de cada lado suben un píxel más (las "orejas" del sprite de agua de Rubí).
uniform float agua_termal_y_borde = -7.0;
uniform float agua_termal_x_borde = 4.0;

// En true pinta en rojo la zona recortada (útil para calibrar los valores)
uniform bool debug_modo = false;

// VERTEX solo está disponible en vertex(); se pasa al fragment mediante varying.
varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a < 0.01) {
		discard;
	}

	bool recortar = recortar_sprite && local_pos.y > clip_local_y && local_pos.x > clip_local_x_izq && local_pos.x < clip_local_x_der;
	// Agua termal: solo la anchura de la celda (el sprite de agua de Rubí mide 16 px).
	bool en_celda = local_pos.x > -8.0 && local_pos.x < 8.0;
	bool sumergido = sumergir_agua_termal && en_celda
			&& (local_pos.y > agua_termal_y || (local_pos.y > agua_termal_y_borde && abs(local_pos.x) > agua_termal_x_borde));
	recortar = recortar || sumergido;
	// bool recortar_x = local_pos.x < clip_local_x_izq || local_pos.x > clip_local_x_der;

	if (recortar) {
		if (debug_modo) {
			COLOR = vec4(1.0, 0.0, 0.0, tex.a);
		} else {
			discard;
		}
	} else {
		COLOR = tex;
	}
}
