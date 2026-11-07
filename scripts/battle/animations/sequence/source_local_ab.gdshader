shader_type canvas_item;
render_mode unshaded;
// Local first-target composition: independent source EVA and second-target EVB.
// The screen snapshot is read only; no global canvas/material state is changed.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float eva : hint_range(0.0, 1.0) = 0.0;
uniform float evb : hint_range(0.0, 1.0) = 1.0;
uniform vec3 first_tint = vec3(1.0);
void fragment() {
	vec4 first = texture(TEXTURE, UV);
	vec3 second = texture(screen_texture, SCREEN_UV).rgb;
	COLOR = vec4(min(first.rgb * first_tint * eva + second * evb, vec3(1.0)), first.a);
}
