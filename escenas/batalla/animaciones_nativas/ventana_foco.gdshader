shader_type canvas_item;
// Ventana OBJ de un sprite (el foco y las manos de Otra Vez y Camelo): donde el sprite es opaco se ve lo que
// había antes del oscurecimiento por hardware (la copia de pantalla que hace el BackBufferCopy de
// EfectoCapasNativo.oscurecer_fuera()), sin oscurecer; el propio sprite no se dibuja.
uniform sampler2D pantalla : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	float dentro = step(0.5, texture(TEXTURE, UV).a);
	COLOR = vec4(texture(pantalla, SCREEN_UV).rgb, dentro);
}
