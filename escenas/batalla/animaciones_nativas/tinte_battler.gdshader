shader_type canvas_item;
// Material temporal de un battler durante una animación nativa:
// - mezcla de paleta del original (BlendPalette: color + (destino - color) * k/16);
// - opacidad con el battler como capa de fondo (REG_BLDALPHA eva/16);
// - recorte por debajo de una línea (la ventana de scanline con la que
//   Excavar mete al battler bajo tierra), en píxeles locales del sprite;
// - §35: colores invertidos de antemano (`invertir`): un compañero que la inversión del campo
//   (InvertPlttBuffer, que en el original no lo toca) vuelve a invertir queda con los suyos.
uniform vec4 color_tinte : source_color = vec4(1.0);
uniform float cantidad : hint_range(0.0, 1.0) = 0.0;
uniform float alfa : hint_range(0.0, 1.0) = 1.0;
uniform float limite_inferior = 100000.0;
uniform float invertir : hint_range(0.0, 1.0) = 0.0;

varying float y_local;

void vertex() {
	y_local = VERTEX.y;
}

void fragment() {
	vec4 textura = texture(TEXTURE, UV);
	float dentro = step(y_local, limite_inferior);
	vec3 color = mix(textura.rgb, color_tinte.rgb, cantidad);
	COLOR = vec4(mix(color, vec3(1.0) - color, invertir), textura.a * alfa * dentro);
}
