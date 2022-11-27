extends ColorRect

export var v_speed: float = 0.01;
export var radius: float = 0.0;

# Called when the node enters the scene tree for the first time.
func _ready():
	self.material.set_shader_param(
		"p_time", 0
	)
	self.material.set_shader_param(
		"offset", Vector2.ZERO
	)
	pass # Replace with function body.

func _process(delta):
	if !self.visible or R.cfg.graphics_quality == 0:
		self.set_process(false)
		return
	self.material.set_shader_param(
		"p_time",
		self.material.get_shader_param("p_time")
		+ delta * v_speed
	)
	self.material.set_shader_param(
		"radius",
		radius
	)

func set_param(key, value):
	if key == "radius" and R.cfg.graphics_quality >= 2:
		radius = value;
	else:
		self.material.set_shader_param(
			key, value
		)
