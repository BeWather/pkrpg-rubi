shader_type canvas_item;
uniform sampler2D mask_texture : repeat_enable, filter_nearest;
uniform vec2 field_origin;
uniform vec2 actor_size;
uniform float scroll = 0.0;
uniform float coefficient = 0.0;
void fragment() {
    vec4 actor = texture(TEXTURE, UV);
    vec2 field = field_origin + (UV - vec2(0.5)) * actor_size;
    vec2 dimensions = vec2(textureSize(mask_texture, 0));
    vec4 mask = texture(mask_texture, (field + vec2(0.0, scroll)) / dimensions);
    COLOR = vec4(mask.rgb, actor.a * mask.a * coefficient);
}
