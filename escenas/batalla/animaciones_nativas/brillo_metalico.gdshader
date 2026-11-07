shader_type canvas_item;
// Brillo metálico de Garra Metal / Cola Férrea (sub_80E0A4C): el battler pasa a gris (media de
// los canales, sub_8079108) y por su silueta pasan franjas claras en diagonal que se desplazan.
// El original usa una textura propia vista a través de una ventana OBJ con la forma del
// battler; aquí son franjas procedurales (aproximación).
uniform float gris : hint_range(0.0, 1.0) = 1.0;
uniform float brillo : hint_range(0.0, 1.0) = 0.0;
// Mezcla hacia un color en vez de gris (Cola Veneno: 11/16 hacia el color del argumento).
uniform vec4 color_tinte : source_color = vec4(1.0);
uniform float tinte : hint_range(0.0, 1.0) = 0.0;
// Desplazamiento de las franjas en píxeles del sprite (avanza 4 px por frame en el original).
uniform float desplazamiento = 0.0;
uniform float periodo = 32.0;
uniform float ancho = 8.0;

void fragment() {
	vec4 textura = texture(TEXTURE, UV);
	vec2 px = UV / TEXTURE_PIXEL_SIZE;
	float media = (textura.r + textura.g + textura.b) / 3.0;
	vec3 color = mix(textura.rgb, vec3(media), gris);
	color = mix(color, color_tinte.rgb, tinte);
	float franja = step(mod(px.x + px.y + desplazamiento, periodo), ancho);
	color = mix(color, min(color * 0.75 + vec3(0.5), vec3(1.0)), franja * brillo);
	COLOR = vec4(color, textura.a);
}
