shader_type canvas_item;
uniform sampler2D palette_lut_texture : filter_nearest, repeat_disable;
uniform sampler2D source_mask : filter_nearest, repeat_disable;
uniform int palette_mode = 0;
uniform bool band_only = false;
uniform int sweep_shift = 0;
uniform vec2 bg_origin = vec2(0.0);
uniform vec2 field_origin = vec2(0.0);
uniform vec2 field_x = vec2(1.0, 0.0);
uniform vec2 field_y = vec2(0.0, 1.0);
varying vec2 source_field;
varying vec4 vertex_tint;
void vertex() {
    vertex_tint = COLOR;
    source_field = field_origin + VERTEX.x * field_x + VERTEX.y * field_y;
}
void fragment() {
    vec4 art = texture(TEXTURE, UV);
    ivec3 q = ivec3(floor(floor(art.rgb * 255.0 + 0.5) / 8.0));
    int index = q.r + q.g * 32 + q.b * 1024;
    vec2 lut_uv = (vec2(float(index % 256), float(index / 256)) + 0.5) / vec2(256.0, 128.0);
    vec3 mapped = texture(palette_lut_texture, lut_uv).rgb;
    float mask = 1.0;
    if (band_only) {
        vec2 pixel = mod(floor(source_field - bg_origin) + vec2(96.0 - float(sweep_shift), 32.0), 256.0);
        mask = texture(source_mask, (pixel + 0.5) / 256.0).a;
        // Bounded actor-local projection of BG1 EVA8/EVB12, not framebuffer parity.
        mapped = min(vec3(31.0), floor((vec3(31.0 * 8.0) + round(mapped * 31.0) * 12.0) / 16.0)) / 31.0;
    }
    COLOR = vec4(mapped, art.a * mask) * vertex_tint;
}
