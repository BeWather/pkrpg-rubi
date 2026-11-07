shader_type canvas_item;
render_mode unshaded;
uniform sampler2D source_mask : repeat_enable, filter_nearest;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float source_scroll = 0.0;
varying vec2 local_pixel;
void vertex() { local_pixel = VERTEX; }
void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float mask = texture(source_mask, (local_pixel + vec2(32.0, 32.0-source_scroll))/256.0).a;
	// Actual BG1 EVA8/EVB12 white palette under the source actor OBJ window.
	COLOR = vec4(min(vec3(0.5)+texture(screen_texture,SCREEN_UV).rgb*0.75,vec3(1.0)),base.a*mask);
}
