shader_type canvas_item;

// 路线流光 Shader
// 模拟能量沿路径流动的视觉效果

uniform float flow_speed : hint_range(0.5, 5.0) = 1.5;
uniform vec4 flow_color : source_color = vec4(1.0, 0.85, 0.4, 1.0); // 金色流光
uniform float flow_width : hint_range(0.05, 0.4) = 0.15;
uniform bool is_active_path = false;

void fragment() {
    vec4 base_color = COLOR;
    
    if (is_active_path) {
        // 流光效果：基于 UV.x 的周期性高亮
        float flow_pos = fract(TIME * flow_speed - UV.x * 2.0);
        float flow_mask = smoothstep(0.0, flow_width, flow_pos) * smoothstep(flow_width * 2.0, flow_width, flow_pos);
        
        // 混合流光颜色
        vec4 glow = flow_color * flow_mask * 0.8;
        base_color.rgb = mix(base_color.rgb, glow.rgb, flow_mask * 0.6);
        base_color.a = max(base_color.a, flow_mask * 0.4);
    }
    
    COLOR = base_color;
}