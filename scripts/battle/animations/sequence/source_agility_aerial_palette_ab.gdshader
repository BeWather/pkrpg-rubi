shader_type canvas_item;
render_mode unshaded;
// A selected source palette bank followed by local transparent-OBJ composition.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float eva : hint_range(0.0, 1.0) = 0.75;
uniform float evb : hint_range(0.0, 1.0) = 0.5;
uniform vec4 blend_color : source_color = vec4(1.0);
uniform bool grayscale = false;
uniform bool invert = false;
uniform float blend_amount = 0.0;
// Finite sword opt-in; every existing caller retains the original false path.
uniform bool source_recolor = false;
uniform vec4 source_recolor_tint : source_color = vec4(1.0);
uniform float wave_amplitude = 0.0;
uniform float wave_phase = 0.0;
uniform float wave_height = 64.0;
uniform float wave_start = -32.0;
uniform float wave_end = 32.0;
uniform float wave_scale_x = 1.0;
uniform float wave_scale_y = 1.0;
varying float source_local_y;
varying vec4 vertex_tint;
void vertex() {
    source_local_y = VERTEX.y;
    vertex_tint = COLOR;
}
void fragment() {
    vec2 sample_uv = UV;
    float source_y = source_local_y * wave_scale_y;
    if (source_y >= wave_start && source_y < wave_end) {
        sample_uv.x += sin((source_y - wave_start + wave_phase) * 6.2831853 / 128.0) * wave_amplitude * TEXTURE_PIXEL_SIZE.x / max(0.001, wave_scale_x);
    }
    vec4 pixel = texture(TEXTURE, sample_uv) * vertex_tint;
    if (source_recolor) {
        vec4 texel = texture(TEXTURE, sample_uv);
        float brightness = max(texel.r, max(texel.g, texel.b));
        pixel = vec4(vec3(brightness) * source_recolor_tint.rgb, texel.a * source_recolor_tint.a);
    }
    vec3 rgb = grayscale ? vec3((pixel.r + pixel.g + pixel.b)/3.0) : pixel.rgb;
    if (invert) { rgb = vec3(1.0) - rgb; }
    vec3 palette_rgb = mix(rgb, blend_color.rgb, blend_amount);
    vec3 screen_rgb = texture(screen_texture, SCREEN_UV).rgb;
    COLOR = vec4(min(palette_rgb * eva + screen_rgb * evb, vec3(1.0)), pixel.a);
}
