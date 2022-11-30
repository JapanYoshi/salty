shader_type canvas_item;

uniform vec2 offset;
uniform vec2 canvas_size = vec2(1280., 720.);
uniform sampler2D txr;
uniform float scale:hint_range(0.5, 1000.0) = 20.0;
uniform float p_time:hint_range(0.0, 1.0) = 0.0;
uniform float blend:hint_range(0, 1) = 1.0;

void fragment() {
	vec2 uv = (UV + offset) * canvas_size / 1000.;
    // simple
	float n = texture(txr, (uv + vec2(0, p_time)) * scale).r;
	
	COLOR = texture(TEXTURE, UV);
	COLOR.rgb = COLOR.rgb * (1. + n * blend);
}