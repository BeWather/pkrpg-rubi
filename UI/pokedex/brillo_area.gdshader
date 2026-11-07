// Mezcla alfa del GBA para el brillo de la pantalla ÁREA (BLDCNT con BG0 como
// primer objetivo): resultado = min(1, brillo · eva + fondo · evb), con eva y
// evb en dieciseisavos (BLDALPHA). Los píxeles transparentes no se mezclan.
shader_type canvas_item;

uniform sampler2D pantalla : hint_screen_texture, filter_nearest;
uniform float eva = 0.0;
uniform float evb = 1.0;

void fragment() {
	vec4 brillo = texture(TEXTURE, UV);
	vec3 fondo = texture(pantalla, SCREEN_UV).rgb;
	COLOR = vec4(min(brillo.rgb * eva + fondo * evb, vec3(1.0)), brillo.a);
}
