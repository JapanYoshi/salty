shader_type canvas_item;

uniform vec2 offset;
uniform vec2 canvas_size = vec2(1280., 720.);
// Texture
uniform sampler2D txr;
// Back-forward scale.
uniform float scale:hint_range(0.001, 1.0) = 0.008;
uniform float p_time = 0.;
uniform float blend:hint_range(0.0, 1.0) = 0.2;

void fragment() {
	// scale the coordinates to dp, starting from center
	vec2 uv = (UV - offset) * canvas_size;
	float radius = length(uv) / length(canvas_size);
	// get log-polar coordinates
	vec2 rt = fract(vec2(
		atan(uv.y, uv.x) / 6.2831853,
		(scale / radius) + p_time
	));
	// center fade effect
	float l = min(1. - radius * 1.41421356, 1.0);
	l = 1. - l * l;
    // generate tileable perlin noise
    float n = texture(txr, rt).r;
    COLOR.rgb = mix(COLOR.rgb + n * blend, vec3(n), blend) * l;
}





