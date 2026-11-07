shader_type canvas_item;
// Escena de evolución (variante con AnimationPlayer): lleva el sprite hacia
// blanco de forma progresiva. `blanco = 0` deja el sprite intacto; `blanco = 1`
// lo deja como silueta blanca conservando el alfa del texto.
//
// Lo anima el AnimationPlayer de escena_evolucion_anim.tscn con la pista
// `Nodo:material:shader_parameter/blanco`.

uniform float blanco : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 final_rgb = mix(c.rgb, vec3(1.0), blanco);
	// Multiplicar por COLOR.a conserva el alfa del modulate entrante: así una
	// futura pista sobre `Nodo:modulate` seguiría fundiendo el sprite.
	COLOR = vec4(final_rgb, c.a * COLOR.a);
}
