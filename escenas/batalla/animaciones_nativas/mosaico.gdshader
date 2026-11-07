shader_type canvas_item;
// Mosaico de REG_MOSAIC (Transformación, sub_812D7E8): bloques de (mosaico + 1) px del fotograma del sprite.
// `blanco`: mezcla hacia el blanco de la paleta nueva (sub_8031FC4 la deja 6/16 más clara).
uniform float mosaico = 0.0;
uniform vec2 origen_uv = vec2(0.0);
uniform vec2 tamano_uv = vec2(1.0);
uniform float blanco : hint_range(0.0, 1.0) = 0.0;
uniform float alfa : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 local = (UV - origen_uv) / tamano_uv;
	vec2 pixeles = local * tamano_uv / TEXTURE_PIXEL_SIZE;
	float bloque = mosaico + 1.0;
	vec2 muestra = (floor(pixeles / bloque) * bloque + vec2(0.5)) * TEXTURE_PIXEL_SIZE / tamano_uv;
	muestra = clamp(muestra, vec2(0.0), vec2(0.999999));
	vec4 color = texture(TEXTURE, origen_uv + muestra * tamano_uv);
	COLOR = vec4(mix(color.rgb, vec3(1.0), blanco), color.a * alfa);
}
