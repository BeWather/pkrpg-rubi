shader_type canvas_item;
render_mode unshaded;
uniform vec2 source_scale=vec2(1.0);
void fragment(){
	// Source affineMode1 retains its32x32 OAM footprint while the image grows.
	vec2 p=(UV-vec2(0.5))*32.0*source_scale;
	if(max(abs(p.x),abs(p.y))>16.0)discard;
	COLOR=texture(TEXTURE,UV);
}
