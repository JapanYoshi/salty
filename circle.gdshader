shader_type canvas_item;

uniform float radius: hint_range(0.0, 1.5) = 0.5;
uniform float smoothing: hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = (UV - 0.5) * 2.0;
	COLOR.a = smoothstep(radius - smoothing, radius, length(uv));
}