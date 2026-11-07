shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D mask_texture : repeat_enable, filter_nearest;
uniform vec2 mask_size=vec2(256.0);
uniform mat3 owner_inverse;
uniform vec2 scroll=vec2(0.0);
uniform float eva=0.0;
uniform float evb=1.0;
void fragment(){
	vec4 silhouette=texture(TEXTURE,UV);
	vec2 point=(owner_inverse*vec3(FRAGCOORD.xy,1.0)).xy;
	vec4 first=texture(mask_texture,(floor(point)+scroll+vec2(0.5))/mask_size);
	vec3 backdrop=texture(screen_texture,SCREEN_UV).rgb;
	COLOR=vec4(min(first.rgb*eva+backdrop*evb,vec3(1.0)),silhouette.a*first.a);
}
