shader_type canvas_item;
// Desplaza las partículas estiradas en diagonal: de la esquina superior
// derecha hacia la esquina inferior izquierda. El patrón se envuelve en
// espejo (mirror repeat) para que el bucle no muestre costuras.
// Con velocidad = 0 la imagen se ve exactamente igual que sin shader.

// Desplazamiento en unidades de UV por segundo (1.0 ≈ cruzar toda la pantalla)
uniform float velocidad : hint_range(0.0, 2.0) = 0.25;
// Dirección del movimiento (por defecto: superior derecha -> inferior izquierda)
uniform vec2 direccion = vec2(-1.0, 1.0);

void fragment() {
	vec2 dir = normalize(direccion);
	vec2 uv = UV - dir * TIME * velocidad;

	// Onda triangular: identidad en [0, 1] y repetición espejada fuera
	// vec2 uv_envuelta = vec2(1.0) - abs(fract(uv * 0.5) * 2.0 - 1.0);
	// COLOR = texture(TEXTURE, uv_envuelta) * COLOR;

	// Efecto de repetición en espejo (mirror repeat) usando fract()
	uv = fract(uv);
	COLOR = texture(TEXTURE, uv);
}
