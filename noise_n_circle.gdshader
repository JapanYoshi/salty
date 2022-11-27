shader_type canvas_item;

uniform vec2 offset;
uniform vec2 canvas_size = vec2(1280., 720.);
uniform sampler2D txr;
uniform float scale:hint_range(0.5, 1000.0) = 20.0;
uniform float p_time:hint_range(0.0, 1.0) = 0.0;
uniform float blend:hint_range(0, 1) = 1.0;
uniform float radius:hint_range(0, 1.5) = 1.5;

void fragment() {
	vec2 uv = (UV + offset) * canvas_size / 1000.;
    // simple
	float n = texture(txr, (uv + vec2(0, p_time)) * scale).r;
	
    COLOR.rgb = mix(COLOR.rgb, COLOR.rgb + n - 0.5, blend);
	COLOR.rgb *= smoothstep(
		radius - 0.002, radius - 0.005,
		length((UV - 0.5) * canvas_size / 500.)
	);
}