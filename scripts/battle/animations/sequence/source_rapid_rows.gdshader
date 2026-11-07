shader_type canvas_item;
render_mode unshaded;
uniform vec2 frame_uv_origin=vec2(0.0);
uniform vec2 frame_uv_size=vec2(1.0);
uniform float source_row_origin=0.0;
uniform float front=69.0;
uniform float back=69.0;
uniform float band=0.0;
uniform float initial_displacement=0.0;
uniform float final_displacement=240.0;
varying vec4 vertex_tint;
void vertex() {
	vertex_tint=COLOR;
}
void fragment() {
	vec2 local=(UV-frame_uv_origin)/frame_uv_size;
	// Native aesthetic projection: the captured selected frame spans the
	// source's 69 scanlines. Source displacement240 removes that row entirely.
	float row=source_row_origin+local.y*69.0;
	float displacement=row>=back?final_displacement:(row>=front?band:initial_displacement);
	if(displacement!=0.0)discard;
	COLOR=texture(TEXTURE,UV)*vertex_tint;
}
