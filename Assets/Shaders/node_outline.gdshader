shader_type canvas_item;

// 粗黑描边 + 呼吸动画 Shader
// 适用于地图节点的卡通风格描边效果

uniform float outline_width : hint_range(1.0, 8.0) = 3.0;
uniform vec4 outline_color : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform float breath_speed : hint_range(0.5, 4.0) = 2.0;
uniform float breath_amount : hint_range(0.0, 0.15) = 0.05;
uniform bool is_reachable = false;
uniform float pulse_time : hint_range(0.0, 6.28) = 0.0;

void fragment() {
    vec4 col = COLOR;
    
    // 呼吸效果：可到达节点有轻微亮度波动
    if (is_reachable) {
        float breath = sin(pulse_time * breath_speed) * breath_amount;
        col.rgb += breath;
    }
    
    COLOR = col;
}

// 描边通过在绘制时多次偏移采样实现（在 MapNode 中用 duplicate + scale 方式模拟）