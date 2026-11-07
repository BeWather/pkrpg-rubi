shader_type canvas_item;
render_mode unshaded;
// Same leaf dimensions as TEXTURE: preserve Sprite2D Atlas/region/frame UVs.
uniform sampler2D palette_texture : source_color, filter_nearest, repeat_disable;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
    COLOR = texture(palette_texture, UV) * vertex_tint;
}
