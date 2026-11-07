shader_type canvas_item;

// Reflejo-silueta de un objeto sobre un puente (pokeruby, field_effect_helpers.c:
// LoadObjectReflectionPalette con bridge type 1/2/3). En el GBA se carga la
// paleta 10 con sus 16 colores iguales, así que el reflejo es una silueta de
// color sólido que se funde con el agua oscura de debajo del puente.
//
// Rellena todos los texels visibles del frame con `color_silueta` y conserva el
// alfa del sprite (forma, frame y flip_h/flip_v del nodo se respetan tal cual).
// El alfa final se multiplica por el de `color_silueta` y por el modulate.

uniform vec4 color_silueta : source_color = vec4(0.290196, 0.450980, 0.674510, 1.0);

void fragment() {
	// COLOR llega como textura × color de vértice (modulate): su alfa ya es la
	// forma del frame actual.
	COLOR = vec4(color_silueta.rgb, COLOR.a * color_silueta.a);
}
