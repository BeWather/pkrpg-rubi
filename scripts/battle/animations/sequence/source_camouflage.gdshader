shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float eva=1.0;
uniform float evb=0.0;
uniform float amount=0.0;
uniform vec3 tint5=vec3(31.0);
void fragment() {
	vec4 pixel=texture(TEXTURE,UV);
	vec3 original=floor(pixel.rgb*31.0+vec3(0.5));
	vec3 blended=floor(original+(tint5-original)*amount/16.0);
	vec3 expanded=(blended*8.0+floor(blended/4.0))/255.0;
	COLOR=vec4(min(expanded*eva+texture(screen_texture,SCREEN_UV).rgb*evb,vec3(1.0)),pixel.a);
}
