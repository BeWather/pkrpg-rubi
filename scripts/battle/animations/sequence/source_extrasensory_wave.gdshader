shader_type canvas_item;
render_mode unshaded;
// Opaque BG first-target membership: setalpha selects NO BG first target.
uniform vec2 frame_uv_origin=vec2(0.0);
uniform vec2 frame_uv_size=vec2(1.0);
uniform float native_top=0.0;
uniform float native_height=64.0;
uniform float native_width=64.0;
uniform float source_top=0.0;
uniform float source_bottom=64.0;
uniform float source_rows[65];
uniform float uv_direction=1.0;
varying vec4 vertex_tint;
void vertex() {
	vertex_tint=COLOR;
}
void fragment() {
	vec2 local=(UV-frame_uv_origin)/frame_uv_size;
	float row=floor(native_top+local.y*native_height);
	float displacement=0.0;
	if(row>=source_top && row<=source_bottom)displacement=source_rows[clamp(int(row-source_top),0,64)];
	local.x+=displacement/max(native_width,1.0)*uv_direction;
	if(local.x<0.0 || local.x>1.0)discard;
	COLOR=texture(TEXTURE,frame_uv_origin+local*frame_uv_size)*vertex_tint;
}
