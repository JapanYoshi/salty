extends TextureRect

var offset = Vector2.ZERO
export var offset_speed = 0.1 * Vector2.DOWN
var p_time = 0
export var time_speed = 0.1

func _ready():
	pass

func _process(delta):
	if R.get_settings_value("graphics_quality") == 0:
		return
	offset += offset_speed * delta
	p_time += time_speed * delta
	self.material.set_shader_param(
		"p_time", p_time
	)
	self.material.set_shader_param(
		"offset", offset
	)
