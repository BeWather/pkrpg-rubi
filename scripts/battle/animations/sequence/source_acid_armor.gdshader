shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float stretch=1.0;
uniform float horizontal=0.0;
uniform float phase_angle=0.0;
uniform float eva=1.0;
uniform float evb=0.0;
uniform bool wave_enabled=true;
uniform float scanline_band=66.0;
uniform vec2 frame_uv_origin=vec2(0.0);
uniform vec2 frame_uv_size=vec2(1.0);
void fragment() {
	vec2 local_uv=(UV-frame_uv_origin)/frame_uv_size;
	vec2 sample_uv=local_uv;
	if (wave_enabled) {
		float rows=(1.0-local_uv.y)*frame_uv_size.y/TEXTURE_PIXEL_SIZE.y;
		if(rows>scanline_band)discard;
		sample_uv.y=1.0-(1.0-local_uv.y)*stretch;
		float shift=horizontal*(1.0-2.0*(1.0-local_uv.y))+8.0*sin((phase_angle+rows*10.0)*6.28318530718/256.0);
		sample_uv.x+=shift*TEXTURE_PIXEL_SIZE.x/frame_uv_size.x;
	}
	vec4 first=texture(TEXTURE,frame_uv_origin+sample_uv*frame_uv_size);
	if (sample_uv.x<0.0 || sample_uv.x>1.0 || sample_uv.y<0.0 || sample_uv.y>1.0)first.a=0.0;
	vec3 second=texture(screen_texture,SCREEN_UV).rgb;
	COLOR=vec4(min(first.rgb*eva+second*evb,vec3(1.0)),first.a);
}
