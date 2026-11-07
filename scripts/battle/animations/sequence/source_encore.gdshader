shader_type canvas_item;
render_mode unshaded;
uniform bool overlay=false;
uniform float brightness=0.0;
uniform mat3 owner_inverse;
uniform bool window_on=false;
uniform sampler2D spot_texture : filter_nearest, repeat_disable;
uniform sampler2D hand_texture : filter_nearest, repeat_disable;
uniform vec4 spot_rect=vec4(0.0);
uniform vec4 hand0_rect=vec4(0.0);
uniform vec4 hand1_rect=vec4(0.0);
bool window_pixel(sampler2D source,vec2 point,vec4 rect,bool flip_h){
	if(rect.z<=0.0 || rect.w<=0.0)return false;
	vec2 uv=(point-rect.xy)/rect.zw+vec2(0.5);
	if(any(lessThan(uv,vec2(0.0))) || any(greaterThanEqual(uv,vec2(1.0))))return false;
	if(flip_h)uv.x=1.0-uv.x;
	return texture(source,uv).a>0.5;
}
void fragment(){
	vec2 point=(owner_inverse*vec3(FRAGCOORD.xy,1.0)).xy;
	bool protected_pixel=window_on && (window_pixel(spot_texture,point,spot_rect,false) || window_pixel(hand_texture,point,hand0_rect,true) || window_pixel(hand_texture,point,hand1_rect,false));
	float amount=protected_pixel?0.0:brightness;
	if(overlay)COLOR=vec4(0.0,0.0,0.0,amount);
	else{
		vec4 first=texture(TEXTURE,UV);
		vec3 original5=floor(first.rgb*31.0+vec3(0.5));
		vec3 value=original5-floor(original5*amount);
		COLOR=vec4((value*8.0+floor(value/4.0))/255.0,first.a);
	}
}
