shader_type canvas_item;

uniform vec2 offset;
uniform vec2 canvas_size = vec2(1280., 720.);
uniform float scale:hint_range(0.0, 1.0);
uniform float strength:hint_range(0.5, 1000.0);
uniform sampler2D txr;

void fragment() {
	vec2 uv = UV * canvas_size;
    vec2 mn = texture(txr, uv * scale / 128.0 + offset).rg - 0.5;
    COLOR = texture(TEXTURE, (uv + mn * strength) / canvas_size);
}