shader_type canvas_item;

// Reflejo con ondas semitransparente (modo ONDAS_SHADER sin backbuffer). La
// fórmula y los uniforms están en `agua_reflejo_ondas.gdshaderinc`.
#include "res://UI/shaders/agua_reflejo_ondas.gdshaderinc"

void fragment() {
	COLOR = calcular_reflejo_ondas(TEXTURE, UV, TIME);
}
