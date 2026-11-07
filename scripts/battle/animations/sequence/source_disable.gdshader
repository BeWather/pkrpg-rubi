shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform bool gray=false;
uniform float eva=1.0;
uniform float evb=0.0;
void fragment() {
	vec4 first=texture(TEXTURE,UV);
	// sub_8079108 reads UNFADED BGR555, truncates their mean, writes FADED.
	vec3 source5=floor(first.rgb*31.0+vec3(0.5));
	float average=floor((source5.r+source5.g+source5.b)/3.0)/31.0;
	vec3 rgb=gray?vec3(average):first.rgb;
	COLOR=vec4(min(rgb*eva+texture(screen_texture,SCREEN_UV).rgb*evb,vec3(1.0)),first.a);
}
