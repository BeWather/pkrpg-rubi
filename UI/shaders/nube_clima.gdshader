shader_type canvas_item;
render_mode blend_mix;

// Mezcla de nubes y niebla horizontal fiel al GBA: son
// OBJ semitransparentes con BLDALPHA EVA = 12, EVB = 8, es decir, por canal
//     resultado = min(1, nube * 12/16 + fondo * 8/16)
// Por eso se ven claras/blanquecinas y nítidas, y no como un alfa normal.
//
// - `screen_texture` es la copia del BackBufferCopy: `BackBufferAgua` para
//   las nubes de mundo, `BackBufferClimaPantalla` para la niebla, o, si no lo
//   hay, la copia automática que Godot hace antes del primer lector.
// - Solo donde el texel de la nube es opaco: el alfa de salida es el de la
//   textura × modulate. El efecto pasa la mezcla del clima (factor de crossfade
//   × intensidad × alfa) en el alfa del modulate, de modo que con blend_mix
//       final = mix(fondo, resultado, alfa)
//   y el fundido de entrada/salida interpola entre el fondo y la mezcla GBA.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
// Peso de la nube (EVA / 16).
uniform float eva : hint_range(0.0, 1.0) = 0.75;
// Peso del fondo (EVB / 16).
uniform float evb : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	// COLOR llega como textura × modulate.
	vec3 fondo = texture(screen_texture, SCREEN_UV).rgb;
	vec3 resultado = min(vec3(1.0), COLOR.rgb * eva + fondo * evb);
	COLOR = vec4(resultado, COLOR.a);
}
