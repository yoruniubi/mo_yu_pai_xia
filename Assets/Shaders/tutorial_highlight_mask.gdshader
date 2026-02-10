shader_type canvas_item;

uniform vec2 cutout_pos = vec2(0.0, 0.0);
uniform vec2 cutout_size = vec2(0.0, 0.0);
uniform float corner_radius = 10.0;
uniform float feather = 2.0;
uniform vec4 overlay_color : source_color = vec4(0.0, 0.0, 0.0, 0.6);

float rounded_rect_sdf(vec2 p, vec2 size, float radius) {
	vec2 half_size = size * 0.5;
	vec2 d = abs(p - half_size) - (half_size - vec2(radius));
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - radius;
}

void fragment() {
	vec2 screen_px = SCREEN_UV / SCREEN_PIXEL_SIZE;
	vec2 local = screen_px - cutout_pos;
	float dist = rounded_rect_sdf(local, cutout_size, corner_radius);
	float alpha = overlay_color.a * smoothstep(0.0, feather, dist);
	COLOR = vec4(overlay_color.rgb, alpha);
}