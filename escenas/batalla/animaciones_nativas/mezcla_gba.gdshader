shader_type canvas_item;
// Sprite semitransparente de GBA (objMode 1 con setalpha 12, 8):
// resultado = min(1, sprite * 12/16 + fondo * 8/16).
// `bajo_inversion`: el sprite se dibuja DEBAJO de una capa que invierte la
// pantalla pero en el original no se invierte; se pre-invierte para que tras
// la capa quede min(1, sprite * eva + fondo_invertido * evb).
// `encima_inversion`: el sprite se dibuja por encima de esa capa; ya lee el
// fondo invertido y no hay que pre-invertir.
uniform sampler2D pantalla : hint_screen_texture, repeat_disable, filter_nearest;
uniform float eva : hint_range(0.0, 1.0) = 0.75;
uniform float evb : hint_range(0.0, 1.0) = 0.5;
uniform bool bajo_inversion = false;
uniform bool encima_inversion = false;

void fragment() {
	vec3 fondo = texture(pantalla, SCREEN_UV).rgb;
	if (bajo_inversion && !encima_inversion) {
		COLOR.rgb = vec3(1.0) - min(COLOR.rgb * eva + (vec3(1.0) - fondo) * evb, vec3(1.0));
	} else {
		COLOR.rgb = min(COLOR.rgb * eva + fondo * evb, vec3(1.0));
	}
}
