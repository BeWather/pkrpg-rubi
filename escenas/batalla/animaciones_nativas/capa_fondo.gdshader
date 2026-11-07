shader_type canvas_item;
// Capa de fondo de las animaciones nativas (CapaFondoNativa): lo que en el original es un fondo
// BG1/BG2/BG3 con su textura, aquí es un Sprite2D con este material. La posición se calcula en
// píxeles locales de la capa (VERTEX), no con UV:
// - `desplazamiento`: scroll; en la fila y de la capa se ve el píxel (x, y) + desplazamiento de
//   la textura, como gBattle_BGn_X/Y. Con `repetir`, la textura se repite dentro del fotograma
//   actual (`fotograma` = x, y, ancho, alto en píxeles de la textura); sin `repetir`, fuera de él
//   no se dibuja nada (copia de un battler).
// - ondulación por fila (lo que el original hace por scanline con HOFS): la fila y se desplaza
//   además floor(onda_amplitud * sen(2π (y + onda_fase) / onda_periodo)) píxeles (el >> de las
//   tablas de seno del original), más onda_extra en el sentido del signo, solo entre onda_filas.x
//   y onda_filas.y (filas locales).
// - mezcla con lo que hay debajo como REG_BLDALPHA (capa * eva + debajo * evb, saturado) o con
//   opacidad normal.
// - ventana: solo se ve dentro de la silueta (alfa) de un battler, como la ventana OBJ.
// - tinte: mezcla de paleta hacia un color (BlendPalette), p. ej. copias oscurecidas de un battler.
uniform sampler2D pantalla : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 tamano_textura = vec2(256.0, 256.0);
uniform vec4 fotograma = vec4(0.0, 0.0, 256.0, 256.0);
uniform vec2 desplazamiento = vec2(0.0);
uniform bool repetir = true;
// Copia de un battler volteado (flip_h): la textura se lee al revés en x.
uniform bool espejo = false;
uniform float onda_amplitud = 0.0;
uniform float onda_periodo = 32.0;
uniform float onda_fase = 0.0;
uniform float onda_extra = 0.0;
uniform vec2 onda_filas = vec2(-100000.0, 100000.0);
uniform bool mezcla_gba = false;
uniform float eva : hint_range(0.0, 1.0) = 1.0;
uniform float evb : hint_range(0.0, 1.0) = 0.0;
uniform float opacidad : hint_range(0.0, 1.0) = 1.0;
uniform vec4 tinte_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float tinte_cantidad : hint_range(0.0, 1.0) = 0.0;
uniform bool con_ventana = false;
uniform sampler2D ventana : filter_nearest, repeat_disable;
// Inversa de la transformada global del battler (mundo -> píxel local de su textura dibujada).
uniform vec3 ventana_x = vec3(1.0, 0.0, 0.0);
uniform vec3 ventana_y = vec3(0.0, 1.0, 0.0);
// Rect del fotograma del battler en su textura y tamaño de la textura (píxeles).
uniform vec4 ventana_rect = vec4(0.0, 0.0, 64.0, 64.0);
uniform vec2 ventana_tamano = vec2(64.0, 64.0);
uniform bool ventana_espejo = false;

varying vec2 local;
varying vec2 mundo;

void vertex() {
	local = VERTEX;
	mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 celda = floor(local);
	float dx = 0.0;
	if (celda.y >= onda_filas.x && celda.y <= onda_filas.y) {
		dx = floor(onda_amplitud * sin(6.28318530718 * (celda.y + onda_fase) / onda_periodo));
		dx += sign(dx) * onda_extra;
	}
	vec2 p = celda + desplazamiento + vec2(dx, 0.0);
	float visible = 1.0;
	if (repetir) {
		p = mod(p, fotograma.zw);
	} else if (p.x < 0.0 || p.y < 0.0 || p.x >= fotograma.z || p.y >= fotograma.w) {
		visible = 0.0;
	}
	if (espejo) {
		p.x = fotograma.z - 1.0 - p.x;
	}
	vec4 c = texture(TEXTURE, (p + fotograma.xy + 0.5) / tamano_textura);
	c.a *= visible;
	c.rgb = mix(c.rgb, tinte_color.rgb, tinte_cantidad);
	if (con_ventana) {
		vec2 q = floor(vec2(dot(ventana_x, vec3(mundo, 1.0)), dot(ventana_y, vec3(mundo, 1.0))));
		if (ventana_espejo) {
			q.x = ventana_rect.z - 1.0 - q.x;
		}
		float dentro = step(0.0, q.x) * step(0.0, q.y) * step(q.x, ventana_rect.z - 1.0) * step(q.y, ventana_rect.w - 1.0);
		float a = texture(ventana, (q + ventana_rect.xy + 0.5) / ventana_tamano).a;
		c.a *= dentro * step(0.5, a);
	}
	if (mezcla_gba) {
		vec3 debajo = texture(pantalla, SCREEN_UV).rgb;
		COLOR = vec4(min(c.rgb * eva + debajo * evb, vec3(1.0)), step(0.5, c.a));
	} else {
		COLOR = vec4(c.rgb, c.a * opacidad);
	}
}
