shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float eva = 1.0;
uniform float evb = 0.0;
uniform vec4 blend_color : source_color = vec4(0.0);
uniform float blend_amount = 0.0;
void fragment() {
    vec4 first = texture(TEXTURE, UV);
    vec3 a = floor(first.rgb * 31.0 + 0.5);
    vec3 b = floor(blend_color.rgb * 31.0 + 0.5);
    float amount = round(blend_amount * 16.0);
    vec3 palette = floor((a * (16.0-amount) + b * amount) / 16.0) / 31.0;
    vec3 second = texture(screen_texture, SCREEN_UV).rgb;
    COLOR = vec4(min(palette * eva + second * evb, vec3(1.0)), first.a);
}
