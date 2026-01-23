shader_type canvas_item;

// 定义模糊强度，可以在检查器里手动拖动调整
uniform float lod: hint_range(0.0, 5.0) = 2.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    // 采样屏幕图像并应用 LOD (Level of Detail) 模糊
    vec4 color = textureLod(screen_texture, SCREEN_UV, lod);
    // 乘上顶点颜色（即 ColorRect 的颜色），实现调色罩层 (Tinting) 效果
    COLOR = color * COLOR;
}
