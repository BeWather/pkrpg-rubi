shader_type canvas_item;
render_mode unshaded;

// B_TRANSITION_GRID_SQUARES (Phase2_Transition_GridSquares_Func2): toda la pantalla
// es el mismo tile 8x8 de sShrinkingBoxTileset; `paso` elige cuál de los 15 tiles
// (verticales en la textura) se muestra. Lo opaco del tile se pinta en negro.

uniform sampler2D tiles : filter_nearest, repeat_disable;
uniform float paso = 0.0;

void fragment() {
	ivec2 p = ivec2(floor(SCREEN_UV / SCREEN_PIXEL_SIZE));
	int n = clamp(int(floor(paso + 0.001)), 0, 14);
	float opaco = texelFetch(tiles, ivec2(p.x & 7, 8 * n + (p.y & 7)), 0).a;
	COLOR = vec4(0.0, 0.0, 0.0, opaco > 0.5 ? 1.0 : 0.0);
}
