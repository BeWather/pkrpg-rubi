shader_type canvas_item;
// Invierte lo ya dibujado debajo (InvertPlttBuffer de sub_80E2324 en el original).
uniform sampler2D pantalla : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	COLOR = vec4(vec3(1.0) - texture(pantalla, SCREEN_UV).rgb, 1.0);
}
