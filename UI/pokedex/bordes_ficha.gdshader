shader_type canvas_item;
render_mode unshaded;

// Los PNG reservan tres tonos magenta para los bordes de la ficha.
// El registro alterna esta paleta azul con la de especies solo avistadas.
uniform bool borde_gris = false;
uniform vec4 azul_claro : source_color = vec4(0.596078, 0.721569, 0.972549, 1.0);
uniform vec4 azul_medio : source_color = vec4(0.188235, 0.313725, 0.815686, 1.0);
uniform vec4 azul_oscuro : source_color = vec4(0.062745, 0.156863, 0.658824, 1.0);

varying vec4 modulacion;

void vertex() {
	modulacion = COLOR;
}

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	if (pixel.r > 0.95 && pixel.g < 0.55 && pixel.b > 0.45) {
		if (pixel.g > 0.4) {
			pixel.rgb = borde_gris ? vec3(216.0 / 255.0) : azul_claro.rgb;
		} else if (pixel.g > 0.15) {
			pixel.rgb = borde_gris ? vec3(184.0 / 255.0) : azul_medio.rgb;
		} else {
			pixel.rgb = borde_gris ? vec3(160.0 / 255.0) : azul_oscuro.rgb;
		}
	}
	COLOR = pixel * modulacion;
}
