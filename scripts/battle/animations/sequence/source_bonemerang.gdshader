shader_type canvas_item;
render_mode unshaded;
uniform float source_rotation=0.0;
void fragment(){
	// Single-size32 OAM clips the rotated opaque image, not a double-size OBJ.
	vec2 p=(UV-vec2(0.5))*32.0;
	float c=cos(source_rotation),s=sin(source_rotation);
	p=mat2(vec2(c,s),vec2(-s,c))*p;
	if(max(abs(p.x),abs(p.y))>16.0)discard;
	COLOR=texture(TEXTURE,UV);
}
