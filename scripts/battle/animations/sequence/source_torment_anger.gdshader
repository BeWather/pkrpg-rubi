shader_type canvas_item;
render_mode unshaded;
uniform vec2 source_scale=vec2(1.0);
void fragment(){
	// affineMode1 keeps a16x16 OAM footprint, even while its source image expands.
	vec2 p=(UV-vec2(0.5))*16.0*source_scale;
	if(max(abs(p.x),abs(p.y))>8.0)discard;
	COLOR=texture(TEXTURE,UV);
}
