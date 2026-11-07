shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float eva = 0.0;
uniform float evb = 1.0;
void fragment() {
	vec4 mask = texture(TEXTURE, UV);
	vec3 backdrop = texture(screen_texture, SCREEN_UV).rgb;
	COLOR = vec4(min(vec3(eva) + backdrop * evb, vec3(1.0)), mask.a);
}
