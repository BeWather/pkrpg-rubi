shader_type canvas_item;
uniform sampler2D mask_texture : repeat_enable, filter_nearest;
uniform float scroll = 0.0;
uniform float amount = 0.0;
void fragment() {
    vec4 actor = texture(TEXTURE, UV);
    vec4 mask = texture(mask_texture, vec2(UV.x, UV.y + scroll));
    COLOR = vec4(mask.rgb, actor.a * mask.a * amount);
}
