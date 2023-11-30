extends ColorRect

export var center: Vector2 = Vector2(0.5, 0.5);
const framerate: float = 24.0;
var abs_time: float = 0.0;
var old_abs_time: float = 0.0
var ptime: float = 0.0;
export var ptimeSpeed: float = 5.0;
export var blend: float = 0.2;

func _ready():
	print(material.get_shader())

func _process(delta):
	if R.get_settings_value("graphics_quality") < 1: return
	abs_time += delta
	if floor(old_abs_time * framerate) != floor(abs_time * framerate):
		ptime = fmod(ptime + ptimeSpeed / framerate, 1.0)
		material.set_shader_param("offset", center)
		material.set_shader_param("blend", blend)
		material.set_shader_param("p_time", ptime)
		old_abs_time = abs_time

func _set_center(new_center):
	if R.get_settings_value("graphics_quality") >= 1: return
	material.set_shader_param("offset", new_center)
