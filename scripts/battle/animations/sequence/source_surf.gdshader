shader_type canvas_item;
uniform float age = 0.0;
uniform float side = 0.0;
// Native moving alpha band substitutes BG1 scanline blending, not a generic wave.
// Finite Surf task projection for Secret Power and ordinary Surf/Muddy Water.
// Literal/custom fallback workers retain the default false path.
uniform bool source_mode = false;
uniform vec4 source_rect = vec4(0.0, 0.0, 1.0, 0.047619047619047616);
uniform vec2 source_scroll = vec2(0.0);
uniform vec2 source_band = vec2(0.0);
uniform vec2 source_coeff = vec2(0.0, 16.0);
uniform vec4 source_tint = vec4(1.0);
uniform bool source_recolor = false;
varying vec2 source_pixel;
void vertex() { source_pixel = VERTEX; }
void fragment() {
    if (source_mode) {
        vec2 source_uv = source_rect.xy + fract((source_pixel + source_scroll) / vec2(512.0, 256.0)) * source_rect.zw;
        vec4 texel = texture(TEXTURE, source_uv);
        vec3 rgb = source_recolor ? max(texel.r, max(texel.g, texel.b)) * source_tint.rgb : texel.rgb * source_tint.rgb;
        float band = source_pixel.y >= source_band.x && source_pixel.y < source_band.y ? 1.0 : 0.0;
        COLOR = vec4(rgb, texel.a * source_tint.a * source_coeff.x / 16.0 * band);
    } else {

    float direction = side < 0.5 ? -1.0 : 1.0;
    vec2 scroll = vec2(direction * age * 2.0 / 240.0, direction * age / 160.0);
    vec2 sample_uv = fract(UV + scroll);
    sample_uv.y = (sample_uv.y + mod(floor(age / 4.0), 7.0) + side * 7.0) / 14.0;
    vec4 water = texture(TEXTURE, sample_uv);
    float edge = side < 0.5 ? 0.30 - age / 160.0 : age / 160.0;
    float band = side < 0.5 ? smoothstep(edge, edge + 0.05, UV.y) : 1.0 - smoothstep(edge, edge + 0.05, UV.y);
    float fade = min(min(age / 26.0, (135.0 - age) / 26.0), 1.0) * 0.8125;
    // Source rotates water palette entries1..7 every four callbacks.

    COLOR = vec4(water.rgb, water.a * band * max(fade, 0.0));
    }
}
