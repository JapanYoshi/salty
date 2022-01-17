/*
	放射状ブラーエフェクト by あるる（きのもと　結衣） @arlez80
	Radial Blur Effect by Yui Kinomoto

	MIT License
*/
shader_type canvas_item;

// 発射中央部
uniform vec2 blur_center = vec2( 0.5, 0.5 );
// ブラー強度
uniform float blur_power : hint_range( 0.0, 1.0 ) = 0.01;
// サンプリング回数
uniform int sampling_count : hint_range( 1, 64 ) = 6;

uniform vec3 ray_color = vec3(1, 1, 1);

void fragment( )
{
	vec2 direction = SCREEN_UV - blur_center;
	float ray = 0.0;
	float f = 1.0 / float( sampling_count ) * COLOR.a;
	for( int i=0; i < sampling_count; i++ ) {
		ray += texture( SCREEN_TEXTURE, SCREEN_UV - blur_power * direction * float(i) ).g * (float(sampling_count - i) / float(sampling_count * sampling_count));
	}
	/* g channel is for rays, r channel is for original */
	ray = min(1.0, ray);
	COLOR.rgb = ((1.0 - texture(SCREEN_TEXTURE, SCREEN_UV).r) * COLOR.rgb) + ray_color * ray;
	COLOR.a = 1.0;
}