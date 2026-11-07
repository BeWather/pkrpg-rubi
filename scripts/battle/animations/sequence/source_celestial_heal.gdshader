shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec3 color5=vec3(31.0);
uniform float amount=0.0;
uniform float eva=1.0;
uniform float evb=0.0;
void fragment(){
	vec4 first=texture(TEXTURE,UV);
	vec3 rgb5=floor(first.rgb*31.0+vec3(0.5));
	vec3 value=floor(rgb5+(color5-rgb5)*amount/16.0);
	vec3 expanded=(value*8.0+floor(value/4.0))/255.0;
	COLOR=vec4(min(expanded*eva+texture(screen_texture,SCREEN_UV).rgb*evb,vec3(1.0)),first.a);
}
