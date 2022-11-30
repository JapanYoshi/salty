shader_type canvas_item;

uniform float radius: hint_range(0.0, 1.0) = 0.5;
uniform float smoothing: hint_range(0.0, 1.0) = 0.0;
uniform vec2 resolution = vec2(1280, 720);

void fragment() {
	vec2 uv = (UV - 0.5) * resolution / length(resolution);
	COLOR.a = smoothstep(radius - smoothing, radius, length(uv) * 2.0);
}