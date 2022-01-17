extends TextureRect

export var period: float = 1.0

func time(value):
	self.material.set_shader_param(
		"offset",
		fmod(value / period, 1.0)
	)
