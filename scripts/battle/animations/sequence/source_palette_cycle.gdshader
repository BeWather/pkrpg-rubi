shader_type canvas_item;
uniform vec4 source_palette[16];
uniform int palette_shift = 0;
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec4 sampled = texture(TEXTURE, UV);
	vec3 result = sampled.rgb;
	for (int index=1; index<=8; index++) {
		if (distance(sampled.rgb,source_palette[index].rgb)<0.003) {
			int selected = 1 + ((index-1-palette_shift+8)%8);
			result = source_palette[selected].rgb;
			break;
		}
	}
	COLOR = vec4(result,sampled.a)*vertex_tint;
}
