shader_type canvas_item;

uniform float offset = 0.0;

void fragment() {
	vec2 uv = vec2(fract(UV.x - offset), UV.y);
	COLOR = texture(TEXTURE, uv);
}