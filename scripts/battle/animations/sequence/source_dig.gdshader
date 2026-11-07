shader_type canvas_item;
render_mode unshaded;
uniform vec2 frame_uv_origin=vec2(0.0);
uniform vec2 frame_uv_size=vec2(1.0);
uniform float native_top=0.0;
uniform float native_height=64.0;
uniform float floor_y=160.0;
varying vec4 vertex_tint;
void vertex() {
	vertex_tint=COLOR;
}
void fragment(){
	vec2 local=(UV-frame_uv_origin)/frame_uv_size;
	if(floor(native_top+local.y*native_height)>=floor_y)discard;
	COLOR=texture(TEXTURE,UV)*vertex_tint;
}
