shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float eva=1.0;
uniform float evb=0.0;
uniform float amount=0.0;
uniform bool bottle_clip=false;
uniform float angle=0.0;
void fragment() {
	vec4 first=texture(TEXTURE,UV);
	vec2 p=(UV-vec2(0.5))*32.0;
	vec2 rotated=mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle)))*p;
	if(bottle_clip && max(abs(rotated.x),abs(rotated.y))>16.0) discard;
	vec3 source5=floor(first.rgb*31.0+vec3(0.5));
	vec3 blended=floor(source5+(vec3(12.0,24.0,30.0)-source5)*amount/16.0);
	vec3 expanded=(blended*8.0+floor(blended/4.0))/255.0;
	COLOR=vec4(min(expanded*eva+texture(screen_texture,SCREEN_UV).rgb*evb,vec3(1.0)),first.a);
}
