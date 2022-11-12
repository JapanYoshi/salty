extends ColorRect

export var shader_framerate: float = 10.0;
export var shader_loop_length: float = 15.0;
var t: float = 0.0;

# Called when the node enters the scene tree for the first time.
func _ready():
	self.material.set_shader_param(
		"p_time", 0
	)
	pass # Replace with function body.

func _process(delta):
	if !self.visible or R.cfg.graphics_quality < 1:
		self.set_process(false)
		return
	if floor(t * shader_framerate) != floor((t + delta) * shader_framerate):
		set_param("p_time", t / shader_loop_length)
	t = fposmod(t + delta, shader_loop_length)

func set_param(key, value):
	self.material.set_shader_param(
		key, value
	)
