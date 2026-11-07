shader_type canvas_item;
uniform float progress = 0.0;
void fragment() {
    vec4 original = texture(TEXTURE, UV);
    float band = 1.0 - smoothstep(0.0, 0.15, abs(UV.x + UV.y * 0.25 - progress * 1.5 + 0.15));
    COLOR = vec4(vec3(0.85, 0.92, 1.0), original.a * band * 0.85);
}
