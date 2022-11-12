extends ColorRect

export var shader_speed: float = 1.0/30.0;
var t: float = 0.0;

# Called when the node enters the scene tree for the first time.
func _ready():
	self.material.set_shader_param(
		"p_time", 0
	)
	pass # Replace with function body.

func _process(delta):
	if !self.visible or R.cfg.graphics_quality < 2:
		self.set_process(false)
		return
	t = fposmod(t + delta * shader_speed, 1.0)
	set_param("p_time", t)

func set_param(key, value):
	self.material.set_shader_param(
		key, value
	)
