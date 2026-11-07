shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 source_scale=vec2(1.0);
uniform float eva=0.5;
uniform float evb=0.5;
void fragment() {
	// The fixed128px double-size OAM footprint clips the transformed64px image.
	vec2 sampled=(UV-vec2(0.5))/source_scale+vec2(0.5);
	if(any(lessThan(sampled,vec2(0.25)))||any(greaterThanEqual(sampled,vec2(0.75))))discard;
	vec4 first=texture(TEXTURE,sampled);
	COLOR=vec4(min(first.rgb*eva+texture(screen_texture,SCREEN_UV).rgb*evb,vec3(1.0)),first.a);
}
