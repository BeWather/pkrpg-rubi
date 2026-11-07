shader_type canvas_item;
render_mode unshaded;
// Black selected BG palette, source VOFS rows and WIN0 in field-pixel coordinates.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 frame_uv_origin=vec2(0.0);
uniform vec2 frame_uv_size=vec2(1.0);
uniform vec2 native_origin=vec2(0.0);
uniform vec2 native_size=vec2(64.0);
uniform float source_rows[160];
uniform float window_left=0.0;
uniform float window_right=240.0;
uniform float eva=0.0;
uniform float evb=1.0;
uniform bool flip_h=false;
uniform bool flip_v=false;
varying vec2 field_pixel;
void vertex(){field_pixel=VERTEX;}
void fragment(){
	int row=clamp(int(floor(field_pixel.y)),0,159);
	vec2 local=(vec2(field_pixel.x,field_pixel.y+source_rows[row])-native_origin)/native_size;
	if(field_pixel.x<window_left || field_pixel.x>=window_right || local.x<0.0 || local.x>=1.0 || local.y<0.0 || local.y>=1.0)discard;
	if(flip_h)local.x=1.0-local.x;
	if(flip_v)local.y=1.0-local.y;
	vec4 first=texture(TEXTURE,frame_uv_origin+local*frame_uv_size);
	// FillPalette(0) makes RGB black, while BG color-index0 remains transparent.
	COLOR=vec4(texture(screen_texture,SCREEN_UV).rgb*evb+vec3(0.0)*eva,first.a);
}
