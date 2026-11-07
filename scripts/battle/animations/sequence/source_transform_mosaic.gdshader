shader_type canvas_item;
render_mode unshaded;
uniform float mosaic=0.0;
uniform vec2 frame_uv_origin=vec2(0.0);
uniform vec2 frame_uv_size=vec2(1.0);
void fragment() {
	vec2 local_uv=(UV-frame_uv_origin)/frame_uv_size;
	vec2 pixels=local_uv*frame_uv_size/TEXTURE_PIXEL_SIZE;
	float block=mosaic+1.0;
	vec2 sampled=(floor(pixels/block)*block+vec2(0.5))*TEXTURE_PIXEL_SIZE/frame_uv_size;
	sampled=clamp(sampled,vec2(0.0),vec2(0.999999));
	COLOR=texture(TEXTURE,frame_uv_origin+sampled*frame_uv_size);
}
