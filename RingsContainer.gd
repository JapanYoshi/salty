extends Control

onready var bg = get_parent().get_parent().get_parent()
var t = 0

func _process(delta):
	if !visible or R.get_settings_value("graphics_quality") == 0: return
	t += delta * bg.ring_speed
	for c in get_children():
		c.time(t)
