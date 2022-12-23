extends ProgressBar

onready var textbox: Label = $Label
var text_template: String = "%s"
var time_limit: float = 0.0
var anim: AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready():
	_set_height(0.0)

func setup(new_anim: AnimationPlayer, new_text_template: String):
	anim = new_anim
	text_template = new_text_template

func _process(delta):
	if visible == false: return
	if time_limit == 0.0:
		visible = false; return
	if is_instance_valid(anim):
		var time_now = anim.current_animation_position
		var time_left = time_limit - time_now
		if time_left <= 0.0:
			_update_text(0.0)
			time_limit = 0.0
			visible = false
		else:
			_update_text(time_left)
			if time_left <= 0.2:
				_set_height(time_left / 0.2)

func _update_text(time_left: float):
	value = time_left
	textbox.text = text_template % ("%.2f" % time_left)

# Sets rect_scale.y to time_left cubed. Used for automatically spinning
func _set_height(time_left: float):
	rect_scale.y = time_left * time_left * time_left

func flip_in(tween: Tween, time_now: float, new_time_limit: float):
	min_value = 0
	max_value = new_time_limit - time_now
	value = max_value
	time_limit = new_time_limit
	tween.interpolate_property(
		self, "rect_scale", Vector2.RIGHT, Vector2.ONE, 0.2, Tween.TRANS_CUBIC, Tween.EASE_OUT
	)
	visible = true
