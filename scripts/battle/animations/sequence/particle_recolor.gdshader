shader_type canvas_item;

uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	float brightness = max(texel.r, max(texel.g, texel.b));
	COLOR = vec4(vec3(brightness) * tint.rgb, texel.a * tint.a);
}
