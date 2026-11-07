shader_type canvas_item;
render_mode unshaded;

// Mosaico del registro REG_MOSAIC de la GBA: cada bloque de `tamano_bloque` x
// `tamano_bloque` píxeles de pantalla repite el color de su píxel superior
// izquierdo. Con tamano_bloque = 1 la imagen queda intacta.
uniform sampler2D pantalla : hint_screen_texture, filter_nearest;
uniform float tamano_bloque : hint_range(1.0, 32.0) = 1.0;

void fragment() {
	vec2 resolucion = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 pixel = floor(SCREEN_UV * resolucion);
	vec2 origen_bloque = floor(pixel / tamano_bloque) * tamano_bloque;
	COLOR = vec4(texture(pantalla, (origen_bloque + 0.5) / resolucion).rgb, 1.0);
}
