shader_type canvas_item;
render_mode blend_mix;

// Reflejo OPACO sobre el agua (ReflexionesAgua con un BackBufferCopy delante).
//
// En el GBA el reflejo es un sprite opaco (paleta pálida) y la silueta de puente
// usa el mismo color que la sombra del agua bajo el puente. Aquí `screen_texture`
// es la copia del backbuffer que hace el `BackBufferCopy` colocado justo después
// de la capa `Agua` del mapa: contiene SOLO el agua (sin nubes ni SombraPuente).
// Donde el texel del sprite tiene alfa > 0 se emite un píxel que ya trae mezclada
// el agua de debajo, así que tapa lo que se haya dibujado entre el agua y AguaFX
// (nubes, sombra del puente). Sobre agua sin nada encima el resultado es idéntico
// al reflejo semitransparente de siempre.
//
// modo 0 (FIJO):    agua ⊕ (textura × modulate × color_reflejo.rgb) con peso
//                   alfa_texel × color_reflejo.a; cobertura = alfa del modulate.
//                   Espejo con flip_v del nodo.
// modo 1 (ONDAS):   agua ⊕ calcular_reflejo_ondas() con peso su alfa (alfa_texel
//                   × opacidad); cobertura 1. Espejo dentro del shader.
// modo 2 (SILUETA): mix(agua, color_sombra.rgb, color_sombra.a); cobertura = alfa
//                   del modulate. Con el color/alfa del tile de SombraPuente da
//                   exactamente el color de la sombra (se funde con ella).

#include "res://UI/shaders/agua_reflejo_ondas.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform int modo = 0;
// FIJO: tinte (rgb) y opacidad (a) del reflejo (ReflexionesAgua.color_reflejo_fijo).
uniform vec4 color_reflejo : source_color = vec4(0.90, 0.92, 0.96, 0.52);
// SILUETA: color y alfa de la sombra del puente sobre el agua.
uniform vec4 color_sombra : source_color = vec4(0.0, 0.0, 0.0, 0.25098);

void fragment() {
	vec3 agua = texture(screen_texture, SCREEN_UV).rgb;
	if (modo == 1) {
		vec4 ondas = calcular_reflejo_ondas(TEXTURE, UV, TIME);
		float cobertura = ondas.a > 0.0 ? 1.0 : 0.0;
		COLOR = vec4(mix(agua, ondas.rgb, ondas.a), cobertura);
	} else {
		// COLOR llega como textura × modulate; el alfa del modulate se recupera
		// dividiendo por el alfa del texel.
		float alfa_texel = texture(TEXTURE, UV).a;
		float alfa_modulate = alfa_texel > 0.0 ? clamp(COLOR.a / alfa_texel, 0.0, 1.0) : 0.0;
		if (modo == 2) {
			COLOR = vec4(mix(agua, color_sombra.rgb, color_sombra.a), alfa_modulate);
		} else {
			vec3 reflejo = COLOR.rgb * color_reflejo.rgb;
			COLOR = vec4(mix(agua, reflejo, alfa_texel * color_reflejo.a), alfa_modulate);
		}
	}
}
