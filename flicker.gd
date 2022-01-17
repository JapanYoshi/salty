extends Panel

onready var base_color = Color("#102b4f")
onready var base_position = rect_position
var time: float = 0.0
var last_time: int = 0

# use md5 for random number generation
# don't worry we don't need our rng to be secure
# just based on hash
func _process(delta):
	if R.cfg.graphics_quality <= 1: return
	time += delta * 10
	if last_time < int(time):
		last_time = int(time)
		var rand = str(last_time).md5_buffer();
		rect_position = (
			base_position + (
				Vector2(rand[0] - 128, rand[1] - 128) / 256
			) * 32.0
		)
		modulate = (
			base_color * (1.0 + 0.03 * (rand[2] + rand[3] + rand[4]) / 512.0)
		)
