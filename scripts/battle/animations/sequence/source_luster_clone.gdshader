shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float eva=1.0;
uniform float evb=0.0;
uniform float palette_amount=0.0;
void fragment() {
	vec4 first=texture(TEXTURE,UV);
	vec3 second=texture(screen_texture,SCREEN_UV).rgb;
	COLOR=vec4(min(mix(first.rgb,vec3(1.0),palette_amount)*eva+second*evb,vec3(1.0)),first.a);
}
