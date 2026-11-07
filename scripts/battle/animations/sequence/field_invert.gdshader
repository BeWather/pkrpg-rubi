shader_type canvas_item;
uniform sampler2D field_screen : hint_screen_texture, repeat_disable, filter_nearest;
void fragment() {
    vec4 field = texture(field_screen, SCREEN_UV);
    COLOR = vec4(vec3(1.0) - field.rgb, 1.0);
}
