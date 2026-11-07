shader_type canvas_item;

uniform vec2 scroll_speed = vec2(16, -16); // X e Y en píxeles por segundo
uniform float time_scale = 1.0;

void fragment() {
    vec2 uv = UV;
    uv += scroll_speed * TIME * time_scale;
    COLOR = texture(TEXTURE, uv);
}
